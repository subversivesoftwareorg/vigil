import Foundation

/// Facade for security scanning — delegates to adapter-specific risk detection.
/// Preserved for backward compatibility with existing callers (MonitoringStore, AISecurityModeView).
enum AISecurityEngine {

    static func scan(sessions: [AISessionLog]) -> AISecurityScanResult {
        let adapter = ClaudeCodeAdapter()
        let signals = adapter.detectRisks(sessions: sessions, config: nil)

        let projects = Set(sessions.map(\.projectPath))

        return AISecurityScanResult(
            scanDate: .now,
            signals: signals.sorted { $0.severity > $1.severity },
            sessions: sessions,
            projectCount: projects.count
        )
    }
}
