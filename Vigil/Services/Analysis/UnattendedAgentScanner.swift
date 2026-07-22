import Foundation

// MARK: - Model

/// An AI agent configured to run without a human present — a scheduled
/// Cowork task, or a cron job that invokes an AI CLI headlessly.
struct UnattendedAgent: Identifiable {
    enum Kind: String {
        case coworkScheduledTask
        case cronJob

        var displayName: String {
            switch self {
            case .coworkScheduledTask: "Cowork Scheduled Task"
            case .cronJob: "Cron Job"
            }
        }
    }

    let id: String
    let kind: Kind
    let name: String
    let schedule: String            // raw cron expression
    let enabled: Bool
    let sourcePath: String          // scheduled-tasks.json or crontab line's script
    let folderAccess: [String]
    let browserDomains: [String]
    let permissionMode: String?
    let lastRunAt: Date?
    let capabilities: [String]      // human-readable capability notes

    var scheduleDescription: String {
        Self.describeCron(schedule)
    }

    static func describeCron(_ expression: String) -> String {
        let parts = expression.split(separator: " ").map(String.init)
        guard parts.count == 5 else { return expression }
        let (minute, hour, _, _, weekday) = (parts[0], parts[1], parts[2], parts[3], parts[4])

        let time: String
        if let h = Int(hour), let m = Int(minute) {
            time = String(format: "%d:%02d", h, m)
        } else {
            time = "\(hour):\(minute)"
        }

        switch weekday {
        case "*": return "Daily at \(time)"
        case "0", "7": return "Sundays at \(time)"
        case "1": return "Mondays at \(time)"
        case "2": return "Tuesdays at \(time)"
        case "3": return "Wednesdays at \(time)"
        case "4": return "Thursdays at \(time)"
        case "5": return "Fridays at \(time)"
        case "6": return "Saturdays at \(time)"
        case "1-5": return "Weekdays at \(time)"
        default: return expression
        }
    }
}

// MARK: - Scanner

/// Discovers unattended AI agents from Cowork scheduled-task state and
/// the user's crontab. Pure disk/process reads — call off the main actor.
enum UnattendedAgentScanner {

    /// AI CLI names to look for in cron commands and their referenced scripts.
    private static let aiCLIMarkers = [
        "claude", "codex", "aider", "gemini", "ollama", "openclaw", "clawdbot",
    ]

    static func scanAll() -> [UnattendedAgent] {
        scanCoworkScheduledTasks() + scanCrontab()
    }

    // MARK: Cowork Scheduled Tasks

    static func scanCoworkScheduledTasks() -> [UnattendedAgent] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let sessionsRoot = "\(home)/Library/Application Support/Claude/local-agent-mode-sessions"
        guard fm.fileExists(atPath: sessionsRoot) else { return [] }

        var agents: [UnattendedAgent] = []

        guard let accountDirs = try? fm.contentsOfDirectory(atPath: sessionsRoot) else { return [] }
        for accountDir in accountDirs where !accountDir.hasPrefix(".") {
            let accountPath = "\(sessionsRoot)/\(accountDir)"
            guard let orgDirs = try? fm.contentsOfDirectory(atPath: accountPath) else { continue }
            for orgDir in orgDirs where !orgDir.hasPrefix(".") {
                let tasksPath = "\(accountPath)/\(orgDir)/scheduled-tasks.json"
                agents.append(contentsOf: parseScheduledTasks(at: tasksPath))
            }
        }

        return agents
    }

    static func parseScheduledTasks(at path: String) -> [UnattendedAgent] {
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tasks = json["scheduledTasks"] as? [[String: Any]] else {
            return []
        }

        return tasks.compactMap { task in
            guard let id = task["id"] as? String,
                  let cron = task["cronExpression"] as? String else { return nil }

            let skillPath = task["filePath"] as? String
            var capabilities: [String] = []
            if let skillPath {
                capabilities = summarizeSkillCapabilities(skillPath: skillPath)
            }
            if task["chromePermissionMode"] != nil {
                capabilities.append("Browser automation")
            }

            let lastRun = (task["lastRunAt"] as? String).flatMap {
                ISO8601DateFormatter.withFractional.date(from: $0)
            }

            return UnattendedAgent(
                id: "cowork-\(id)",
                kind: .coworkScheduledTask,
                name: id,
                schedule: cron,
                enabled: task["enabled"] as? Bool ?? false,
                sourcePath: skillPath ?? path,
                folderAccess: task["userSelectedFolders"] as? [String] ?? [],
                browserDomains: task["chromeAllowedDomains"] as? [String] ?? [],
                permissionMode: task["chromePermissionMode"] as? String,
                lastRunAt: lastRun,
                capabilities: capabilities
            )
        }
    }

    /// Read a scheduled task's SKILL.md and note security-relevant capabilities.
    private static func summarizeSkillCapabilities(skillPath: String) -> [String] {
        guard let data = FileManager.default.contents(atPath: skillPath),
              let content = String(data: data, encoding: .utf8)?.lowercased() else {
            return []
        }

        var notes: [String] = []
        if content.contains("bash") || content.contains("shell") {
            notes.append("Shell execution")
        }
        if content.contains("install") {
            notes.append("Can install packages")
        }
        if content.contains("websearch") || content.contains("web search") {
            notes.append("Web search")
        }
        if content.contains("update_scheduled_task") {
            notes.append("Can modify its own schedule")
        }
        if content.contains("write") || content.contains("create") {
            notes.append("File writing")
        }
        return notes
    }

    // MARK: Crontab

    static func scanCrontab() -> [UnattendedAgent] {
        guard let output = runCrontabList() else { return [] }
        return parseCrontab(output)
    }

    static func parseCrontab(_ output: String) -> [UnattendedAgent] {
        var agents: [UnattendedAgent] = []

        for (index, rawLine) in output.split(separator: "\n").enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            let parts = line.split(separator: " ", maxSplits: 5).map(String.init)
            guard parts.count == 6 else { continue }
            let cron = parts[0...4].joined(separator: " ")
            let command = parts[5]

            // Direct AI CLI invocation, or a script that invokes one
            var isAI = containsAIMarker(command)
            var capabilities: [String] = []
            if !isAI, let scriptPath = firstScriptPath(in: command),
               let script = try? String(contentsOfFile: scriptPath, encoding: .utf8) {
                isAI = containsAIMarker(script)
                if script.contains("--print") || script.contains("-p ") {
                    capabilities.append("Headless (no permission prompts)")
                }
            }
            guard isAI else { continue }

            if command.contains("--print") {
                capabilities.append("Headless (no permission prompts)")
            }

            let name = firstScriptPath(in: command)
                .map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
                ?? String(command.prefix(48))

            agents.append(UnattendedAgent(
                id: "cron-\(index)-\(name)",
                kind: .cronJob,
                name: name,
                schedule: cron,
                enabled: true,
                sourcePath: firstScriptPath(in: command) ?? "crontab",
                folderAccess: [],
                browserDomains: [],
                permissionMode: nil,
                lastRunAt: nil,
                capabilities: capabilities.isEmpty ? ["Invokes AI CLI"] : capabilities
            ))
        }

        return agents
    }

    private static func containsAIMarker(_ text: String) -> Bool {
        let lower = text.lowercased()
        return aiCLIMarkers.contains { lower.contains($0) }
    }

    private static func firstScriptPath(in command: String) -> String? {
        for token in command.split(separator: " ") {
            let t = String(token)
            if t.hasSuffix(".sh") || t.hasSuffix(".py"),
               FileManager.default.fileExists(atPath: t) {
                return t
            }
        }
        return nil
    }

    private static func runCrontabList() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/crontab")
        process.arguments = ["-l"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

// MARK: - Formatter

private extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
