import Foundation

// MARK: - Adapter Protocol

protocol AIToolAdapter {
    var toolID: String { get }
    var displayName: String { get }
    var provider: String { get }
    var category: AICategory { get }

    var processSignatures: [ProcessSignature] { get }
    var pathSignatures: [PathSignature] { get }

    func readConfig() -> AIToolConfig?
    func parseSessions(projectFilter: String?) -> [AISessionLog]
    func detectRisks(sessions: [AISessionLog], config: AIToolConfig?) -> [AISecuritySignal]
}

extension AIToolAdapter {
    func parseSessions(projectFilter: String?) -> [AISessionLog] { [] }
    func detectRisks(sessions: [AISessionLog], config: AIToolConfig?) -> [AISecuritySignal] { [] }
}

// MARK: - Process Signature

struct ProcessSignature {
    let pattern: String
    let matchMode: MatchMode
    let displayName: String

    enum MatchMode {
        case exact
        case prefix
        case substring
    }

    func matches(_ processName: String) -> AIEvidence? {
        let matched: Bool
        switch matchMode {
        case .exact:
            matched = processName == pattern
        case .prefix:
            matched = processName.hasPrefix(pattern)
        case .substring:
            matched = processName.contains(pattern)
        }
        guard matched else { return nil }

        let basis: EvidenceBasis = matchMode == .exact ? .observed : .inferred
        let confidence: ConfidenceLevel = matchMode == .exact ? .high : .medium
        let reason = matchMode == .exact
            ? "Process name exactly matches known pattern \"\(pattern)\""
            : "Process name contains \"\(pattern)\" — may be \(displayName) or a related process"

        return AIEvidence(basis: basis, confidence: confidence, reason: reason)
    }
}

// MARK: - Path Signature

struct PathSignature {
    let pattern: String
    let pathCategory: AIPathCategory
    let tool: String

    func matches(_ path: String) -> AIEvidence? {
        let lower = path.lowercased()
        guard lower.contains(pattern.lowercased()) else { return nil }

        let confidence: ConfidenceLevel =
            pattern.hasPrefix("/.") || pattern.contains("Application Support")
            ? .high : .medium

        return AIEvidence(
            basis: .inferred,
            confidence: confidence,
            reason: "File path contains \"\(pattern)\" — likely \(tool) activity"
        )
    }
}
