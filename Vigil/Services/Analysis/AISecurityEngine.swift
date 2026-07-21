import Foundation

/// Facade for security scanning — delegates to all adapter-specific risk detections
/// plus cross-tool analysis from AIRiskEngine.
enum AISecurityEngine {

    static func scan(sessions: [AISessionLog]) -> AISecurityScanResult {
        var signals: [AISecuritySignal] = []
        var configs: [AIToolConfig] = []

        for adapter in AIAdapterRegistry.adapters {
            let config = adapter.readConfig()
            if let config { configs.append(config) }
            let adapterSessions = adapter.parseSessions(projectFilter: nil)
            signals.append(contentsOf: adapter.detectRisks(sessions: adapterSessions, config: config))
        }

        // Cross-tool risk detections
        signals.append(contentsOf: AIRiskEngine.detectMCPRisks(configs: configs))
        signals.append(contentsOf: AIRiskEngine.detectExcessiveAgency(configs: configs))
        signals.append(contentsOf: AIRiskEngine.detectFileSharingExposure(sessions: sessions))

        // Deduplicate by title + evidence (adapters may produce overlapping signals with the engine)
        var seen = Set<String>()
        let deduped = signals.filter { signal in
            let key = "\(signal.title)|\(signal.evidence)"
            return seen.insert(key).inserted
        }

        let projects = Set(sessions.map(\.projectPath))

        return AISecurityScanResult(
            scanDate: .now,
            signals: deduped.sorted { $0.severity > $1.severity },
            sessions: sessions,
            projectCount: projects.count
        )
    }
}
