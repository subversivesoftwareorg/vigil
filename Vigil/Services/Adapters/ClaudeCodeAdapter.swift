import Foundation

struct ClaudeCodeAdapter: AIToolAdapter {
    let toolID = "claude-code"
    let displayName = "Claude Code"
    let provider = "Anthropic"
    let category = AICategory.codingAssistant

    // MARK: - Process Signatures

    var processSignatures: [ProcessSignature] {
        [
            ProcessSignature(pattern: "claude", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "claude", matchMode: .substring, displayName: displayName),
        ]
    }

    // MARK: - Path Signatures

    var pathSignatures: [PathSignature] {
        [PathSignature(pattern: "/.claude/", pathCategory: .workspaceData, tool: displayName)]
    }

    // MARK: - Config Reading

    func readConfig() -> AIToolConfig? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fm = FileManager.default

        // Managed settings (enterprise/org-level)
        let managedLayers: [(path: String, label: String)] = [
            ("/etc/claude/settings.json", "Managed (system)"),
            ("\(home)/.claude/settings.managed.json", "Managed (user)"),
        ]

        // User settings layers
        let userLayers: [(path: String, label: String)] = [
            ("\(home)/.claude/settings.json", "User global"),
            ("\(home)/.claude/settings.local.json", "User local"),
        ]

        // Project-level settings
        var projectLayers: [(path: String, label: String)] = []
        let projectRoots = AIAdapterRegistry.discoverProjectRoots(marker: ".claude/settings.json")
        for root in projectRoots {
            let projectName = URL(fileURLWithPath: root).lastPathComponent
            projectLayers.append(("\(root)/.claude/settings.json", "Project: \(projectName)"))
            projectLayers.append(("\(root)/.claude/settings.local.json", "Project local: \(projectName)"))
        }

        let allLayers = managedLayers + userLayers + projectLayers

        var foundLayers: [SettingsLayer] = []
        var mergedAllow: [String] = []
        var mergedDeny: [String] = []
        var mergedAsk: [String] = []
        var envVars: [String: String] = [:]
        var mcpServerNames: [String] = []
        var mcpDetails: [MCPServerDetail] = []
        var hookDetails: [HookDetail] = []
        var hasHooks = false
        var hasManagedPolicy = false

        for layer in allLayers {
            guard let data = fm.contents(atPath: layer.path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            foundLayers.append(SettingsLayer(path: layer.path, label: layer.label))

            if layer.label.hasPrefix("Managed") {
                hasManagedPolicy = true
            }

            if let perms = json["permissions"] as? [String: Any] {
                if let allow = perms["allow"] as? [String] {
                    mergedAllow.append(contentsOf: allow)
                }
                if let deny = perms["deny"] as? [String] {
                    mergedDeny.append(contentsOf: deny)
                }
                if let ask = perms["ask"] as? [String] {
                    mergedAsk.append(contentsOf: ask)
                }
            }

            if let env = json["env"] as? [String: String] {
                envVars.merge(env) { _, new in new }
            }

            if let servers = json["mcpServers"] as? [String: Any] {
                for (name, value) in servers {
                    mcpServerNames.append(name)
                    if let serverConfig = value as? [String: Any] {
                        let command = serverConfig["command"] as? String
                        let args = serverConfig["args"] as? [String] ?? []
                        let env = serverConfig["env"] as? [String: String] ?? [:]
                        let autoApproved = serverConfig["autoApprove"] as? [String] ?? []
                        mcpDetails.append(MCPServerDetail(
                            name: name, command: command, args: args,
                            envVars: env, autoApprovedTools: autoApproved,
                            source: layer.label
                        ))
                    }
                }
            }

            if let hooksJSON = json["hooks"] as? [String: Any] {
                hasHooks = true
                for (event, value) in hooksJSON {
                    if let hookList = value as? [[String: Any]] {
                        let commands = hookList.compactMap { $0["command"] as? String }
                        if !commands.isEmpty {
                            hookDetails.append(HookDetail(event: event, commands: commands))
                        }
                    }
                }
            }
        }

        // Also read project-level .mcp.json files
        for root in projectRoots {
            let mcpPath = "\(root)/.mcp.json"
            if let data = fm.contents(atPath: mcpPath),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let servers = json["mcpServers"] as? [String: Any] {
                let projectName = URL(fileURLWithPath: root).lastPathComponent
                for (name, value) in servers {
                    if !mcpServerNames.contains(name) {
                        mcpServerNames.append(name)
                    }
                    if let serverConfig = value as? [String: Any] {
                        mcpDetails.append(MCPServerDetail(
                            name: name,
                            command: serverConfig["command"] as? String,
                            args: serverConfig["args"] as? [String] ?? [],
                            envVars: serverConfig["env"] as? [String: String] ?? [:],
                            autoApprovedTools: serverConfig["autoApprove"] as? [String] ?? [],
                            source: ".mcp.json (\(projectName))"
                        ))
                    }
                }
            }
        }

        // Read ~/.claude.json for memory settings
        var memoryEnabled = false
        let claudeJsonPath = "\(home)/.claude.json"
        if let data = fm.contents(atPath: claudeJsonPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let hasMemory = json["hasCompletedOnboarding"] as? Bool, hasMemory {
                memoryEnabled = true
            }
            if json["memory"] != nil {
                memoryEnabled = true
            }
        }

        // Discover prompt surfaces (CLAUDE.md files)
        var promptSurfaces: [PromptSurface] = []
        let globalClaudeMD = "\(home)/.claude/CLAUDE.md"
        if fm.fileExists(atPath: globalClaudeMD) {
            promptSurfaces.append(PromptSurface(
                type: .claudeMD, path: globalClaudeMD, scope: "Global"
            ))
        }
        for root in projectRoots {
            let projectName = URL(fileURLWithPath: root).lastPathComponent
            let projectClaudeMD = "\(root)/CLAUDE.md"
            if fm.fileExists(atPath: projectClaudeMD) {
                promptSurfaces.append(PromptSurface(
                    type: .claudeMD, path: projectClaudeMD, scope: "Project: \(projectName)"
                ))
            }
            let dotClaudeMD = "\(root)/.claude/CLAUDE.md"
            if fm.fileExists(atPath: dotClaudeMD) {
                promptSurfaces.append(PromptSurface(
                    type: .claudeMD, path: dotClaudeMD, scope: "Project: \(projectName)"
                ))
            }
        }

        guard !foundLayers.isEmpty else { return nil }

        let permissions = Self.categorizePermissions(
            allow: mergedAllow, deny: mergedDeny, ask: mergedAsk
        )

        // Detect auto-mode: broad allow lists suggest reduced oversight
        let autoMode = mergedAllow.count > 20
            || mergedAllow.contains("Bash")
            || mergedAllow.contains(where: { $0 == "Edit" || $0 == "Write" })

        var config = AIToolConfig(
            tool: displayName,
            provider: provider,
            layers: foundLayers,
            permissions: permissions,
            envVarCount: envVars.count,
            mcpServers: mcpServerNames,
            hasHooks: hasHooks,
            summary: Self.generateSummary(permissions: permissions, mcpServers: mcpServerNames,
                                          envVarCount: envVars.count, hasHooks: hasHooks)
        )
        config.autoMode = autoMode
        config.mcpServerDetails = mcpDetails
        config.hookDetails = hookDetails
        config.memoryEnabled = memoryEnabled
        config.managedPolicy = hasManagedPolicy
        config.promptSurfaces = promptSurfaces
        return config
    }

    // MARK: - Session Parsing

    func parseSessions(projectFilter: String?) -> [AISessionLog] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let projectsPath = home + "/.claude/projects"
        let fm = FileManager.default
        guard fm.fileExists(atPath: projectsPath) else { return [] }

        var sessions: [AISessionLog] = []

        guard let projectDirs = try? fm.contentsOfDirectory(atPath: projectsPath) else {
            return []
        }

        for dirName in projectDirs {
            let projectPath = Self.decodeDirName(dirName)
            if let filter = projectFilter {
                guard projectPath.localizedCaseInsensitiveContains(filter) else { continue }
            }

            let dirPath = projectsPath + "/" + dirName
            guard let files = try? fm.contentsOfDirectory(atPath: dirPath) else { continue }

            for file in files where file.hasSuffix(".jsonl") {
                let sessionID = String(file.dropLast(6))
                let filePath = dirPath + "/" + file
                if let session = Self.parseSession(filePath: filePath, sessionID: sessionID,
                                                   projectPath: projectPath) {
                    sessions.append(session)
                }
            }
        }

        return sessions
    }

    // MARK: - Risk Detection

    func detectRisks(sessions: [AISessionLog], config: AIToolConfig?) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        for session in sessions {
            signals.append(contentsOf: Self.detectSensitiveFileAccess(session))
            signals.append(contentsOf: Self.detectSuspiciousBash(session))
            signals.append(contentsOf: Self.detectExfiltration(session))
            signals.append(contentsOf: Self.detectTokenmaxxing(session))
            signals.append(contentsOf: Self.detectLongSession(session))
            signals.append(contentsOf: Self.detectAgentActionConcerns(session))
        }

        // Cross-domain: file sharing exposure
        signals.append(contentsOf: AIRiskEngine.detectFileSharingExposure(sessions: sessions))

        // Config-based: MCP risk, excessive agency
        if let config {
            signals.append(contentsOf: AIRiskEngine.detectMCPRisks(configs: [config]))
            signals.append(contentsOf: AIRiskEngine.detectExcessiveAgency(configs: [config]))
        }

        return signals
    }
}

// MARK: - Session Parsing Internals

extension ClaudeCodeAdapter {

    static func decodeDirName(_ name: String) -> String {
        "/" + name.dropFirst().replacingOccurrences(of: "-", with: "/")
    }

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

    static func parseSession(filePath: String, sessionID: String,
                             projectPath: String) -> AISessionLog? {
        guard let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        var session = AISessionLog(id: sessionID, projectPath: projectPath)
        var earliestTimestamp: Date?
        var latestTimestamp: Date?

        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            if let ts = parseTimestamp(obj["timestamp"]) {
                if earliestTimestamp == nil || ts < earliestTimestamp! {
                    earliestTimestamp = ts
                }
                if latestTimestamp == nil || ts > latestTimestamp! {
                    latestTimestamp = ts
                }
            }

            guard let type = obj["type"] as? String else { continue }

            if session.gitBranch == nil, let branch = obj["gitBranch"] as? String {
                session.gitBranch = branch
            }

            switch type {
            case "user":
                session.humanTurns += 1
            case "assistant":
                session.assistantTurns += 1
                parseAssistantEntry(obj, into: &session)
            default:
                break
            }
        }

        session.startedAt = earliestTimestamp
        session.endedAt = latestTimestamp

        guard session.totalTurns > 0 else { return nil }
        return session
    }

    private static func parseAssistantEntry(_ obj: [String: Any], into session: inout AISessionLog) {
        guard let message = obj["message"] as? [String: Any] else { return }

        if let model = message["model"] as? String {
            session.modelsUsed.insert(model)
        }

        if let usage = message["usage"] as? [String: Any] {
            session.tokens.input += usage["input_tokens"] as? Int ?? 0
            session.tokens.output += usage["output_tokens"] as? Int ?? 0
            session.tokens.cacheCreation += usage["cache_creation_input_tokens"] as? Int ?? 0
            session.tokens.cacheRead += usage["cache_read_input_tokens"] as? Int ?? 0
        }

        guard let content = message["content"] as? [[String: Any]] else { return }

        for block in content {
            guard block["type"] as? String == "tool_use",
                  let toolName = block["name"] as? String else { continue }

            session.toolsUsed[toolName, default: 0] += 1

            guard let input = block["input"] as? [String: Any] else { continue }

            switch toolName {
            case "Bash":
                if let command = input["command"] as? String {
                    session.bashCommands.append(command)
                }

            case "Read":
                if let path = input["file_path"] as? String {
                    session.filesTouched.append(AIFileTouched(path: path, action: .read))
                }

            case "Write":
                if let path = input["file_path"] as? String {
                    session.filesTouched.append(AIFileTouched(path: path, action: .write))
                }

            case "Edit":
                if let path = input["file_path"] as? String {
                    session.filesTouched.append(AIFileTouched(path: path, action: .edit))
                }

            case "MultiEdit":
                if let edits = input["edits"] as? [[String: Any]] {
                    for edit in edits {
                        if let path = edit["file_path"] as? String {
                            session.filesTouched.append(AIFileTouched(path: path, action: .multiEdit))
                        }
                    }
                }

            case "Grep":
                if let pattern = input["pattern"] as? String {
                    session.searchOperations.append(AISearchOperation(type: .grep, pattern: pattern))
                }

            case "Glob":
                if let pattern = input["pattern"] as? String {
                    session.searchOperations.append(AISearchOperation(type: .glob, pattern: pattern))
                }

            case "WebFetch":
                if let url = input["url"] as? String {
                    session.webFetches.append(url)
                }

            case "WebSearch":
                if let query = input["query"] as? String {
                    session.webSearches.append(query)
                }

            case "NotebookEdit":
                if let path = input["notebook_path"] as? String ?? input["file_path"] as? String {
                    session.filesTouched.append(AIFileTouched(path: path, action: .edit))
                }

            case "Agent":
                let desc = input["description"] as? String ?? ""
                let agentType = input["subagent_type"] as? String
                session.subagentSpawns.append(AISubagentSpawn(
                    description: desc, agentType: agentType
                ))

            default:
                // MCP tool calls: mcp__<server>__<tool>
                // e.g. mcp__claude_ai_Gmail__authenticate → server: claude_ai_Gmail, tool: authenticate
                if toolName.hasPrefix("mcp__") {
                    let withoutPrefix = String(toolName.dropFirst(5))
                    if let range = withoutPrefix.range(of: "__") {
                        let serverName = String(withoutPrefix[..<range.lowerBound])
                        let toolPart = String(withoutPrefix[range.upperBound...])
                        session.mcpCalls.append(AIMCPCall(
                            serverName: serverName, toolName: toolPart
                        ))
                    } else {
                        session.mcpCalls.append(AIMCPCall(
                            serverName: withoutPrefix, toolName: withoutPrefix
                        ))
                    }
                }
            }
        }
    }

    private static func parseTimestamp(_ value: Any?) -> Date? {
        guard let str = value as? String else { return nil }
        return isoFormatter.date(from: str) ?? isoFallback.date(from: str)
    }
}

// MARK: - Risk Detection Internals

extension ClaudeCodeAdapter {

    static let tokensPerFileWarn = 100_000
    static let tokensPerTurnWarn = 20_000
    static let maxSessionHours = 12.0

    static func detectSensitiveFileAccess(_ session: AISessionLog) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []
        let sensitiveFiles = session.filesTouched.filter { AIRiskEngine.isSensitivePath($0.path) }
        guard !sensitiveFiles.isEmpty else { return [] }

        let writes = sensitiveFiles.filter { $0.action == .write || $0.action == .edit || $0.action == .multiEdit }
        let reads = sensitiveFiles.filter { $0.action == .read }

        if !writes.isEmpty {
            let paths = writes.map(\.path).joined(separator: "\n  ")
            signals.append(AISecuritySignal(
                category: .sensitiveFileAccess, severity: .warning,
                title: "AI wrote to sensitive files",
                detail: "AI session modified \(writes.count) sensitive file(s) that may contain credentials or secrets.",
                evidence: paths, sessionID: session.id, projectPath: session.projectPath
            ))
        }

        if !reads.isEmpty {
            let paths = reads.map(\.path).joined(separator: "\n  ")
            signals.append(AISecuritySignal(
                category: .sensitiveFileAccess, severity: .concern,
                title: "AI read sensitive files",
                detail: "AI session accessed \(reads.count) sensitive file(s) that may contain credentials or secrets.",
                evidence: paths, sessionID: session.id, projectPath: session.projectPath
            ))
        }

        return signals
    }

    static func detectSuspiciousBash(_ session: AISessionLog) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        for command in session.bashCommands {
            let lower = command.lowercased()

            // Network exfiltration patterns
            if (lower.contains("curl") || lower.contains("wget")) && lower.contains("|") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash, severity: .warning,
                    title: "Piped network command",
                    detail: "Data piped to/from a network tool — could indicate exfiltration.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            // curl|sh / curl|bash — remote code execution
            if (lower.contains("curl") || lower.contains("wget")) &&
               (lower.contains("| sh") || lower.contains("| bash") || lower.contains("|sh") || lower.contains("|bash")) {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash, severity: .warning,
                    title: "Remote code execution",
                    detail: "Piping remote content directly into a shell. This is a common supply chain attack vector.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            if lower.contains("netcat") || lower.contains(" nc ") || lower.hasPrefix("nc ") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash, severity: .warning,
                    title: "Netcat usage",
                    detail: "Netcat can establish arbitrary network connections.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            if (lower.contains("scp ") || lower.contains("rsync ")) && lower.contains("@") {
                signals.append(AISecuritySignal(
                    category: .exfiltration, severity: .warning,
                    title: "Remote file transfer",
                    detail: "File transfer to a remote host detected.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            if lower.contains("base64") && lower.contains("|") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash, severity: .concern,
                    title: "Piped base64 encoding",
                    detail: "Base64 encoding in a pipeline — may be used to obfuscate data.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            if lower.contains("openssl enc") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash, severity: .concern,
                    title: "OpenSSL encryption",
                    detail: "OpenSSL encryption command — data may be encrypted before exfiltration.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            if lower.contains("/.ssh/") || lower.contains("/.aws/") || lower.contains("/.gnupg/")
                || lower.contains("/.kube/") || lower.contains("/.docker/") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash, severity: .concern,
                    title: "Credential directory access",
                    detail: "Command accessed a directory commonly containing credentials.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            // Unpinned npx — supply chain risk
            if lower.contains("npx ") && !command.contains("@") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash, severity: .concern,
                    title: "Unpinned npx execution",
                    detail: "Running npx without a pinned version could execute a compromised package.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            // sudo usage
            if lower.hasPrefix("sudo ") || lower.contains(" sudo ") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash, severity: .warning,
                    title: "Privilege escalation",
                    detail: "AI session used sudo to run a command with elevated privileges.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            // Destructive rm
            if lower.contains("rm -rf /") || lower.contains("rm -rf ~") || lower.contains("rm -rf $home") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash, severity: .warning,
                    title: "Destructive delete",
                    detail: "Recursive force-delete targeting a root or home directory.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            // macOS persistence / privilege tools
            if lower.contains("launchctl") || lower.contains("launchagents") || lower.contains("launchdaemons") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash, severity: .concern,
                    title: "Launch agent manipulation",
                    detail: "Command interacts with macOS launch agents or daemons — potential persistence mechanism.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            if lower.contains("osascript") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash, severity: .concern,
                    title: "AppleScript execution",
                    detail: "osascript can control other applications and access system features.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            // macOS keychain access
            if lower.contains("security find-") || lower.contains("security dump-") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash, severity: .warning,
                    title: "Keychain access",
                    detail: "Command queries the macOS keychain for stored credentials.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            // Cloud CLI credential access
            if lower.contains("gh auth token") || lower.contains("aws secretsmanager")
                || lower.contains("gcloud auth print-access-token") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash, severity: .concern,
                    title: "Cloud credential access",
                    detail: "Command extracts credentials from a cloud CLI tool.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            // Infrastructure mutation
            if lower.contains("kubectl exec") || lower.contains("kubectl apply")
                || lower.contains("terraform apply") || lower.contains("terraform destroy") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash, severity: .concern,
                    title: "Infrastructure mutation",
                    detail: "Command modifies live infrastructure (Kubernetes or Terraform).",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            // chmod 777
            if lower.contains("chmod 777") || lower.contains("chmod a+rwx") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash, severity: .concern,
                    title: "World-writable permissions",
                    detail: "Setting files to world-writable (777) weakens filesystem security.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }
        }

        return signals
    }

    // MARK: - Exfiltration Detection

    static func detectExfiltration(_ session: AISessionLog) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        for command in session.bashCommands {
            let lower = command.lowercased()

            // curl/wget/httpie POST-ing files
            if (lower.contains("curl") && (lower.contains("-x post") || lower.contains("--data") || lower.contains("-d @") || lower.contains("--upload")))
                || (lower.contains("http ") && lower.contains("post")) {
                signals.append(AISecuritySignal(
                    category: .exfiltration, severity: .warning,
                    title: "HTTP file upload",
                    detail: "Data sent to an external endpoint via HTTP POST.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            // Tunnel tools
            if lower.contains("ngrok") || lower.contains("bore ") || lower.contains("cloudflared tunnel") {
                signals.append(AISecuritySignal(
                    category: .exfiltration, severity: .warning,
                    title: "Network tunnel created",
                    detail: "A tunneling tool was invoked, potentially exposing local services to the internet.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }

            // Paste services
            let pasteServices = ["pastebin", "hastebin", "dpaste", "ix.io", "sprunge", "0x0.st", "transfer.sh"]
            for service in pasteServices {
                if lower.contains(service) {
                    signals.append(AISecuritySignal(
                        category: .exfiltration, severity: .concern,
                        title: "Data sent to paste service",
                        detail: "Content was uploaded to \(service), a public paste/file sharing service.",
                        evidence: truncateCommand(command),
                        sessionID: session.id, projectPath: session.projectPath
                    ))
                    break
                }
            }

            // socat outbound
            if lower.contains("socat") && lower.contains("tcp") {
                signals.append(AISecuritySignal(
                    category: .exfiltration, severity: .warning,
                    title: "Socat TCP connection",
                    detail: "socat was used to create a TCP connection — potential data exfiltration channel.",
                    evidence: truncateCommand(command),
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }
        }

        // WebFetch signals
        if !session.webFetches.isEmpty {
            signals.append(AISecuritySignal(
                category: .exfiltration, severity: .info,
                title: "Web requests made",
                detail: "Session fetched \(session.webFetches.count) URL(s). Review for data leakage via URL parameters.",
                evidence: session.webFetches.prefix(5).joined(separator: "\n"),
                sessionID: session.id, projectPath: session.projectPath
            ))
        }

        return signals
    }

    static func detectTokenmaxxing(_ session: AISessionLog) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        let filesCount = max(Set(session.filesTouched.map(\.path)).count, 1)
        let tokensPerFile = session.tokens.output / filesCount

        if tokensPerFile > tokensPerFileWarn && session.tokens.output > 10_000 {
            signals.append(AISecuritySignal(
                category: .tokenmaxxing, severity: .concern,
                title: "High token-to-file ratio",
                detail: "\(formatTokens(session.tokens.output)) output tokens across \(filesCount) file(s) — \(formatTokens(tokensPerFile)) per file.",
                evidence: "Threshold: \(formatTokens(tokensPerFileWarn)) tokens/file",
                sessionID: session.id, projectPath: session.projectPath
            ))
        }

        if session.assistantTurns > 0 {
            let tokensPerTurn = session.tokens.output / session.assistantTurns
            if tokensPerTurn > tokensPerTurnWarn {
                signals.append(AISecuritySignal(
                    category: .tokenmaxxing, severity: .info,
                    title: "High tokens per turn",
                    detail: "\(formatTokens(tokensPerTurn)) output tokens per assistant turn over \(session.assistantTurns) turns.",
                    evidence: "Threshold: \(formatTokens(tokensPerTurnWarn)) tokens/turn",
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }
        }

        return signals
    }

    static func detectLongSession(_ session: AISessionLog) -> [AISecuritySignal] {
        guard let hours = session.durationHours, hours > maxSessionHours else { return [] }

        return [AISecuritySignal(
            category: .longSession, severity: .warning,
            title: "Extremely long session",
            detail: "Session ran for \(String(format: "%.1f", hours)) hours.",
            evidence: "Threshold: \(String(format: "%.0f", maxSessionHours)) hours",
            sessionID: session.id, projectPath: session.projectPath
        )]
    }

    static func detectAgentActionConcerns(_ session: AISessionLog) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        let totalToolUses = session.toolsUsed.values.reduce(0, +)
        guard totalToolUses > 0 else { return signals }

        if session.humanTurns > 0 {
            let ratio = Double(totalToolUses) / Double(session.humanTurns)
            if ratio > 50 {
                signals.append(AISecuritySignal(
                    category: .agentAction, severity: .concern,
                    title: "High autonomous action rate",
                    detail: "\(totalToolUses) tool uses across \(session.humanTurns) human turn(s) — ratio of \(String(format: "%.0f", ratio)):1.",
                    evidence: "May indicate extended agentic loops with minimal human oversight.",
                    sessionID: session.id, projectPath: session.projectPath
                ))
            } else if ratio > 20 {
                signals.append(AISecuritySignal(
                    category: .agentAction, severity: .info,
                    title: "Elevated autonomous actions",
                    detail: "\(totalToolUses) tool uses across \(session.humanTurns) human turn(s) — ratio of \(String(format: "%.0f", ratio)):1.",
                    evidence: "Moderate level of autonomous tool use per human interaction.",
                    sessionID: session.id, projectPath: session.projectPath
                ))
            }
        }

        if session.bashCommands.count > 50 {
            signals.append(AISecuritySignal(
                category: .agentAction, severity: .info,
                title: "Heavy shell usage",
                detail: "\(session.bashCommands.count) bash commands executed in a single session.",
                evidence: "High command volume increases the surface area for unintended actions.",
                sessionID: session.id, projectPath: session.projectPath
            ))
        }

        return signals
    }

    private static func truncateCommand(_ command: String, maxLength: Int = 200) -> String {
        if command.count <= maxLength { return command }
        return String(command.prefix(maxLength)) + "..."
    }

    private static func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Permission Categorization

extension ClaudeCodeAdapter {

    static func categorizePermissions(
        allow: [String], deny: [String], ask: [String]
    ) -> PermissionSummary {
        PermissionSummary(
            allowed: groupPermissions(allow),
            denied: groupPermissions(deny),
            requiresApproval: groupPermissions(ask)
        )
    }

    private static func groupPermissions(_ perms: [String]) -> [PermissionGroup] {
        var groups: [String: [String]] = [:]

        for perm in perms {
            if perm.hasPrefix("Bash(") {
                let cmd = String(perm.dropFirst(5).prefix(while: { $0 != ":" && $0 != ")" }))
                groups["Shell Commands", default: []].append(cmd)
            } else if perm.hasPrefix("Read(") {
                let path = String(perm.dropFirst(5).dropLast())
                groups["File Access", default: []].append(path)
            } else if perm.hasPrefix("Write(") || perm == "Edit" || perm == "Write" {
                groups["File Writing", default: []].append(perm)
            } else if perm.hasPrefix("WebFetch") {
                let domain = perm.contains("domain:") ?
                    String(perm.split(separator: ":").last?.dropLast() ?? "") : "any"
                groups["Web Access", default: []].append(domain)
            } else if perm == "WebSearch" {
                groups["Web Access", default: []].append("search")
            } else if perm.hasPrefix("mcp__") {
                let parts = perm.split(separator: "__")
                let server = parts.count > 1 ? String(parts[1]) : perm
                groups["MCP (\(server))", default: []].append(
                    parts.count > 2 ? String(parts[2]) : perm
                )
            } else {
                groups["Other", default: []].append(perm)
            }
        }

        return groups.map { PermissionGroup(category: $0.key, items: $0.value) }
            .sorted { $0.category < $1.category }
    }

    static func generateSummary(
        permissions: PermissionSummary, mcpServers: [String],
        envVarCount: Int, hasHooks: Bool
    ) -> [String] {
        var summary: [String] = []

        let allowedCategories = Set(permissions.allowed.map(\.category))
        let deniedCategories = Set(permissions.denied.map(\.category))

        if allowedCategories.contains("Shell Commands") {
            let cmds = permissions.allowed.first { $0.category == "Shell Commands" }?.items ?? []
            summary.append("Can run \(cmds.count) shell commands automatically (e.g., \(cmds.prefix(3).joined(separator: ", ")))")
        }

        if allowedCategories.contains("Web Access") {
            let domains = permissions.allowed.first { $0.category == "Web Access" }?.items ?? []
            summary.append("Can access \(domains.count) web domains and search the web")
        }

        if !mcpServers.isEmpty {
            summary.append("Connected to \(mcpServers.count) MCP server\(mcpServers.count == 1 ? "" : "s"): \(mcpServers.joined(separator: ", "))")
        }

        if deniedCategories.contains("Shell Commands") {
            let cmds = permissions.denied.first { $0.category == "Shell Commands" }?.items ?? []
            summary.append("Blocked from: \(cmds.joined(separator: ", "))")
        }

        if deniedCategories.contains("File Access") {
            summary.append("Cannot read sensitive files (SSH keys, credentials, .env)")
        }

        let askCategories = Set(permissions.requiresApproval.map(\.category))
        if askCategories.contains("Shell Commands") {
            let cmds = permissions.requiresApproval.first { $0.category == "Shell Commands" }?.items ?? []
            summary.append("Requires approval for: \(cmds.prefix(4).joined(separator: ", "))\(cmds.count > 4 ? ", ..." : "")")
        }

        if hasHooks {
            summary.append("Custom hooks are configured (automated actions on events)")
        }

        if envVarCount > 0 {
            summary.append("\(envVarCount) environment variables configured")
        }

        return summary
    }
}
