import Foundation

struct GeminiAdapter: AIToolAdapter {
    let toolID = "gemini"
    let displayName = "Gemini"
    let provider = "Google"
    let category = AICategory.chatApp

    var processSignatures: [ProcessSignature] {
        [ProcessSignature(pattern: "Gemini", matchMode: .exact, displayName: displayName)]
    }

    var pathSignatures: [PathSignature] { [] }

    func readConfig() -> AIToolConfig? { nil }
}
