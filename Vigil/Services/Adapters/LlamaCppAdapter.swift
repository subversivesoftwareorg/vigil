import Foundation

struct LlamaCppAdapter: AIToolAdapter {
    let toolID = "llama-cpp"
    let displayName = "llama.cpp"
    let provider = "Local"
    let category = AICategory.localModel

    var processSignatures: [ProcessSignature] {
        [
            ProcessSignature(pattern: "llamafile", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "llama", matchMode: .substring, displayName: displayName),
        ]
    }

    var pathSignatures: [PathSignature] { [] }

    func readConfig() -> AIToolConfig? { nil }
}
