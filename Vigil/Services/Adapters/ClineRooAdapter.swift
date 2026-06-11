import Foundation

struct ClineRooAdapter: AIToolAdapter {
    let toolID = "cline-roo"
    let displayName = "Cline / Roo Code"
    let provider = "Open Source"
    let category = AICategory.codingAssistant

    var processSignatures: [ProcessSignature] {
        [
            ProcessSignature(pattern: "cline", matchMode: .substring, displayName: "Cline"),
            ProcessSignature(pattern: "roo-code", matchMode: .substring, displayName: "Roo Code"),
            ProcessSignature(pattern: "roo_code", matchMode: .substring, displayName: "Roo Code"),
        ]
    }

    var pathSignatures: [PathSignature] {
        [PathSignature(pattern: "/.continue/", pathCategory: .workspaceData, tool: displayName)]
    }

    func readConfig() -> AIToolConfig? {
        let fm = FileManager.default

        var foundLayers: [SettingsLayer] = []
        var promptSurfaces: [PromptSurface] = []
        var mcpServerNames: [String] = []
        var mcpDetails: [MCPServerDetail] = []

        // Cline stores MCP config in VS Code settings
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let vscodePaths = [
            "\(home)/Library/Application Support/Code/User/settings.json",
            "\(home)/Library/Application Support/Code - Insiders/User/settings.json",
        ]
        for path in vscodePaths {
            guard let data = fm.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            // Cline MCP servers are under "cline.mcpServers" or "roo-cline.mcpServers"
            for key in ["cline.mcpServers", "roo-cline.mcpServers"] {
                if let servers = json[key] as? [String: Any] {
                    foundLayers.append(SettingsLayer(path: path, label: "VS Code (\(key))"))
                    for (name, value) in servers {
                        mcpServerNames.append(name)
                        if let serverConfig = value as? [String: Any] {
                            mcpDetails.append(MCPServerDetail(
                                name: name,
                                command: serverConfig["command"] as? String,
                                args: serverConfig["args"] as? [String] ?? [],
                                envVars: (serverConfig["env"] as? [String: String]) ?? [:],
                                autoApprovedTools: serverConfig["alwaysAllow"] as? [String] ?? [],
                                source: "VS Code settings"
                            ))
                        }
                    }
                }
            }

            // Auto-approval settings
            if let autoApprove = json["roo-cline.autoApprove"] as? Bool, autoApprove {
                foundLayers.append(SettingsLayer(path: path, label: "VS Code (auto-approve)"))
            }
        }

        // Prompt surfaces
        for root in AIAdapterRegistry.discoverProjectRoots(marker: ".clinerules") {
            let projectName = URL(fileURLWithPath: root).lastPathComponent
            promptSurfaces.append(PromptSurface(
                type: .clineRules, path: "\(root)/.clinerules",
                scope: "Project: \(projectName)"
            ))
        }
        for root in AIAdapterRegistry.discoverProjectRoots(marker: ".roo/rules") {
            let projectName = URL(fileURLWithPath: root).lastPathComponent
            promptSurfaces.append(PromptSurface(
                type: .rooRules, path: "\(root)/.roo/rules",
                scope: "Project: \(projectName)"
            ))
        }

        guard !foundLayers.isEmpty || !promptSurfaces.isEmpty else { return nil }

        if foundLayers.isEmpty && !promptSurfaces.isEmpty {
            foundLayers.append(SettingsLayer(path: "(prompt surfaces only)", label: "Project rules"))
        }

        var summary: [String] = []
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
            permissions: PermissionSummary(allowed: [], denied: [], requiresApproval: []),
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
