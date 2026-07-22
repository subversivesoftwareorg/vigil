import Foundation

struct CodexAdapter: AIToolAdapter {
    let toolID = "codex-cli"
    let displayName = "Codex CLI"
    let provider = "OpenAI"
    let category = AICategory.codingAssistant

    var processSignatures: [ProcessSignature] {
        [
            ProcessSignature(pattern: "codex", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "codex", matchMode: .substring, displayName: displayName),
        ]
    }

    var pathSignatures: [PathSignature] {
        [PathSignature(pattern: "/.codex/", pathCategory: .workspaceData, tool: displayName)]
    }

    func readConfig() -> AIToolConfig? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        let globalPath = "\(home)/.codex/config.toml"
        guard let content = Self.readFile(globalPath) else { return nil }

        let toml = SimpleTOMLParser.parse(content)
        var foundLayers = [SettingsLayer(path: globalPath, label: "User global")]

        // Project-level configs
        for root in AIAdapterRegistry.discoverProjectRoots(marker: ".codex/config.toml") {
            let projectName = URL(fileURLWithPath: root).lastPathComponent
            foundLayers.append(SettingsLayer(
                path: "\(root)/.codex/config.toml",
                label: "Project: \(projectName)"
            ))
        }

        // MCP servers
        var mcpServerNames: [String] = []
        var mcpDetails: [MCPServerDetail] = []
        if let mcpTable = SimpleTOMLParser.table(toml, "mcp_servers") {
            for (name, value) in mcpTable {
                mcpServerNames.append(name)
                if let serverTable = value as? [String: Any] {
                    let command = serverTable["command"] as? String
                    let args = serverTable["args"] as? [String] ?? []
                    let envTable = (serverTable["env"] as? [String: Any]) ?? [:]
                    let env = envTable.compactMapValues { $0 as? String }
                    mcpDetails.append(MCPServerDetail(
                        name: name, command: command, args: args,
                        envVars: env, autoApprovedTools: [],
                        source: "~/.codex/config.toml"
                    ))
                }
            }
        }

        // Model
        let model = SimpleTOMLParser.string(toml, "model")

        // Prompt surfaces (AGENTS.md)
        var promptSurfaces: [PromptSurface] = []
        for root in AIAdapterRegistry.discoverProjectRoots(marker: "AGENTS.md") {
            let projectName = URL(fileURLWithPath: root).lastPathComponent
            promptSurfaces.append(PromptSurface(
                type: .agentsMD, path: "\(root)/AGENTS.md",
                scope: "Project: \(projectName)"
            ))
        }

        // Desktop settings
        let desktopTable = SimpleTOMLParser.table(toml, "desktop")

        // Trusted projects
        var trustedProjects: [String] = []
        if let projectsTable = SimpleTOMLParser.table(toml, "projects") {
            for (path, value) in projectsTable {
                if let projectInfo = value as? [String: Any],
                   let trust = projectInfo["trust_level"] as? String,
                   trust == "trusted" {
                    trustedProjects.append(path)
                }
            }
        }

        // Plugins
        var enabledPlugins: [String] = []
        if let pluginsTable = SimpleTOMLParser.table(toml, "plugins") {
            for (name, value) in pluginsTable {
                if let pluginInfo = value as? [String: Any],
                   let enabled = pluginInfo["enabled"] as? Bool, enabled {
                    enabledPlugins.append(name)
                }
            }
        }

        // Build summary
        var summary: [String] = []
        if let model { summary.append("Model: \(model)") }
        if !mcpServerNames.isEmpty {
            summary.append("\(mcpServerNames.count) MCP server\(mcpServerNames.count == 1 ? "" : "s"): \(mcpServerNames.joined(separator: ", "))")
        }
        if !trustedProjects.isEmpty {
            summary.append("\(trustedProjects.count) trusted project\(trustedProjects.count == 1 ? "" : "s")")
        }
        if !enabledPlugins.isEmpty {
            summary.append("\(enabledPlugins.count) plugin\(enabledPlugins.count == 1 ? "" : "s") enabled")
        }
        if desktopTable != nil {
            summary.append("Desktop app configured")
        }

        var config = AIToolConfig(
            tool: displayName,
            provider: provider,
            layers: foundLayers,
            permissions: PermissionSummary(allowed: [], denied: [], requiresApproval: []),
            envVarCount: 0,
            mcpServers: mcpServerNames,
            hasHooks: false,
            summary: summary
        )
        config.mcpServerDetails = mcpDetails
        config.promptSurfaces = promptSurfaces
        applySandboxPolicies(to: &config, home: home)
        return config
    }

    /// Read persisted per-thread sandbox policies from Codex global state.
    /// Union across threads: any writable root counts, any network grant counts.
    private func applySandboxPolicies(to config: inout AIToolConfig, home: String) {
        let statePath = "\(home)/.codex/.codex-global-state.json"
        guard let data = FileManager.default.contents(atPath: statePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let threadPerms = json["heartbeat-thread-permissions-by-id"] as? [String: Any],
              !threadPerms.isEmpty else {
            return
        }

        var writableRoots = Set<String>()
        var networkAccess = false
        var approvalPolicy: String?
        var sandboxType: String?

        for (_, value) in threadPerms {
            guard let perms = value as? [String: Any] else { continue }
            if let policy = perms["approvalPolicy"] as? String {
                approvalPolicy = policy
            }
            if let sandbox = perms["sandboxPolicy"] as? [String: Any] {
                sandboxType = sandbox["type"] as? String ?? sandboxType
                if let roots = sandbox["writableRoots"] as? [String] {
                    writableRoots.formUnion(roots)
                }
                if (sandbox["networkAccess"] as? Bool) == true {
                    networkAccess = true
                }
            }
        }

        if let sandboxType {
            config.sandboxMode = writableRoots.isEmpty
                ? sandboxType
                : "\(sandboxType): \(writableRoots.sorted().joined(separator: ", "))"
        }
        config.networkAccess = networkAccess
        config.approvalMode = approvalPolicy
    }

    // MARK: - Session Parsing

    func parseSessions(projectFilter: String?) -> [AISessionLog] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let sessionsPath = home + "/.codex/sessions"
        let fm = FileManager.default
        guard fm.fileExists(atPath: sessionsPath) else { return [] }

        var sessions: [AISessionLog] = []

        // Walk the date-based directory tree: sessions/YYYY/MM/DD/*.jsonl
        guard let years = try? fm.contentsOfDirectory(atPath: sessionsPath) else { return [] }
        for year in years {
            let yearPath = sessionsPath + "/" + year
            guard let months = try? fm.contentsOfDirectory(atPath: yearPath) else { continue }
            for month in months {
                let monthPath = yearPath + "/" + month
                guard let days = try? fm.contentsOfDirectory(atPath: monthPath) else { continue }
                for day in days {
                    let dayPath = monthPath + "/" + day
                    guard let files = try? fm.contentsOfDirectory(atPath: dayPath) else { continue }
                    for file in files where file.hasSuffix(".jsonl") {
                        let filePath = dayPath + "/" + file
                        if let session = Self.parseCodexSession(filePath: filePath, projectFilter: projectFilter) {
                            sessions.append(session)
                        }
                    }
                }
            }
        }

        return sessions
    }

    // MARK: - Risk Detection

    func detectRisks(sessions: [AISessionLog], config: AIToolConfig?) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        for session in sessions {
            signals.append(contentsOf: ClaudeCodeAdapter.detectSensitiveFileAccess(session))
            signals.append(contentsOf: ClaudeCodeAdapter.detectSuspiciousBash(session))
            signals.append(contentsOf: ClaudeCodeAdapter.detectExfiltration(session))
            signals.append(contentsOf: ClaudeCodeAdapter.detectLongSession(session))
        }

        // Config-based risks
        if let config {
            signals.append(contentsOf: AIRiskEngine.detectMCPRisks(configs: [config]))

            // Desktop mode with ambient suggestions = elevated agency
            for line in config.summary where line.contains("Desktop app configured") {
                signals.append(AISecuritySignal(
                    category: .excessiveAgency,
                    severity: .info,
                    title: "Codex desktop mode enabled",
                    detail: "Codex is configured with desktop app mode, which can provide ambient code suggestions without explicit prompts.",
                    evidence: "Source: ~/.codex/config.toml [desktop]"
                ))
            }

            // Trusted projects = explicit trust grant
            let trustedCount = config.summary.compactMap { line -> Int? in
                guard line.contains("trusted project") else { return nil }
                return Int(line.prefix(while: \.isNumber))
            }.first ?? 0

            if trustedCount > 5 {
                signals.append(AISecuritySignal(
                    category: .excessiveAgency,
                    severity: .concern,
                    title: "Many trusted projects in Codex",
                    detail: "\(trustedCount) projects are marked as trusted. Each trusted project grants Codex full access without approval prompts.",
                    evidence: "Source: ~/.codex/config.toml [projects]"
                ))
            }
        }

        return signals
    }

    // MARK: - Internals

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFallback: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseCodexSession(filePath: String, projectFilter: String?) -> AISessionLog? {
        guard let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        var sessionID = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
        var projectPath = ""
        var earliestTimestamp: Date?
        var latestTimestamp: Date?
        var humanTurns = 0
        var assistantTurns = 0
        var toolsUsed: [String: Int] = [:]
        var bashCommands: [String] = []
        let modelsUsed: Set<String> = []

        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let lineData = rawLine.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            if let ts = parseTimestamp(obj["timestamp"]) {
                if earliestTimestamp == nil || ts < earliestTimestamp! { earliestTimestamp = ts }
                if latestTimestamp == nil || ts > latestTimestamp! { latestTimestamp = ts }
            }

            let type = obj["type"] as? String ?? ""
            guard let payload = obj["payload"] as? [String: Any] else { continue }

            switch type {
            case "session_meta":
                if let id = payload["id"] as? String { sessionID = id }
                if let cwd = payload["cwd"] as? String { projectPath = cwd }

            case "turn_context":
                break

            case "event_msg":
                if let msgType = payload["type"] as? String {
                    if msgType == "message" || msgType == "user_message" {
                        humanTurns += 1
                    }
                }

            case "response_item":
                let itemType = payload["type"] as? String ?? ""

                if itemType == "message" {
                    if let role = payload["role"] as? String, role == "assistant" {
                        assistantTurns += 1
                    }
                }

                if itemType == "function_call" {
                    let name = payload["name"] as? String ?? ""
                    toolsUsed[name, default: 0] += 1

                    if name == "exec_command",
                       let argsStr = payload["arguments"] as? String,
                       let argsData = argsStr.data(using: .utf8),
                       let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any],
                       let cmd = args["cmd"] as? String {
                        bashCommands.append(cmd)
                    }
                }

            default:
                break
            }
        }

        if let filter = projectFilter {
            guard projectPath.localizedCaseInsensitiveContains(filter) else { return nil }
        }

        guard humanTurns > 0 || assistantTurns > 0 || !toolsUsed.isEmpty else { return nil }

        var session = AISessionLog(id: sessionID, projectPath: projectPath)
        session.startedAt = earliestTimestamp
        session.endedAt = latestTimestamp
        session.humanTurns = humanTurns
        session.assistantTurns = assistantTurns
        session.toolsUsed = toolsUsed
        session.bashCommands = bashCommands
        session.modelsUsed = modelsUsed
        return session
    }

    private static func parseTimestamp(_ value: Any?) -> Date? {
        guard let str = value as? String else { return nil }
        return isoFormatter.date(from: str) ?? isoFallback.date(from: str)
    }

    private static func readFile(_ path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
