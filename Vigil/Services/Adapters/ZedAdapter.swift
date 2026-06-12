import Foundation

struct ZedAdapter: AIToolAdapter {
    let toolID = "zed"
    let displayName = "Zed"
    let provider = "Zed Industries"
    let category = AICategory.codingAssistant

    var processSignatures: [ProcessSignature] {
        [
            ProcessSignature(pattern: "Zed", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "zed", matchMode: .exact, displayName: displayName),
        ]
    }

    var pathSignatures: [PathSignature] {
        [
            PathSignature(pattern: "/.config/zed/", pathCategory: .workspaceData, tool: displayName),
            PathSignature(pattern: "/Application Support/Zed/", pathCategory: .workspaceData, tool: displayName),
        ]
    }

    func readConfig() -> AIToolConfig? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fm = FileManager.default

        let settingsPath = "\(home)/.config/zed/settings.json"
        let appSupportPath = "\(home)/Library/Application Support/Zed"

        // Zed settings.json uses JSONC (comments allowed) — strip them before parsing
        guard let content = Self.readFile(settingsPath),
              let json = Self.parseJSONC(content) else {
            // Fall back: if no settings but App Support exists, still report the tool
            guard fm.fileExists(atPath: appSupportPath) else { return nil }
            return AIToolConfig(
                tool: displayName, provider: provider,
                layers: [SettingsLayer(path: appSupportPath, label: "App Support")],
                permissions: PermissionSummary(allowed: [], denied: [], requiresApproval: []),
                envVarCount: 0, mcpServers: [], hasHooks: false,
                summary: ["Zed is installed but no user settings found."]
            )
        }

        var foundLayers = [SettingsLayer(path: settingsPath, label: "User settings")]

        // AI agent config
        let agentConfig = json["agent"] as? [String: Any]

        // Language model config
        let lmConfig = json["language_model"] as? [String: Any]

        // Assistant config (older Zed versions)
        let assistantConfig = json["assistant"] as? [String: Any]
        let defaultModel = assistantConfig?["default_model"] as? [String: Any]
        let modelName = defaultModel?["model"] as? String
        let modelProvider = defaultModel?["provider"] as? String
            ?? lmConfig?["provider"] as? String

        // MCP servers (Zed supports MCP via context_servers)
        var mcpServerNames: [String] = []
        var mcpDetails: [MCPServerDetail] = []
        if let contextServers = json["context_servers"] as? [String: Any] {
            for (name, value) in contextServers {
                mcpServerNames.append(name)
                if let serverConfig = value as? [String: Any],
                   let settings = serverConfig["settings"] as? [String: Any] {
                    mcpDetails.append(MCPServerDetail(
                        name: name,
                        command: settings["command"] as? String,
                        args: settings["args"] as? [String] ?? [],
                        envVars: (settings["env"] as? [String: String]) ?? [:],
                        autoApprovedTools: [],
                        source: "~/.config/zed/settings.json"
                    ))
                }
            }
        }

        // External agents (~/Library/Application Support/Zed/external_agents/)
        var externalAgents: [String] = []
        let agentsPath = "\(appSupportPath)/external_agents"
        if let agentDirs = try? fm.contentsOfDirectory(atPath: agentsPath) {
            for dir in agentDirs where dir != "registry" && !dir.hasPrefix(".") {
                externalAgents.append(dir)
            }
        }

        // Extensions
        var extensionCount = 0
        let extensionsIndex = "\(appSupportPath)/extensions/index.json"
        if let data = fm.contents(atPath: extensionsIndex),
           let indexJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let exts = indexJSON["extensions"] as? [String: Any] {
            extensionCount = exts.count
        }

        // Threads database
        let threadsDB = "\(appSupportPath)/threads/threads.db"
        if fm.fileExists(atPath: threadsDB) {
            foundLayers.append(SettingsLayer(path: threadsDB, label: "AI threads"))
        }

        // Build summary
        var summary: [String] = []
        if let modelName {
            summary.append("AI model: \(modelName)\(modelProvider.map { " (\($0))" } ?? "")")
        }
        if agentConfig != nil {
            summary.append("Agent mode configured")
        }
        if !mcpServerNames.isEmpty {
            summary.append("\(mcpServerNames.count) context server\(mcpServerNames.count == 1 ? "" : "s")")
        }
        if !externalAgents.isEmpty {
            summary.append("External agents: \(externalAgents.joined(separator: ", "))")
        }
        if extensionCount > 0 {
            summary.append("\(extensionCount) extension\(extensionCount == 1 ? "" : "s") installed")
        }
        if summary.isEmpty {
            summary.append("Zed is installed with AI capabilities available")
        }

        var config = AIToolConfig(
            tool: displayName, provider: provider,
            layers: foundLayers,
            permissions: PermissionSummary(
                allowed: [PermissionGroup(category: "Editor", items: ["Full IDE access"])],
                denied: [], requiresApproval: []
            ),
            envVarCount: 0,
            mcpServers: mcpServerNames,
            hasHooks: false,
            summary: summary
        )
        config.mcpServerDetails = mcpDetails
        return config
    }

    // MARK: - Helpers

    private static func readFile(_ path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Strip // and /* */ comments from JSONC (used by Zed's settings.json)
    private static func parseJSONC(_ content: String) -> [String: Any]? {
        var result = ""
        var inString = false
        var inLineComment = false
        var inBlockComment = false
        var prev: Character = " "

        for char in content {
            if inLineComment {
                if char == "\n" { inLineComment = false; result.append(char) }
                prev = char
                continue
            }
            if inBlockComment {
                if prev == "*" && char == "/" { inBlockComment = false }
                prev = char
                continue
            }
            if char == "\"" && prev != "\\" { inString.toggle() }
            if !inString {
                if prev == "/" && char == "/" {
                    result.removeLast()
                    inLineComment = true
                    prev = char
                    continue
                }
                if prev == "/" && char == "*" {
                    result.removeLast()
                    inBlockComment = true
                    prev = char
                    continue
                }
            }
            result.append(char)
            prev = char
        }

        guard let data = result.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
