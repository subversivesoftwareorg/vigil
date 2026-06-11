import Foundation

// MARK: - Tool Configuration

struct AIToolConfig {
    let tool: String
    let provider: String
    let layers: [SettingsLayer]
    let permissions: PermissionSummary
    let envVarCount: Int
    let mcpServers: [String]
    let hasHooks: Bool
    let summary: [String]

    // Extended fields (Phase 3)
    var autoMode: Bool = false
    var mcpServerDetails: [MCPServerDetail] = []
    var hookDetails: [HookDetail] = []
    var memoryEnabled: Bool = false
    var managedPolicy: Bool = false
    var promptSurfaces: [PromptSurface] = []
    var sandboxMode: String?
    var networkAccess: Bool?
    var approvalMode: String?
}

// MARK: - Settings Layer

struct SettingsLayer {
    let path: String
    let label: String
}

// MARK: - Permissions

struct PermissionSummary {
    let allowed: [PermissionGroup]
    let denied: [PermissionGroup]
    let requiresApproval: [PermissionGroup]

    var totalAllowed: Int { allowed.reduce(0) { $0 + $1.items.count } }
    var totalDenied: Int { denied.reduce(0) { $0 + $1.items.count } }
    var totalAsk: Int { requiresApproval.reduce(0) { $0 + $1.items.count } }
}

struct PermissionGroup {
    let category: String
    let items: [String]
}

// MARK: - MCP Server Detail

struct MCPServerDetail {
    let name: String
    let command: String?
    let args: [String]
    let envVars: [String: String]
    let autoApprovedTools: [String]
    let source: String
}

// MARK: - Hook Detail

struct HookDetail {
    let event: String
    let commands: [String]
}

// MARK: - Prompt Surface

struct PromptSurface {
    let type: PromptSurfaceType
    let path: String
    let scope: String

    enum PromptSurfaceType: String {
        case claudeMD = "CLAUDE.md"
        case agentsMD = "AGENTS.md"
        case cursorRules = ".cursorrules"
        case cursorRulesDir = ".cursor/rules"
        case windsurfRules = ".windsurfrules"
        case clineRules = ".clinerules"
        case rooRules = ".roo/rules"
        case codexInstructions = "codex-instructions"
    }
}
