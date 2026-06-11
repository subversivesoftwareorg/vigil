import Foundation

struct ZedAdapter: AIToolAdapter {
    let toolID = "zed"
    let displayName = "Zed"
    let provider = "Zed Industries"
    let category = AICategory.codingAssistant

    var processSignatures: [ProcessSignature] {
        [
            ProcessSignature(pattern: "Zed", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "zed", matchMode: .exact, displayName: displayName),
        ]
    }

    var pathSignatures: [PathSignature] { [] }

    func readConfig() -> AIToolConfig? { nil }
}
