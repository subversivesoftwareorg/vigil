import Foundation

struct AiderAdapter: AIToolAdapter {
    let toolID = "aider"
    let displayName = "Aider"
    let provider = "Open Source"
    let category = AICategory.codingAssistant

    var processSignatures: [ProcessSignature] {
        [ProcessSignature(pattern: "aider", matchMode: .exact, displayName: displayName)]
    }

    var pathSignatures: [PathSignature] {
        [PathSignature(pattern: "/.aider", pathCategory: .workspaceData, tool: displayName)]
    }

    func readConfig() -> AIToolConfig? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var configPaths: [SettingsLayer] = []

        let globalPath = "\(home)/.aider.conf.yml"
        if FileManager.default.fileExists(atPath: globalPath) {
            configPaths.append(SettingsLayer(path: globalPath, label: "User global"))
        }

        for root in AIAdapterRegistry.discoverProjectRoots(marker: ".aider.conf.yml") {
            let projectName = URL(fileURLWithPath: root).lastPathComponent
            configPaths.append(SettingsLayer(path: "\(root)/.aider.conf.yml", label: "Project: \(projectName)"))
        }

        guard !configPaths.isEmpty else { return nil }

        return AIToolConfig(
            tool: displayName,
            provider: provider,
            layers: configPaths,
            permissions: PermissionSummary(allowed: [], denied: [], requiresApproval: []),
            envVarCount: 0,
            mcpServers: [],
            hasHooks: false,
            summary: ["Aider configuration found across \(configPaths.count) location\(configPaths.count == 1 ? "" : "s")."]
        )
    }
}
