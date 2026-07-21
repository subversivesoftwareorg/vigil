import Foundation

/// Cross-tool risk detections that operate on config posture, file sharing overlap,
/// and MCP server configurations. Complements per-session detections in each adapter.
enum AIRiskEngine {

    // MARK: - File Sharing Cross-Correlation

    static func detectFileSharingExposure(sessions: [AISessionLog]) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        for session in sessions {
            for file in session.filesTouched {
                guard file.action == .write || file.action == .edit || file.action == .multiEdit else { continue }
                let lower = file.path.lowercased()

                for pattern in FileSharingCatalog.pathPatterns {
                    if lower.contains(pattern.pattern.lowercased()) {
                        let isSensitive = isSensitivePath(file.path)
                        let severity: SignalSeverity = isSensitive ? .warning : .concern

                        signals.append(AISecuritySignal(
                            category: .fileSharingExposure,
                            severity: severity,
                            title: isSensitive
                                ? "AI wrote sensitive file in \(pattern.tool) directory"
                                : "AI wrote file in \(pattern.tool) synced directory",
                            detail: "File \(URL(fileURLWithPath: file.path).lastPathComponent) was \(file.action.rawValue) by an AI session in a \(pattern.tool)-synced directory. This file may be automatically uploaded.",
                            evidence: file.path,
                            sessionID: session.id,
                            projectPath: session.projectPath
                        ))
                        break
                    }
                }
            }
        }

        return signals
    }

    // MARK: - MCP Risk Detection

    static func detectMCPRisks(configs: [AIToolConfig]) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        for config in configs {
            for server in config.mcpServerDetails {
                // Auto-approved tools
                if !server.autoApprovedTools.isEmpty {
                    signals.append(AISecuritySignal(
                        category: .mcpRisk,
                        severity: .concern,
                        title: "MCP server has auto-approved tools",
                        detail: "\(server.name) in \(config.tool) has \(server.autoApprovedTools.count) auto-approved tool(s): \(server.autoApprovedTools.prefix(5).joined(separator: ", ")). These execute without user confirmation.",
                        evidence: "Source: \(server.source)"
                    ))
                }

                // Broad env var passthrough
                let riskyEnvVars = server.envVars.keys.filter { key in
                    let k = key.uppercased()
                    return k == "PATH" || k == "HOME" || k.hasPrefix("AWS_")
                        || k.hasPrefix("GOOGLE_") || k.hasPrefix("AZURE_")
                        || k == "GITHUB_TOKEN" || k == "NPM_TOKEN"
                        || k == "OPENAI_API_KEY" || k == "ANTHROPIC_API_KEY"
                }
                if !riskyEnvVars.isEmpty {
                    signals.append(AISecuritySignal(
                        category: .mcpRisk,
                        severity: .concern,
                        title: "MCP server receives sensitive env vars",
                        detail: "\(server.name) in \(config.tool) receives \(riskyEnvVars.count) sensitive environment variable(s).",
                        evidence: riskyEnvVars.joined(separator: ", ")
                    ))
                }

                // Unpinned npm/pip packages in startup command
                if let command = server.command {
                    if command.contains("npx ") && !command.contains("@") {
                        signals.append(AISecuritySignal(
                            category: .mcpRisk,
                            severity: .warning,
                            title: "MCP server uses unpinned npx package",
                            detail: "\(server.name) in \(config.tool) starts with an unpinned npx command. This could execute arbitrary code if the package is compromised.",
                            evidence: command
                        ))
                    }
                    if command.contains("uvx ") || command.contains("pipx run ") {
                        if !command.contains("==") {
                            signals.append(AISecuritySignal(
                                category: .mcpRisk,
                                severity: .concern,
                                title: "MCP server uses unpinned Python package",
                                detail: "\(server.name) in \(config.tool) starts with an unpinned Python package runner.",
                                evidence: command
                            ))
                        }
                    }
                }
            }
        }

        return signals
    }

    // MARK: - Excessive Agency Detection (Config-Based)

    static func detectExcessiveAgency(configs: [AIToolConfig]) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        for config in configs {
            if config.autoMode {
                signals.append(AISecuritySignal(
                    category: .excessiveAgency,
                    severity: .concern,
                    title: "\(config.tool) has broad auto-approval",
                    detail: "Configuration grants extensive automatic permissions, reducing human oversight over tool actions.",
                    evidence: "Allowed: \(config.permissions.totalAllowed) items, Denied: \(config.permissions.totalDenied) items"
                ))
            }

            // Network access without approval
            if let networkAccess = config.networkAccess, networkAccess {
                signals.append(AISecuritySignal(
                    category: .excessiveAgency,
                    severity: .info,
                    title: "\(config.tool) has network access enabled",
                    detail: "The tool can make outbound network requests.",
                    evidence: "Network access: enabled"
                ))
            }
        }

        return signals
    }

    // MARK: - Privacy Posture Risk Detection

    static func detectPrivacyRisks(postures: [AIPrivacyPosture]) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        for posture in postures {
            let elevated = posture.grants.filter { $0.granted && $0.service.isElevated }
            for grant in elevated {
                signals.append(AISecuritySignal(
                    category: .excessiveAgency,
                    severity: .warning,
                    title: "\(posture.displayName) has \(grant.service.displayName)",
                    detail: "\(posture.displayName) has been granted \(grant.service.displayName) access. Combined with AI agent capabilities, this significantly increases blast radius.",
                    evidence: "Bundle: \(posture.bundleID), Service: \(grant.service.rawValue)"
                ))
            }

            if !posture.launchAgents.isEmpty {
                let labels = posture.launchAgents.map(\.label).joined(separator: ", ")
                signals.append(AISecuritySignal(
                    category: .excessiveAgency,
                    severity: .info,
                    title: "\(posture.displayName) has LaunchAgent persistence",
                    detail: "\(posture.launchAgents.count) LaunchAgent(s) found for \(posture.displayName). These run at login without explicit user action.",
                    evidence: labels
                ))
            }
        }

        return signals
    }

    // MARK: - Tool Shadowing Detection

    static func detectToolShadowing(configs: [AIToolConfig]) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        // Build a map of tool names to the servers that provide them
        // MCP tool names follow: mcp__<server>__<tool>
        // If two servers register a tool with the same name, one shadows the other
        var toolProviders: [String: [(server: String, tool: String, source: String)]] = [:]

        for config in configs {
            for server in config.mcpServerDetails {
                // Each auto-approved tool name is a known tool on this server
                for toolName in server.autoApprovedTools {
                    let key = toolName.lowercased()
                    toolProviders[key, default: []].append(
                        (server: server.name, tool: config.tool, source: server.source)
                    )
                }
            }
        }

        // Also check for servers with identical names across different tools
        var serverNames: [String: [(tool: String, source: String)]] = [:]
        for config in configs {
            for server in config.mcpServerDetails {
                serverNames[server.name, default: []].append(
                    (tool: config.tool, source: server.source)
                )
            }
        }

        for (name, providers) in serverNames where providers.count > 1 {
            let tools = providers.map { "\($0.tool) (\($0.source))" }.joined(separator: ", ")
            signals.append(AISecuritySignal(
                category: .toolShadowing,
                severity: .concern,
                title: "MCP server name registered in multiple tools",
                detail: "Server \"\(name)\" is configured in \(providers.count) tools: \(tools). If both are active, tool calls could route to an unintended server.",
                evidence: "Server: \(name)"
            ))
        }

        return signals
    }

    // MARK: - Dangerous Tool Combination Detection

    static func detectDangerousCombinations(sessions: [AISessionLog]) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        let dangerousPatterns: [(read: String, write: String, risk: String)] = [
            ("read", "send", "data exfiltration via messaging"),
            ("read", "email", "data exfiltration via email"),
            ("read", "post", "data exfiltration via HTTP"),
            ("get", "send", "data exfiltration via messaging"),
            ("get", "email", "data exfiltration via email"),
            ("query", "create_gist", "database content published to gist"),
            ("query", "post", "database content sent externally"),
            ("search", "send", "search results forwarded externally"),
            ("list", "upload", "listed data uploaded externally"),
            ("read_file", "send_message", "file content sent via messaging"),
            ("get_secret", "post", "secret exfiltrated via HTTP"),
        ]

        for session in sessions {
            guard session.mcpCalls.count >= 2 else { continue }

            let serverNames = Set(session.mcpCalls.map(\.serverName))
            guard serverNames.count >= 2 else { continue }

            let toolNames = session.mcpCalls.map { $0.toolName.lowercased() }

            for pattern in dangerousPatterns {
                let hasRead = toolNames.contains { $0.contains(pattern.read) }
                let hasWrite = toolNames.contains { $0.contains(pattern.write) }

                if hasRead && hasWrite {
                    let readServers = session.mcpCalls
                        .filter { $0.toolName.lowercased().contains(pattern.read) }
                        .map(\.serverName)
                    let writeServers = session.mcpCalls
                        .filter { $0.toolName.lowercased().contains(pattern.write) }
                        .map(\.serverName)

                    // Only flag if the read and write hit different servers
                    guard Set(readServers).intersection(Set(writeServers)).isEmpty else { continue }

                    signals.append(AISecuritySignal(
                        category: .toolCombination,
                        severity: .concern,
                        title: "Potentially dangerous tool combination",
                        detail: "Session used \(pattern.read)-type tools on \(readServers.first ?? "?") and \(pattern.write)-type tools on \(writeServers.first ?? "?") — risk: \(pattern.risk).",
                        evidence: "Tools: \(toolNames.joined(separator: ", "))",
                        sessionID: session.id,
                        projectPath: session.projectPath
                    ))
                    break
                }
            }
        }

        return signals
    }

    // MARK: - Cross-Server Data Flow Detection

    static func detectCrossServerFlows(sessions: [AISessionLog]) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        let sensitiveServerPatterns = [
            "database", "db", "postgres", "mysql", "mongo", "redis",
            "secret", "vault", "credential", "keychain",
            "internal", "private", "admin",
        ]

        let externalServerPatterns = [
            "email", "gmail", "mail", "outlook",
            "slack", "discord", "telegram", "chat",
            "gist", "pastebin", "paste",
            "webhook", "http", "api",
            "drive", "dropbox", "s3",
        ]

        for session in sessions {
            guard session.mcpCalls.count >= 2 else { continue }

            let servers = session.mcpCalls.map(\.serverName)
            let uniqueServers = Set(servers)
            guard uniqueServers.count >= 2 else { continue }

            let sensitiveServers = uniqueServers.filter { server in
                let lower = server.lowercased()
                return sensitiveServerPatterns.contains { lower.contains($0) }
            }

            let externalServers = uniqueServers.filter { server in
                let lower = server.lowercased()
                return externalServerPatterns.contains { lower.contains($0) }
            }

            if !sensitiveServers.isEmpty && !externalServers.isEmpty {
                signals.append(AISecuritySignal(
                    category: .crossServerFlow,
                    severity: .warning,
                    title: "Data flow from sensitive to external MCP server",
                    detail: "Session accessed sensitive server(s) \(sensitiveServers.joined(separator: ", ")) and external server(s) \(externalServers.joined(separator: ", ")). Data may have flowed between them via the shared context window.",
                    evidence: "All MCP servers in session: \(uniqueServers.sorted().joined(separator: ", "))",
                    sessionID: session.id,
                    projectPath: session.projectPath
                ))
            }
        }

        return signals
    }

    // MARK: - Config Drift Detection

    static func detectConfigDrift(configs: [AIToolConfig], database: Database?) -> [AISecuritySignal] {
        guard let database else { return [] }
        var signals: [AISecuritySignal] = []

        for config in configs {
            let toolID = AIInventoryEntry.toolID(from: config.tool)
            guard let previous = database.loadLatestConfigSnapshot(toolID: toolID) else { continue }

            guard let prevData = previous.configJSON.data(using: .utf8),
                  let prevDict = try? JSONSerialization.jsonObject(with: prevData) as? [String: Any] else {
                continue
            }

            let prevMCP = prevDict["mcpServers"] as? [String] ?? []
            let currentMCP = config.mcpServers

            let added = Set(currentMCP).subtracting(Set(prevMCP))
            let removed = Set(prevMCP).subtracting(Set(currentMCP))

            for name in added {
                signals.append(AISecuritySignal(
                    category: .configDrift,
                    severity: .concern,
                    title: "New MCP server added to \(config.tool)",
                    detail: "MCP server \"\(name)\" was added since the last scan. Review its configuration and permissions.",
                    evidence: "Tool: \(config.tool), Server: \(name)"
                ))
            }

            for name in removed {
                signals.append(AISecuritySignal(
                    category: .configDrift,
                    severity: .info,
                    title: "MCP server removed from \(config.tool)",
                    detail: "MCP server \"\(name)\" was removed since the last scan.",
                    evidence: "Tool: \(config.tool), Server: \(name)"
                ))
            }

            // Check permissions changes
            let prevHash = previous.permissionsHash ?? ""
            let currentHash = "a:\(config.permissions.totalAllowed)|d:\(config.permissions.totalDenied)|q:\(config.permissions.totalAsk)"
            if !prevHash.isEmpty && prevHash != currentHash {
                signals.append(AISecuritySignal(
                    category: .configDrift,
                    severity: .info,
                    title: "Permission changes in \(config.tool)",
                    detail: "Permission counts changed from \(prevHash) to \(currentHash).",
                    evidence: "Previous: \(prevHash), Current: \(currentHash)"
                ))
            }
        }

        return signals
    }

    // MARK: - Tool Description Injection Scanning

    static func detectToolDescriptionInjection(toolDefinitions: [MCPToolDefinition]) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        let injectionPatterns: [(pattern: String, risk: String)] = [
            ("ignore previous", "instruction override attempt"),
            ("ignore above", "instruction override attempt"),
            ("disregard", "instruction override attempt"),
            ("you must", "directive injection"),
            ("you should", "directive injection"),
            ("always ", "directive injection"),
            ("never ", "directive injection"),
            ("do not tell", "secrecy instruction"),
            ("don't tell", "secrecy instruction"),
            ("keep secret", "secrecy instruction"),
            ("hidden instruction", "explicit injection marker"),
            ("system prompt", "prompt manipulation"),
            ("<system>", "XML injection attempt"),
            ("</system>", "XML injection attempt"),
            ("<tool_result>", "XML injection attempt"),
            ("~/.ssh", "sensitive path reference"),
            ("~/.aws", "sensitive path reference"),
            ("~/.gnupg", "sensitive path reference"),
            (".env", "sensitive file reference"),
            ("id_rsa", "SSH key reference"),
            ("credentials", "credential file reference"),
            ("api_key", "API key reference"),
            ("access_token", "token reference"),
            ("password", "password reference"),
            ("curl ", "embedded command"),
            ("wget ", "embedded command"),
            ("exec(", "code execution"),
            ("eval(", "code execution"),
            ("base64", "encoding/obfuscation"),
            ("send_email", "cross-tool reference"),
            ("send_message", "cross-tool reference"),
            ("create_gist", "cross-tool reference"),
            ("upload", "exfiltration verb"),
        ]

        for tool in toolDefinitions {
            let description = tool.description.lowercased()
            guard !description.isEmpty else { continue }

            for (pattern, risk) in injectionPatterns {
                if description.contains(pattern.lowercased()) {
                    signals.append(AISecuritySignal(
                        category: .toolDescriptionInjection,
                        severity: pattern.contains("ignore") || pattern.contains("system") ? .warning : .concern,
                        title: "Suspicious content in MCP tool description",
                        detail: "Tool \"\(tool.name)\" on server \"\(tool.serverName)\" has a description containing \"\(pattern)\" — \(risk).",
                        evidence: "Description excerpt: \(String(tool.description.prefix(200)))"
                    ))
                    break
                }
            }
        }

        return signals
    }

    // MARK: - Shared Helpers

    private static let sensitivePatterns: [(pattern: String, matchType: PatternMatch)] = [
        (".env", .exact), (".env.local", .exact), (".env.production", .exact),
        (".env.development", .exact), (".env.staging", .exact),
        ("credentials", .prefix), ("credentials.json", .exact), ("credentials.yaml", .exact),
        ("id_rsa", .exact), ("id_ed25519", .exact), ("id_ecdsa", .exact),
        ("id_dsa", .exact), ("authorized_keys", .exact), ("known_hosts", .exact),
        (".pem", .suffix), (".key", .suffix), (".p12", .suffix), (".pfx", .suffix),
        (".jks", .suffix), (".keystore", .suffix), (".crt", .suffix),
        ("secret", .prefix), ("secrets.yaml", .exact), ("secrets.json", .exact),
        ("aws_access", .prefix), (".aws", .exact),
        ("service_account", .prefix), ("serviceAccountKey", .prefix),
        ("password", .prefix), ("passwords", .exact),
        ("kubeconfig", .exact), (".kube", .exact),
        (".npmrc", .exact), (".pypirc", .exact), (".netrc", .exact),
        (".tfstate", .suffix), ("terraform.tfvars", .exact),
        ("pulumi.yaml", .exact), ("Pulumi.yaml", .exact),
        (".gnupg", .exact), (".gpg", .suffix),
        (".sops.yaml", .exact), ("sops.yaml", .exact),
        (".docker/config.json", .exact), ("docker-compose.override", .prefix),
        ("token", .exact), ("tokens.json", .exact), (".token", .exact),
    ]

    private enum PatternMatch {
        case exact, prefix, suffix
    }

    static func isSensitivePath(_ path: String) -> Bool {
        let filename = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        for (pattern, matchType) in sensitivePatterns {
            let p = pattern.lowercased()
            switch matchType {
            case .exact:
                if filename == p { return true }
            case .prefix:
                if filename.hasPrefix(p) { return true }
            case .suffix:
                if filename.hasSuffix(p) { return true }
            }
        }
        return false
    }
}
