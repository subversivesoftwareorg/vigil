import Foundation

struct WhisperAdapter: AIToolAdapter {
    let toolID = "whisper"
    let displayName = "Whisper"
    let provider = "Local"
    let category = AICategory.localModel

    var processSignatures: [ProcessSignature] {
        [ProcessSignature(pattern: "whisper", matchMode: .substring, displayName: displayName)]
    }

    var pathSignatures: [PathSignature] { [] }

    func readConfig() -> AIToolConfig? { nil }
}
