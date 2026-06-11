import Foundation

struct StableDiffusionAdapter: AIToolAdapter {
    let toolID = "stable-diffusion"
    let displayName = "Stable Diffusion"
    let provider = "Local"
    let category = AICategory.localModel

    var processSignatures: [ProcessSignature] {
        [
            ProcessSignature(pattern: "stable-diffusion", matchMode: .substring, displayName: displayName),
            ProcessSignature(pattern: "DiffusionBee", matchMode: .exact, displayName: displayName),
        ]
    }

    var pathSignatures: [PathSignature] { [] }

    func readConfig() -> AIToolConfig? { nil }
}
