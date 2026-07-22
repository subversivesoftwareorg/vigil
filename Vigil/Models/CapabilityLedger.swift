import Foundation

// MARK: - Ledger Entry

/// One principal that can act on this machine: an AI tool, an MCP server,
/// a scheduled task, or a cron job — with what it's allowed to do.
struct LedgerEntry: Identifiable {
    enum PrincipalKind: String, CaseIterable {
        case tool
        case mcpServer
        case scheduledTask
        case cronJob

        var displayName: String {
            switch self {
            case .tool: "AI Tools"
            case .mcpServer: "MCP Servers"
            case .scheduledTask: "Scheduled Tasks"
            case .cronJob: "Cron Jobs"
            }
        }

        var systemImage: String {
            switch self {
            case .tool: "brain"
            case .mcpServer: "server.rack"
            case .scheduledTask: "calendar.badge.clock"
            case .cronJob: "terminal"
            }
        }
    }

    enum AccessLevel {
        case granted
        case requiresApproval
        case denied
        case unknown

        var label: String {
            switch self {
            case .granted: "Granted"
            case .requiresApproval: "Approval"
            case .denied: "Denied"
            case .unknown: "Unknown"
            }
        }
    }

    let id: String
    let kind: PrincipalKind
    let name: String
    let parent: String?             // owning tool, for MCP servers
    let fileScope: [String]
    let shellAccess: AccessLevel
    let networkAccess: AccessLevel
    let browserDomains: [String]
    let schedule: String?           // human-readable, nil = acts only when invoked
    let approvalMode: String
    let grantedTools: [String]      // per-tool MCP grants from settings allow-lists
    let source: String
}

// MARK: - Adapter Coverage

/// What Vigil knows how to check for a given tool — independent of whether
/// the tool is installed on this machine.
enum CoverageLevel: Int, Comparable {
    case none = 0
    case partial = 1
    case full = 2

    static func < (lhs: CoverageLevel, rhs: CoverageLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .none: "None"
        case .partial: "Partial"
        case .full: "Full"
        }
    }
}

// MARK: - Risk Surface Visibility

/// A risk surface in the AI usage landscape and who can see it. Includes
/// surfaces Vigil cannot observe — an honest visibility map is the point.
/// Full visibility is a combination of tools: Vigil (host activity),
/// Prism (browser), Tapped (network), Harden (enforcement).
struct RiskSurface: Identifiable {
    let name: String
    let detail: String
    let vigilCoverage: CoverageLevel
    let companion: String?          // tool that covers (or would cover) the gap
    let notes: String

    var id: String { name }
}

struct AdapterCoverage: Identifiable {
    let toolID: String
    let displayName: String
    let configReading: CoverageLevel
    let sessionParsing: CoverageLevel
    let riskDetection: CoverageLevel
    let mcpDiscovery: CoverageLevel
    let permissionParsing: CoverageLevel
    let scheduleDiscovery: CoverageLevel

    var id: String { toolID }

    static let dimensionLabels = [
        "Config", "Sessions", "Risks", "MCP", "Permissions", "Schedules",
    ]

    var levels: [CoverageLevel] {
        [configReading, sessionParsing, riskDetection,
         mcpDiscovery, permissionParsing, scheduleDiscovery]
    }
}
