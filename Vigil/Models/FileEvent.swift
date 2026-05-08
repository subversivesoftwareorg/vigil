import Foundation

/// A file system event detected by a FileEventSource.
struct FileEvent: Identifiable, Hashable, Codable {
    let id: UUID
    let path: String
    let kind: Kind
    let timestamp: Date

    enum Kind: String, Codable, Hashable {
        case created
        case modified
        case deleted
        case renamed
        case metadataChanged
    }

    var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var directory: String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
    }
}
