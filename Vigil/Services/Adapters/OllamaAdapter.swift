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

    func readConfig() -> AIToolConfig? { nil }
}
