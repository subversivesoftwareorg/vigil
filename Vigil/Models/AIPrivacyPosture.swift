import Foundation

struct AIPrivacyPosture {
    let toolID: String
    let displayName: String
    let bundleID: String
    var grants: [PrivacyGrant] = []
    var launchAgents: [LaunchAgentEntry] = []

    var hasElevatedAccess: Bool {
        grants.contains { $0.granted && $0.service.isElevated }
    }
}

struct PrivacyGrant {
    let service: PrivacyService
    let granted: Bool
}

enum PrivacyService: String, CaseIterable {
    case accessibility = "kTCCServiceAccessibility"
    case screenRecording = "kTCCServiceScreenCapture"
    case fullDiskAccess = "kTCCServiceSystemPolicyAllFiles"
    case automation = "kTCCServiceAppleEvents"
    case microphone = "kTCCServiceMicrophone"
    case camera = "kTCCServiceCamera"
    case inputMonitoring = "kTCCServiceListenEvent"
    case desktopFolder = "kTCCServiceSystemPolicyDesktopFolder"
    case documentsFolder = "kTCCServiceSystemPolicyDocumentsFolder"
    case downloadsFolder = "kTCCServiceSystemPolicyDownloadsFolder"

    var displayName: String {
        switch self {
        case .accessibility: "Accessibility"
        case .screenRecording: "Screen Recording"
        case .fullDiskAccess: "Full Disk Access"
        case .automation: "Automation"
        case .microphone: "Microphone"
        case .camera: "Camera"
        case .inputMonitoring: "Input Monitoring"
        case .desktopFolder: "Desktop Folder"
        case .documentsFolder: "Documents Folder"
        case .downloadsFolder: "Downloads Folder"
        }
    }

    var systemImage: String {
        switch self {
        case .accessibility: "figure.stand"
        case .screenRecording: "rectangle.dashed.badge.record"
        case .fullDiskAccess: "externaldrive"
        case .automation: "gearshape.2"
        case .microphone: "mic"
        case .camera: "camera"
        case .inputMonitoring: "keyboard"
        case .desktopFolder: "folder"
        case .documentsFolder: "doc.on.doc"
        case .downloadsFolder: "arrow.down.circle"
        }
    }

    var isElevated: Bool {
        switch self {
        case .accessibility, .screenRecording, .fullDiskAccess, .inputMonitoring:
            return true
        default:
            return false
        }
    }
}

struct LaunchAgentEntry {
    let path: String
    let label: String
    let bundleID: String?
}
