import Foundation

struct LMStudioAdapter: AIToolAdapter {
    let toolID = "lm-studio"
    let displayName = "LM Studio"
    let provider = "Local"
    let category = AICategory.localModel

    var processSignatures: [ProcessSignature] {
        [
            ProcessSignature(pattern: "LM Studio", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "lmstudio", matchMode: .exact, displayName: displayName),
        ]
    }

    var pathSignatures: [PathSignature] {
        [PathSignature(pattern: "/LM Studio/", pathCategory: .modelStorage, tool: displayName)]
    }

    func readConfig() -> AIToolConfig? { nil }
}
