import Foundation

struct CursorAdapter: AIToolAdapter {
    let toolID = "cursor"
    let displayName = "Cursor"
    let provider = "Cursor Inc"
    let category = AICategory.codingAssistant

    var processSignatures: [ProcessSignature] {
        [
            ProcessSignature(pattern: "Cursor", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "cursor", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "Cursor", matchMode: .substring, displayName: displayName),
        ]
    }

    var pathSignatures: [PathSignature] {
        [PathSignature(pattern: "/.cursor/", pathCategory: .workspaceData, tool: displayName)]
    }

    func readConfig() -> AIToolConfig? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fm = FileManager.default

        let settingsPaths = [
            (path: "\(home)/.cursor/settings.json", label: "User dotfile"),
            (path: "\(home)/Library/Application Support/Cursor/User/settings.json", label: "App settings"),
        ]

        var foundLayers: [SettingsLayer] = []
        var mcpServerNames: [String] = []
        var mcpDetails: [MCPServerDetail] = []

        for candidate in settingsPaths {
            guard let data = fm.contents(atPath: candidate.path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            foundLayers.append(SettingsLayer(path: candidate.path, label: candidate.label))

            // Cursor stores MCP config in its settings.json
            if let mcpConfig = json["mcpServers"] as? [String: Any] {
                for (name, value) in mcpConfig {
                    mcpServerNames.append(name)
                    if let serverConfig = value as? [String: Any] {
                        mcpDetails.append(MCPServerDetail(
                            name: name,
                            command: serverConfig["command"] as? String,
                            args: serverConfig["args"] as? [String] ?? [],
                            envVars: (serverConfig["env"] as? [String: String]) ?? [:],
                            autoApprovedTools: [],
                            source: candidate.label
                        ))
                    }
                }
            }
        }

        // Prompt surfaces: .cursorrules and .cursor/rules/
        var promptSurfaces: [PromptSurface] = []
        for root in AIAdapterRegistry.discoverProjectRoots(marker: ".cursorrules") {
            let projectName = URL(fileURLWithPath: root).lastPathComponent
            promptSurfaces.append(PromptSurface(
                type: .cursorRules, path: "\(root)/.cursorrules",
                scope: "Project: \(projectName)"
            ))
        }
        for root in AIAdapterRegistry.discoverProjectRoots(marker: ".cursor/rules") {
            let projectName = URL(fileURLWithPath: root).lastPathComponent
            let rulesDir = "\(root)/.cursor/rules"
            if var isDir = Optional(ObjCBool(false)),
               fm.fileExists(atPath: rulesDir, isDirectory: &isDir), isDir.boolValue {
                promptSurfaces.append(PromptSurface(
                    type: .cursorRulesDir, path: rulesDir,
                    scope: "Project: \(projectName)"
                ))
            }
        }

        guard !foundLayers.isEmpty || !promptSurfaces.isEmpty else { return nil }

        if foundLayers.isEmpty {
            foundLayers.append(SettingsLayer(path: "(prompt surfaces only)", label: "Project rules"))
        }

        var summary = ["Cursor has full access to open projects via its IDE integration."]
        if !mcpServerNames.isEmpty {
            summary.append("\(mcpServerNames.count) MCP server\(mcpServerNames.count == 1 ? "" : "s")")
        }
        if !promptSurfaces.isEmpty {
            summary.append("\(promptSurfaces.count) project rule file\(promptSurfaces.count == 1 ? "" : "s")")
        }

        var config = AIToolConfig(
            tool: displayName,
            provider: provider,
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
        config.promptSurfaces = promptSurfaces
        return config
    }
}
