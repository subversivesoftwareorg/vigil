import Foundation

/// What we know about a well-known process.
struct ProcessKnowledge: Hashable {
    let description: String
    let category: Category
    let expectation: Expectation

    /// Broad category for grouping in the UI.
    enum Category: String, Hashable, CaseIterable {
        case kernel = "Kernel & Core"
        case windowManager = "Display & Window Management"
        case security = "Security & Privacy"
        case storage = "Storage & Filesystem"
        case networking = "Networking"
        case cloud = "iCloud & Sync"
        case input = "Input & Accessibility"
        case audio = "Audio & Media"
        case printing = "Printing & Scanning"
        case location = "Location Services"
        case diagnostics = "Diagnostics & Reporting"
        case appStore = "App Store & Updates"
        case continuity = "Continuity & Handoff"
        case appleApp = "Apple Application"
        case developerTool = "Developer Tool"
        case thirdParty = "Third-Party Application"
        case runtime = "Language Runtime"
        case utility = "System Utility"

        var systemImage: String {
            switch self {
            case .kernel: "cpu"
            case .windowManager: "macwindow"
            case .security: "lock.shield"
            case .storage: "internaldrive"
            case .networking: "network"
            case .cloud: "icloud"
            case .input: "keyboard"
            case .audio: "speaker.wave.3"
            case .printing: "printer"
            case .location: "location"
            case .diagnostics: "stethoscope"
            case .appStore: "arrow.down.app"
            case .continuity: "macbook.and.iphone"
            case .appleApp: "apple.logo"
            case .developerTool: "wrench.and.screwdriver"
            case .thirdParty: "app.badge"
            case .runtime: "chevron.left.forwardslash.chevron.right"
            case .utility: "gearshape"
            }
        }
    }

    /// How we expect this process to behave on a healthy system.
    enum Expectation: String, Hashable {
        /// Always running — absence or restart is notable.
        case alwaysRunning = "Always Running"
        /// Usually running on most Macs.
        case usuallyRunning = "Usually Running"
        /// Runs on demand, then exits. Long-running instances are notable.
        case transient = "Transient"
        /// Runs periodically (e.g., cron-like maintenance).
        case periodic = "Periodic"
        /// Only runs when the user explicitly launches it.
        case userLaunched = "User Launched"
    }
}
