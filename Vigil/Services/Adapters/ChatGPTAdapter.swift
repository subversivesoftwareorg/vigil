import Foundation

struct ChatGPTAdapter: AIToolAdapter {
    let toolID = "chatgpt"
    let displayName = "ChatGPT"
    let provider = "OpenAI"
    let category = AICategory.chatApp

    var processSignatures: [ProcessSignature] {
        [ProcessSignature(pattern: "ChatGPT", matchMode: .exact, displayName: displayName)]
    }

    var pathSignatures: [PathSignature] {
        [PathSignature(pattern: "/Library/Application Support/ChatGPT/", pathCategory: .workspaceData, tool: displayName)]
    }

    func readConfig() -> AIToolConfig? { nil }
}
