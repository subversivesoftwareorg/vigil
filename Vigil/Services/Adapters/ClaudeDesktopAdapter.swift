import Foundation

struct ClaudeDesktopAdapter: AIToolAdapter {
    let toolID = "claude-desktop"
    let displayName = "Claude Desktop"
    let provider = "Anthropic"
    let category = AICategory.chatApp

    var processSignatures: [ProcessSignature] {
        [
            ProcessSignature(pattern: "Claude", matchMode: .exact, displayName: displayName),
            ProcessSignature(pattern: "Claude", matchMode: .substring, displayName: displayName),
        ]
    }

    var pathSignatures: [PathSignature] {
        [PathSignature(pattern: "/Library/Application Support/Claude/", pathCategory: .workspaceData, tool: displayName)]
    }

    func readConfig() -> AIToolConfig? { nil }
}
