import Foundation

struct CopilotAdapter: AIToolAdapter {
    let toolID = "github-copilot"
    let displayName = "GitHub Copilot"
    let provider = "GitHub/OpenAI"
    let category = AICategory.codingAssistant

    var processSignatures: [ProcessSignature] {
        [
            ProcessSignature(pattern: "copilot", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "Copilot", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "GitHub Copilot", matchMode: .prefix, displayName: displayName),
        ]
    }

    var pathSignatures: [PathSignature] {
        [
            PathSignature(pattern: "/.config/github-copilot/", pathCategory: .workspaceData, tool: displayName),
            PathSignature(pattern: "/globalStorage/github.copilot", pathCategory: .workspaceData, tool: displayName),
            PathSignature(pattern: "/extensions/github.copilot", pathCategory: .workspaceData, tool: displayName),
            PathSignature(pattern: "/gh-copilot/", pathCategory: .workspaceData, tool: displayName),
        ]
    }

    func readConfig() -> AIToolConfig? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fm = FileManager.default

        var foundLayers: [SettingsLayer] = []
        var summary: [String] = []

        // Primary auth config: ~/.config/github-copilot/hosts.json
        let authPath = "\(home)/.config/github-copilot/hosts.json"
        if fm.fileExists(atPath: authPath) {
            foundLayers.append(SettingsLayer(path: authPath, label: "Auth config"))
            if let data = fm.contents(atPath: authPath),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let hostCount = json.keys.count
                summary.append("Authenticated with \(hostCount) GitHub host\(hostCount == 1 ? "" : "s")")
            }
        }

        // Version tracking
        let versionsPath = "\(home)/.config/github-copilot/versions.json"
        if fm.fileExists(atPath: versionsPath) {
            foundLayers.append(SettingsLayer(path: versionsPath, label: "Version tracking"))
        }

        // VS Code extension detection
        let vscodePath = "\(home)/.vscode/extensions"
        if let extensions = try? fm.contentsOfDirectory(atPath: vscodePath) {
            let copilotExts = extensions.filter { $0.hasPrefix("github.copilot") }
            for ext in copilotExts {
                foundLayers.append(SettingsLayer(
                    path: "\(vscodePath)/\(ext)", label: "VS Code extension"
                ))
            }
            if !copilotExts.isEmpty {
                summary.append("VS Code extension installed (\(copilotExts.count) component\(copilotExts.count == 1 ? "" : "s"))")
            }
        }

        // VS Code global storage
        let globalStorage = "\(home)/Library/Application Support/Code/User/globalStorage/github.copilot"
        if fm.fileExists(atPath: globalStorage) {
            foundLayers.append(SettingsLayer(path: globalStorage, label: "VS Code global storage"))
        }
        let chatStorage = "\(home)/Library/Application Support/Code/User/globalStorage/github.copilot-chat"
        if fm.fileExists(atPath: chatStorage) {
            foundLayers.append(SettingsLayer(path: chatStorage, label: "VS Code chat storage"))
            summary.append("Copilot Chat data present")
        }

        // VS Code settings — check for Copilot config keys
        let vsSettingsPath = "\(home)/Library/Application Support/Code/User/settings.json"
        if let data = fm.contents(atPath: vsSettingsPath),
           let content = String(data: data, encoding: .utf8),
           content.contains("github.copilot") {
            foundLayers.append(SettingsLayer(path: vsSettingsPath, label: "VS Code settings"))
        }

        // gh CLI copilot extension
        let ghCopilotPath = "\(home)/.local/share/gh/extensions/gh-copilot"
        if fm.fileExists(atPath: ghCopilotPath) {
            foundLayers.append(SettingsLayer(path: ghCopilotPath, label: "gh CLI extension"))
            summary.append("gh copilot CLI installed")
        }

        // gh copilot config
        let ghCopilotConfig = "\(home)/.config/gh-copilot"
        if fm.fileExists(atPath: ghCopilotConfig) {
            foundLayers.append(SettingsLayer(path: ghCopilotConfig, label: "gh copilot config"))
        }

        // JetBrains plugin detection
        let jetbrainsSupport = "\(home)/Library/Application Support/JetBrains"
        if let ides = try? fm.contentsOfDirectory(atPath: jetbrainsSupport) {
            for ide in ides {
                let pluginPath = "\(jetbrainsSupport)/\(ide)/plugins"
                if let plugins = try? fm.contentsOfDirectory(atPath: pluginPath) {
                    if plugins.contains(where: { $0.lowercased().contains("copilot") }) {
                        foundLayers.append(SettingsLayer(
                            path: "\(pluginPath)", label: "JetBrains plugin (\(ide))"
                        ))
                        summary.append("JetBrains plugin installed (\(ide))")
                    }
                }
            }
        }

        guard !foundLayers.isEmpty else { return nil }

        if summary.isEmpty {
            summary.append("GitHub Copilot configuration found")
        }

        return AIToolConfig(
            tool: displayName, provider: provider,
            layers: foundLayers,
            permissions: PermissionSummary(
                allowed: [PermissionGroup(category: "Editor", items: ["Code completions", "Chat"])],
                denied: [], requiresApproval: []
            ),
            envVarCount: 0,
            mcpServers: [],
            hasHooks: false,
            summary: summary
        )
    }
}
