import Foundation

struct MLXAdapter: AIToolAdapter {
    let toolID = "mlx"
    let displayName = "MLX"
    let provider = "Local (Apple MLX)"
    let category = AICategory.localModel

    var processSignatures: [ProcessSignature] {
        [
            ProcessSignature(pattern: "mlx_lm", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "mlx-server", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "mlx_server", matchMode: .exact, displayName: displayName),
        ]
    }

    var pathSignatures: [PathSignature] {
        [PathSignature(pattern: "/mlx-models/", pathCategory: .modelStorage, tool: displayName)]
    }

    func readConfig() -> AIToolConfig? { nil }
}
