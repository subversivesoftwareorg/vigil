import Foundation

struct ClaudeDesktopAdapter: AIToolAdapter {
    let toolID = "claude-desktop"
    let displayName = "Claude Desktop"
    let provider = "Anthropic"
    let category = AICategory.chatApp

    var processSignatures: [ProcessSignature] {
        [
            ProcessSignature(pattern: "Claude", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "Claude", matchMode: .substring, displayName: displayName),
        ]
    }

    var pathSignatures: [PathSignature] {
        [PathSignature(pattern: "/Library/Application Support/Claude/", pathCategory: .workspaceData, tool: displayName)]
    }

    // MARK: - Config Reading

    func readConfig() -> AIToolConfig? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let appSupport = "\(home)/Library/Application Support/Claude"
        guard fm.fileExists(atPath: appSupport) else { return nil }

        var foundLayers: [SettingsLayer] = []
        var mcpServerNames: [String] = []
        var mcpDetails: [MCPServerDetail] = []

        // Read claude_desktop_config.json if it exists
        let configPath = "\(appSupport)/claude_desktop_config.json"
        if let data = fm.contents(atPath: configPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            foundLayers.append(SettingsLayer(path: configPath, label: "Desktop config"))

            if let servers = json["mcpServers"] as? [String: Any] {
                for (name, value) in servers {
                    mcpServerNames.append(name)
                    if let serverConfig = value as? [String: Any] {
                        mcpDetails.append(MCPServerDetail(
                            name: name,
                            command: serverConfig["command"] as? String,
                            args: serverConfig["args"] as? [String] ?? [],
                            envVars: serverConfig["env"] as? [String: String] ?? [:],
                            autoApprovedTools: [],
                            source: "Desktop config"
                        ))
                    }
                }
            }
        }

        // Discover remote MCP servers from session files
        let sessionServers = discoverRemoteMCPServers()
        for server in sessionServers {
            if !mcpServerNames.contains(server.name) {
                mcpServerNames.append(server.name)
                mcpDetails.append(server)
            }
        }

        if foundLayers.isEmpty && sessionServers.isEmpty {
            return nil
        }

        if foundLayers.isEmpty && !sessionServers.isEmpty {
            foundLayers.append(SettingsLayer(path: appSupport, label: "Desktop sessions"))
        }

        return AIToolConfig(
            tool: displayName,
            provider: provider,
            layers: foundLayers,
            permissions: PermissionSummary(allowed: [], denied: [], requiresApproval: []),
            envVarCount: 0,
            mcpServers: mcpServerNames,
            hasHooks: false,
            summary: mcpServerNames.isEmpty ? [] : [
                "Connected to \(mcpServerNames.count) MCP server\(mcpServerNames.count == 1 ? "" : "s"): \(mcpServerNames.joined(separator: ", "))"
            ],
            mcpServerDetails: mcpDetails
        )
    }

    // MARK: - Tool Definition Extraction

    func discoverToolDefinitions() -> [MCPToolDefinition] {
        var definitions: [MCPToolDefinition] = []
        let sessions = discoverSessionFiles()

        // Deduplicate by server+tool name, keeping the most recent
        var seen = Set<String>()

        for sessionPath in sessions {
            guard let data = FileManager.default.contents(atPath: sessionPath),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let remoteMCP = json["remoteMcpServersConfig"] as? [[String: Any]] else {
                continue
            }

            for serverConfig in remoteMCP {
                let serverName = serverConfig["name"] as? String ?? "unknown"
                guard let tools = serverConfig["tools"] as? [[String: Any]] else { continue }

                for tool in tools {
                    let toolName = tool["name"] as? String ?? ""
                    let key = "\(serverName)|\(toolName)"
                    guard seen.insert(key).inserted else { continue }

                    let description = tool["description"] as? String ?? ""
                    var schemaJSON = ""
                    if let schema = tool["inputSchema"] as? [String: Any],
                       let schemaData = try? JSONSerialization.data(withJSONObject: schema),
                       let schemaStr = String(data: schemaData, encoding: .utf8) {
                        schemaJSON = schemaStr
                    }

                    definitions.append(MCPToolDefinition(
                        serverName: serverName,
                        name: toolName,
                        description: description,
                        inputSchemaJSON: schemaJSON
                    ))
                }
            }
        }

        return definitions
    }

    // MARK: - Private Helpers

    private func discoverRemoteMCPServers() -> [MCPServerDetail] {
        var servers: [MCPServerDetail] = []
        var seen = Set<String>()
        let sessions = discoverSessionFiles()

        for sessionPath in sessions {
            guard let data = FileManager.default.contents(atPath: sessionPath),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let remoteMCP = json["remoteMcpServersConfig"] as? [[String: Any]] else {
                continue
            }

            for serverConfig in remoteMCP {
                let name = serverConfig["name"] as? String ?? "unknown"
                guard seen.insert(name).inserted else { continue }

                let url = serverConfig["url"] as? String
                let toolCount = (serverConfig["tools"] as? [[String: Any]])?.count ?? 0

                servers.append(MCPServerDetail(
                    name: name,
                    command: url,
                    args: [],
                    envVars: [:],
                    autoApprovedTools: [],
                    source: "Desktop remote (\(toolCount) tools)"
                ))
            }
        }

        return servers
    }

    private func discoverSessionFiles() -> [String] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let sessionsRoot = "\(home)/Library/Application Support/Claude/local-agent-mode-sessions"
        guard fm.fileExists(atPath: sessionsRoot) else { return [] }

        var sessionFiles: [String] = []

        guard let accountDirs = try? fm.contentsOfDirectory(atPath: sessionsRoot) else { return [] }
        for accountDir in accountDirs where !accountDir.hasPrefix(".") {
            let accountPath = "\(sessionsRoot)/\(accountDir)"
            guard let orgDirs = try? fm.contentsOfDirectory(atPath: accountPath) else { continue }
            for orgDir in orgDirs where !orgDir.hasPrefix(".") {
                let orgPath = "\(accountPath)/\(orgDir)"
                guard let files = try? fm.contentsOfDirectory(atPath: orgPath) else { continue }
                for file in files where file.hasPrefix("local_") && file.hasSuffix(".json") {
                    sessionFiles.append("\(orgPath)/\(file)")
                }
            }
        }

        return sessionFiles
    }
}
