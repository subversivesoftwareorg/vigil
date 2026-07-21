import Foundation

struct OllamaAdapter: AIToolAdapter {
    let toolID = "ollama"
    let displayName = "Ollama"
    let provider = "Local"
    let category = AICategory.localModel

    var processSignatures: [ProcessSignature] {
        [
            ProcessSignature(pattern: "ollama", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "ollama", matchMode: .substring, displayName: displayName),
        ]
    }

    var pathSignatures: [PathSignature] {
        [PathSignature(pattern: "/.ollama/", pathCategory: .modelStorage, tool: displayName)]
    }

    func readConfig() -> AIToolConfig? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fm = FileManager.default
        let ollamaPath = "\(home)/.ollama"

        guard fm.fileExists(atPath: ollamaPath) else { return nil }

        var foundLayers = [SettingsLayer(path: ollamaPath, label: "Local models")]

        // Discover downloaded models from manifests
        let models = discoverModels()

        // Check for OLLAMA_HOST env var (security-relevant: local vs network binding)
        let ollamaHost = ProcessInfo.processInfo.environment["OLLAMA_HOST"]
        let isNetworkExposed = ollamaHost != nil
            && ollamaHost != "127.0.0.1"
            && ollamaHost != "localhost"
            && ollamaHost != "127.0.0.1:11434"
            && ollamaHost != "localhost:11434"

        // Check for SSH keys (Ollama generates these for registry auth)
        let hasSSHKeys = fm.fileExists(atPath: "\(ollamaPath)/id_ed25519")

        // Build summary
        var summary: [String] = []
        if models.isEmpty {
            summary.append("Ollama installed, no models downloaded")
        } else {
            let totalSize = models.reduce(0) { $0 + $1.sizeBytes }
            summary.append("\(models.count) model\(models.count == 1 ? "" : "s") downloaded (\(formatBytes(totalSize)))")
            let names = models.map(\.name).prefix(5).joined(separator: ", ")
            summary.append("Models: \(names)\(models.count > 5 ? ", ..." : "")")
        }

        if isNetworkExposed {
            summary.append("API bound to \(ollamaHost!) — network accessible")
        } else {
            summary.append("API bound to localhost (default)")
        }

        var config = AIToolConfig(
            tool: displayName,
            provider: provider,
            layers: foundLayers,
            permissions: PermissionSummary(allowed: [], denied: [], requiresApproval: []),
            envVarCount: 0,
            mcpServers: [],
            hasHooks: false,
            summary: summary
        )
        config.networkAccess = isNetworkExposed
        return config
    }

    // MARK: - Risk Detection

    func detectRisks(sessions: [AISessionLog], config: AIToolConfig?) -> [AISecuritySignal] {
        guard let config else { return [] }
        var signals: [AISecuritySignal] = []

        // Network-exposed API
        if config.networkAccess == true {
            let host = ProcessInfo.processInfo.environment["OLLAMA_HOST"] ?? "0.0.0.0"
            signals.append(AISecuritySignal(
                category: .excessiveAgency,
                severity: .warning,
                title: "Ollama API exposed to network",
                detail: "OLLAMA_HOST is set to \"\(host)\", making the local model API accessible from other machines. Anyone on the network can query your models.",
                evidence: "OLLAMA_HOST=\(host)"
            ))
        }

        return signals
    }

    // MARK: - Model Discovery

    struct OllamaModel {
        let name: String
        let tag: String
        let sizeBytes: Int
    }

    private func discoverModels() -> [OllamaModel] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let manifestsRoot = "\(home)/.ollama/models/manifests/registry.ollama.ai/library"
        let fm = FileManager.default
        guard fm.fileExists(atPath: manifestsRoot) else { return [] }

        var models: [OllamaModel] = []

        guard let modelDirs = try? fm.contentsOfDirectory(atPath: manifestsRoot) else { return [] }
        for modelName in modelDirs where !modelName.hasPrefix(".") {
            let modelPath = "\(manifestsRoot)/\(modelName)"
            guard let tags = try? fm.contentsOfDirectory(atPath: modelPath) else { continue }
            for tag in tags where !tag.hasPrefix(".") {
                let manifestPath = "\(modelPath)/\(tag)"
                let size = parseModelSize(manifestPath: manifestPath)
                models.append(OllamaModel(
                    name: modelName,
                    tag: tag,
                    sizeBytes: size
                ))
            }
        }

        return models.sorted { $0.name < $1.name }
    }

    private func parseModelSize(manifestPath: String) -> Int {
        guard let data = FileManager.default.contents(atPath: manifestPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let layers = json["layers"] as? [[String: Any]] else {
            return 0
        }
        return layers.reduce(0) { total, layer in
            total + (layer["size"] as? Int ?? 0)
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1_000_000_000 {
            return String(format: "%.1f GB", Double(bytes) / 1_000_000_000)
        } else if bytes >= 1_000_000 {
            return String(format: "%.0f MB", Double(bytes) / 1_000_000)
        }
        return "\(bytes) bytes"
    }
}
