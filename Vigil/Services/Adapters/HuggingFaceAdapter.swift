import Foundation

struct HuggingFaceAdapter: AIToolAdapter {
    let toolID = "huggingface"
    let displayName = "Hugging Face"
    let provider = "Local"
    let category = AICategory.localModel

    var processSignatures: [ProcessSignature] { [] }

    var pathSignatures: [PathSignature] {
        [
            PathSignature(pattern: "/huggingface/", pathCategory: .modelStorage, tool: displayName),
            PathSignature(pattern: "/.cache/huggingface/", pathCategory: .modelStorage, tool: displayName),
        ]
    }

    func readConfig() -> AIToolConfig? { nil }
}
