import Foundation

// MARK: - Security Signal

struct AISecuritySignal: Identifiable {
    let id: UUID
    let category: SignalCategory
    let severity: SignalSeverity
    let title: String
    let detail: String
    let evidence: String
    let sessionID: String?
    let projectPath: String?
    let detectedAt: Date

    init(category: SignalCategory, severity: SignalSeverity, title: String,
         detail: String, evidence: String, sessionID: String? = nil,
         projectPath: String? = nil) {
        self.id = UUID()
        self.category = category
        self.severity = severity
        self.title = title
        self.detail = detail
        self.evidence = evidence
        self.sessionID = sessionID
        self.projectPath = projectPath
        self.detectedAt = .now
    }
}

enum SignalCategory: String, CaseIterable {
    case sensitiveFileAccess
    case suspiciousBash
    case tokenmaxxing
    case longSession
    case agentAction
    case exfiltration
    case mcpRisk
    case fileSharingExposure
    case excessiveAgency
    case toolShadowing
    case toolCombination
    case configDrift
    case supplyChain
    case toolDescriptionInjection
    case crossServerFlow

    var displayName: String {
        switch self {
        case .sensitiveFileAccess: "Sensitive File Access"
        case .suspiciousBash: "Suspicious Command"
        case .tokenmaxxing: "Token Usage"
        case .longSession: "Long Session"
        case .agentAction: "Agent Action"
        case .exfiltration: "Exfiltration Risk"
        case .mcpRisk: "MCP Risk"
        case .fileSharingExposure: "File Sharing Exposure"
        case .excessiveAgency: "Excessive Agency"
        case .toolShadowing: "Tool Shadowing"
        case .toolCombination: "Dangerous Combination"
        case .configDrift: "Config Drift"
        case .supplyChain: "Supply Chain"
        case .toolDescriptionInjection: "Description Injection"
        case .crossServerFlow: "Cross-Server Flow"
        }
    }

    var systemImage: String {
        switch self {
        case .sensitiveFileAccess: "lock.trianglebadge.exclamationmark"
        case .suspiciousBash: "terminal"
        case .tokenmaxxing: "chart.bar.xaxis.ascending"
        case .longSession: "clock.badge.exclamationmark"
        case .agentAction: "figure.walk.motion"
        case .exfiltration: "arrow.up.doc"
        case .mcpRisk: "server.rack"
        case .fileSharingExposure: "icloud.and.arrow.up"
        case .excessiveAgency: "exclamationmark.shield"
        case .toolShadowing: "square.on.square.badge.person.crop"
        case .toolCombination: "arrow.triangle.merge"
        case .configDrift: "arrow.triangle.2.circlepath"
        case .supplyChain: "shippingbox"
        case .toolDescriptionInjection: "text.badge.xmark"
        case .crossServerFlow: "arrow.left.arrow.right"
        }
    }
}

enum SignalSeverity: Int, Comparable, CaseIterable {
    case healthy = 0
    case info = 1
    case concern = 2
    case warning = 3

    static func < (lhs: SignalSeverity, rhs: SignalSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .healthy: "Healthy"
        case .info: "Info"
        case .concern: "Concern"
        case .warning: "Warning"
        }
    }

    var color: String {
        switch self {
        case .healthy: "green"
        case .info: "blue"
        case .concern: "orange"
        case .warning: "red"
        }
    }
}

// MARK: - Scan Result

struct AISecurityScanResult {
    let scanDate: Date
    let signals: [AISecuritySignal]
    let sessions: [AISessionLog]
    let projectCount: Int

    var signalsBySeverity: [SignalSeverity: [AISecuritySignal]] {
        Dictionary(grouping: signals, by: \.severity)
    }

    var signalsByCategory: [SignalCategory: [AISecuritySignal]] {
        Dictionary(grouping: signals, by: \.category)
    }

    var warningCount: Int { signals.filter { $0.severity == .warning }.count }
    var concernCount: Int { signals.filter { $0.severity == .concern }.count }
    var infoCount: Int { signals.filter { $0.severity == .info }.count }
    var healthyCount: Int { signals.filter { $0.severity == .healthy }.count }
}
