import Foundation

/// A persistent record of an AI tool observed on this system.
/// Updated in-memory on each monitoring cycle and flushed to SQLite periodically.
struct AIInventoryEntry: Identifiable {
    let toolID: String
    let displayName: String
    let provider: String
    let category: String
    var firstSeen: Date
    var lastSeen: Date
    var observationCount: Int
    var highestConfidence: ConfidenceLevel
    var bestBasis: EvidenceBasis
    var lastReason: String
    var processNames: Set<String>

    var id: String { toolID }

    static func toolID(from name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
    }
}
