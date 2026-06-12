import Foundation

/// Adapter for the Gemini CLI (google/gemini-cli), distinct from the Gemini desktop chat app.
/// The CLI stores config at ~/.gemini/ and project rules at .gemini/.
struct GeminiCLIAdapter: AIToolAdapter {
    let toolID = "gemini-cli"
    let displayName = "Gemini CLI"
    let provider = "Google"
    let category = AICategory.codingAssistant

    var processSignatures: [ProcessSignature] {
        [
            ProcessSignature(pattern: "gemini", matchMode: .exact, displayName: displayName),
        ]
    }

    var pathSignatures: [PathSignature] {
        [
            PathSignature(pattern: "/.gemini/", pathCategory: .workspaceData, tool: displayName),
        ]
    }

    func readConfig() -> AIToolConfig? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fm = FileManager.default

        let geminiDir = "\(home)/.gemini"
        guard fm.fileExists(atPath: geminiDir) else { return nil }

        var foundLayers: [SettingsLayer] = []
        var summary: [String] = []

        // Settings
        let settingsPath = "\(geminiDir)/settings.json"
        if let data = fm.contents(atPath: settingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            foundLayers.append(SettingsLayer(path: settingsPath, label: "User settings"))
            if let model = json["model"] as? String {
                summary.append("Model: \(model)")
            }
        }

        // Sessions directory
        let sessionsPath = "\(geminiDir)/sessions"
        if let sessions = try? fm.contentsOfDirectory(atPath: sessionsPath) {
            let sessionCount = sessions.count
            if sessionCount > 0 {
                foundLayers.append(SettingsLayer(path: sessionsPath, label: "Sessions"))
                summary.append("\(sessionCount) session\(sessionCount == 1 ? "" : "s") stored")
            }
        }

        // Prompt surfaces (.gemini/ project rules)
        var promptSurfaces: [PromptSurface] = []
        for root in AIAdapterRegistry.discoverProjectRoots(marker: ".gemini") {
            let projectName = URL(fileURLWithPath: root).lastPathComponent
            let geminiProjectDir = "\(root)/.gemini"
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: geminiProjectDir, isDirectory: &isDir), isDir.boolValue {
                // Look for rules files inside .gemini/
                if let files = try? fm.contentsOfDirectory(atPath: geminiProjectDir) {
                    for file in files where file.hasSuffix(".md") || file == "rules" || file == "config.json" {
                        promptSurfaces.append(PromptSurface(
                            type: .codexInstructions,
                            path: "\(geminiProjectDir)/\(file)",
                            scope: "Project: \(projectName)"
                        ))
                    }
                }
            }
        }

        // Update notifier (proves CLI has been run)
        let notifierPath = "\(geminiDir)/update-notifier.json"
        if fm.fileExists(atPath: notifierPath) {
            foundLayers.append(SettingsLayer(path: notifierPath, label: "Update tracking"))
        }

        if foundLayers.isEmpty && promptSurfaces.isEmpty {
            foundLayers.append(SettingsLayer(path: geminiDir, label: "Install directory"))
        }

        if summary.isEmpty {
            summary.append("Gemini CLI is installed")
        }
        if !promptSurfaces.isEmpty {
            summary.append("\(promptSurfaces.count) project rule file\(promptSurfaces.count == 1 ? "" : "s")")
        }

        var config = AIToolConfig(
            tool: displayName, provider: provider,
            layers: foundLayers,
            permissions: PermissionSummary(allowed: [], denied: [], requiresApproval: []),
            envVarCount: 0, mcpServers: [], hasHooks: false,
            summary: summary
        )
        config.promptSurfaces = promptSurfaces
        return config
    }
}
