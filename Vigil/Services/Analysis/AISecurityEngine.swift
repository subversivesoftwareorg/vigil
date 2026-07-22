import Foundation

/// Facade for security scanning — delegates to all adapter-specific risk detections
/// plus cross-tool analysis from AIRiskEngine.
enum AISecurityEngine {

    /// Full scan using pre-computed data. `sessionsByTool` maps adapter toolID →
    /// that adapter's parsed sessions, so per-adapter detection never re-parses
    /// anything to attribute sessions.
    static func scan(sessionsByTool: [String: [AISessionLog]],
                     configs: [AIToolConfig],
                     database: Database? = nil) -> AISecurityScanResult {
        let sessions = sessionsByTool.values.flatMap { $0 }
        var signals: [AISecuritySignal] = []

        // Per-adapter risk detection
        for adapter in AIAdapterRegistry.adapters {
            let config = configs.first { $0.tool == adapter.displayName }
            let adapterSessions = sessionsByTool[adapter.toolID] ?? []
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
        let toolDefinitions = ClaudeDesktopAdapter().discoverToolDefinitions()
        signals.append(contentsOf: AIRiskEngine.detectToolDescriptionInjection(toolDefinitions: toolDefinitions))

        // Unattended agents: Cowork scheduled tasks + AI cron jobs
        let unattendedAgents = UnattendedAgentScanner.scanAll()
        signals.append(contentsOf: AIRiskEngine.detectUnattendedAgentRisks(agents: unattendedAgents))

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

    /// Convenience overload for callers with a flat session list (tests, legacy).
    /// Sessions are attributed to Claude Code for per-session detection, since
    /// its detectors cover the shared bash/file/exfiltration heuristics.
    static func scan(sessions: [AISessionLog], database: Database? = nil) -> AISecurityScanResult {
        scan(sessionsByTool: ["claude-code": sessions],
             configs: AIAdapterRegistry.discoverAllConfigs(),
             database: database)
    }
}
