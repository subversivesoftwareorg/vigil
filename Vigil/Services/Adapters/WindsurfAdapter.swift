import Foundation

struct WindsurfAdapter: AIToolAdapter {
    let toolID = "windsurf"
    let displayName = "Windsurf"
    let provider = "Codeium"
    let category = AICategory.codingAssistant

    var processSignatures: [ProcessSignature] {
        [
            ProcessSignature(pattern: "Windsurf", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "windsurf", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "Windsurf", matchMode: .substring, displayName: displayName),
        ]
    }

    var pathSignatures: [PathSignature] {
        [PathSignature(pattern: "/.windsurf/", pathCategory: .workspaceData, tool: displayName)]
    }

    func readConfig() -> AIToolConfig? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fm = FileManager.default

        let settingsPaths = [
            (path: "\(home)/.windsurf/settings.json", label: "User dotfile"),
            (path: "\(home)/Library/Application Support/Windsurf/User/settings.json", label: "App settings"),
        ]

        var foundLayers: [SettingsLayer] = []
        for candidate in settingsPaths {
            if fm.fileExists(atPath: candidate.path) {
                foundLayers.append(SettingsLayer(path: candidate.path, label: candidate.label))
            }
        }

        // Prompt surfaces: .windsurfrules
        var promptSurfaces: [PromptSurface] = []
        for root in AIAdapterRegistry.discoverProjectRoots(marker: ".windsurfrules") {
            let projectName = URL(fileURLWithPath: root).lastPathComponent
            promptSurfaces.append(PromptSurface(
                type: .windsurfRules, path: "\(root)/.windsurfrules",
                scope: "Project: \(projectName)"
            ))
        }

        guard !foundLayers.isEmpty || !promptSurfaces.isEmpty else { return nil }

        if foundLayers.isEmpty {
            foundLayers.append(SettingsLayer(path: "(prompt surfaces only)", label: "Project rules"))
        }

        var summary = ["Windsurf (Cascade) has IDE-level access to open projects."]
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
            mcpServers: [],
            hasHooks: false,
            summary: summary
        )
        config.promptSurfaces = promptSurfaces
        return config
    }
}
