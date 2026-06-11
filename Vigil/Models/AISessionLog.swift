import Foundation

// MARK: - Session Log

struct AISessionLog: Identifiable {
    let id: String
    let projectPath: String
    var startedAt: Date?
    var endedAt: Date?
    var humanTurns: Int = 0
    var assistantTurns: Int = 0
    var tokens: AITokenUsage = AITokenUsage()
    var modelsUsed: Set<String> = []
    var toolsUsed: [String: Int] = [:]
    var filesTouched: [AIFileTouched] = []
    var bashCommands: [String] = []
    var gitBranch: String?

    // Extended fields (Phase 4)
    var webFetches: [String] = []
    var webSearches: [String] = []
    var mcpCalls: [AIMCPCall] = []
    var subagentSpawns: [AISubagentSpawn] = []
    var searchOperations: [AISearchOperation] = []

    var duration: TimeInterval? {
        guard let start = startedAt, let end = endedAt else { return nil }
        return end.timeIntervalSince(start)
    }

    var durationHours: Double? {
        duration.map { $0 / 3600.0 }
    }

    var totalTurns: Int { humanTurns + assistantTurns }
}

struct AITokenUsage {
    var input: Int = 0
    var output: Int = 0
    var cacheCreation: Int = 0
    var cacheRead: Int = 0

    var total: Int { input + output + cacheCreation + cacheRead }
}

struct AIFileTouched: Hashable {
    let path: String
    let action: AIFileAction
}

enum AIFileAction: String, CaseIterable {
    case read
    case write
    case edit
    case multiEdit
    case search
}

// MARK: - MCP Call

struct AIMCPCall: Hashable {
    let serverName: String
    let toolName: String
}

// MARK: - Subagent Spawn

struct AISubagentSpawn {
    let description: String
    let agentType: String?
}

// MARK: - Search Operation

struct AISearchOperation {
    let type: SearchType
    let pattern: String

    enum SearchType: String {
        case grep
        case glob
    }
}
