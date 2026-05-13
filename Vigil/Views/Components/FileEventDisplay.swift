import SwiftUI

/// Display helpers for FileEvent.Kind — icon and color for use in views.
extension FileEvent.Kind {
    var systemImage: String {
        switch self {
        case .created: "plus.circle.fill"
        case .modified: "pencil.circle.fill"
        case .deleted: "minus.circle.fill"
        case .renamed: "arrow.triangle.swap"
        case .metadataChanged: "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .created: .green
        case .modified: .blue
        case .deleted: .red
        case .renamed: .orange
        case .metadataChanged: .purple
        }
    }

    var displayName: String {
        switch self {
        case .created: "Created"
        case .modified: "Modified"
        case .deleted: "Deleted"
        case .renamed: "Renamed"
        case .metadataChanged: "Metadata"
        }
    }
}
