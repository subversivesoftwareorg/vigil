import Foundation

/// Facade for session log parsing — delegates to adapter-specific parsers.
/// Preserved for backward compatibility with existing callers (AILogsModeView, MonitoringStore).
enum AISessionLogParser {

    /// Parse all AI sessions, optionally filtered to a specific project path.
    static func parseAll(projectFilter: String? = nil) -> [AISessionLog] {
        AIAdapterRegistry.parseAllSessions(projectFilter: projectFilter)
    }

    /// Decode a Claude Code directory name back to a filesystem path.
    /// Kept here for backward compatibility — delegates to ClaudeCodeAdapter.
    static func decodeDirName(_ name: String) -> String {
        ClaudeCodeAdapter.decodeDirName(name)
    }
}
