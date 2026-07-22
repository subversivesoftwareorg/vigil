import Foundation

/// Facade for security scanning — delegates to all adapter-specific risk detections
/// plus cross-tool analysis from AIRiskEngine.
enum AISecurityEngine {

    /// Full scan using pre-computed configs and sessions (no redundant I/O).
    static func scan(sessions: [AISessionLog], configs: [AIToolConfig],
                     database: Database? = nil) -> AISecurityScanResult {
        var signals: [AISecuritySignal] = []

        // Per-adapter risk detection using pre-computed data
        for adapter in AIAdapterRegistry.adapters {
            let config = configs.first { $0.tool == adapter.displayName }
            let adapterSessions = sessions.filter { session in
                adapter.parseSessions(projectFilter: nil).contains { $0.id == session.id }
            }
            signals.append(contentsOf: adapter.detectRisks(sessions: adapterSessions, config: config))
        }

        // Cross-tool risk detections
        signals.append(contentsOf: AIRiskEngine.detectMCPRisks(configs: configs))
        signals.append(contentsOf: AIRiskEngine.detectExcessiveAgency(configs: configs))
        signals.append(contentsOf: AIRiskEngine.detectFileSharingExposure(sessions: sessions))

        // MCP deep visibility detections
        signals.append(contentsOf: AIRiskEngine.detectToolShadowing(configs: configs))
        signals.append(contentsOf: AIRiskEngine.detectDangerousCombinations(sessions: sessions))
        signals.append(contentsOf: AIRiskEngine.detectCrossServerFlows(sessions: sessions))
        signals.append(contentsOf: AIRiskEngine.detectConfigDrift(configs: configs, database: database))

        // Tool description injection scanning (Claude Desktop tool schemas)
        let desktopAdapter = ClaudeDesktopAdapter()
        let toolDefinitions = desktopAdapter.discoverToolDefinitions()
        signals.append(contentsOf: AIRiskEngine.detectToolDescriptionInjection(toolDefinitions: toolDefinitions))

        // Deduplicate by title + evidence
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

    /// Convenience for callers that don't have pre-computed data (e.g., tests).
    static func scan(sessions: [AISessionLog], database: Database? = nil) -> AISecurityScanResult {
        let configs = AIAdapterRegistry.discoverAllConfigs()
        return scan(sessions: sessions, configs: configs, database: database)
    }
}
