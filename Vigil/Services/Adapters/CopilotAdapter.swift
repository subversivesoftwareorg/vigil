import Foundation

struct CopilotAdapter: AIToolAdapter {
    let toolID = "github-copilot"
    let displayName = "GitHub Copilot"
    let provider = "GitHub/OpenAI"
    let category = AICategory.codingAssistant

    var processSignatures: [ProcessSignature] {
        [ProcessSignature(pattern: "copilot", matchMode: .substring, displayName: displayName)]
    }

    var pathSignatures: [PathSignature] {
        [PathSignature(pattern: "/copilot", pathCategory: .workspaceData, tool: displayName)]
    }

    func readConfig() -> AIToolConfig? { nil }
}
