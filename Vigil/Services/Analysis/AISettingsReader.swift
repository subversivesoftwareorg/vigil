import Foundation

/// Facade for AI tool configuration discovery — delegates to adapter-specific readers.
/// Preserved for backward compatibility with existing callers (AIActivityModeView, AIInventoryModeView).
/// Data types (AIToolConfig, SettingsLayer, etc.) are now in Vigil/Models/AIToolConfig.swift.
enum AISettingsReader {

    /// Discover and summarize all AI tool configurations.
    static func discoverAll() -> [AIToolConfig] {
        AIAdapterRegistry.discoverAllConfigs()
    }
}
