import Foundation

/// Lookup table for well-known macOS processes, daemons, agents, and common apps.
/// Matches on exact name first, then falls back to prefix matching.
enum ProcessDatabase {

    /// Returns knowledge about a process by name.
    /// Tries exact match, then prefix match (for bundle-ID-style names and truncated names).
    static func lookup(_ processName: String) -> ProcessKnowledge? {
        if let exact = db[processName] { return exact }
        let lower = processName.lowercased()
        for (key, entry) in db {
            let k = key.lowercased()
            guard k.count >= 4 else { continue }
            if lower.hasPrefix(k) || (lower.count >= 4 && k.hasPrefix(lower)) {
                return entry
            }
        }
        return nil
    }

    // swiftlint:disable function_body_length

    private static let db: [String: ProcessKnowledge] = [

        // ━━ Kernel & Core ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "kernel_task": .init(
            description: "The macOS kernel. Manages memory, scheduling, I/O, and hardware. High CPU often means thermal throttling — the kernel uses CPU cycles to cool down the system.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "launchd": .init(
            description: "The root process (PID 1). Starts and manages all other daemons, agents, and services. Every process on your Mac is a descendant of launchd.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "logd": .init(
            description: "Unified logging daemon. Collects log messages from all processes and makes them available via Console.app and the `log` command.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "syslogd": .init(
            description: "Legacy system logger. Routes older-style syslog messages to the unified logging system.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "notifyd": .init(
            description: "Darwin notification center daemon. Delivers lightweight inter-process notifications used by system frameworks.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "distnoted": .init(
            description: "Distributed notification daemon. Delivers NSDistributedNotification messages between processes.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "cfprefsd": .init(
            description: "Preferences daemon. Reads and writes UserDefaults (plist) preferences for all apps. Multiple instances are normal — one per user plus a system instance.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "dasd": .init(
            description: "Duet Activity Scheduler. Schedules background tasks intelligently based on battery, network, and thermal state.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "runningboardd": .init(
            description: "Process lifecycle manager. Tracks which apps are running, suspended, or terminated. Works with launchd to manage app states.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "UserEventAgent": .init(
            description: "Monitors system events (disk mounts, network changes, power events) and dispatches them to registered plugins.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "coreservicesd": .init(
            description: "Core Services daemon. Manages Launch Services (file associations), UTI types, and app registration.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "launchservicesd": .init(
            description: "Launch Services daemon. Maintains the database of installed apps and handles 'Open With' associations.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "containermanagerd": .init(
            description: "Container Manager. Manages sandboxed app containers and their data directories.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "endpointsecurityd": .init(
            description: "Endpoint Security daemon. Provides the Endpoint Security framework API for security products to monitor system events.",
            category: .security, expectation: .alwaysRunning
        ),
        "syspolicyd": .init(
            description: "System Policy daemon. Enforces Gatekeeper, notarization, and code signing policies when apps are launched.",
            category: .security, expectation: .alwaysRunning
        ),
        "thermalmonitord": .init(
            description: "Thermal monitor. Watches CPU/GPU temperatures and triggers throttling to prevent overheating.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "powerd": .init(
            description: "Power management daemon. Manages sleep, wake, display sleep, and power assertions from apps.",
            category: .kernel, expectation: .alwaysRunning
        ),

        // ━━ Display & Window Management ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "WindowServer": .init(
            description: "The display server. Composites all windows, handles GPU rendering, and processes mouse/keyboard input for the entire GUI. High CPU means heavy screen updates.",
            category: .windowManager, expectation: .alwaysRunning
        ),
        "Dock": .init(
            description: "The Dock, Mission Control, Launchpad, and desktop spaces. Also manages the desktop wallpaper and hot corners.",
            category: .windowManager, expectation: .alwaysRunning
        ),
        "Finder": .init(
            description: "The file manager. Renders the desktop, manages file browsing windows, and handles file operations (copy, move, delete).",
            category: .windowManager, expectation: .alwaysRunning
        ),
        "SystemUIServer": .init(
            description: "Manages menu bar extras (status items) like volume, Bluetooth, clock, and third-party icons.",
            category: .windowManager, expectation: .alwaysRunning
        ),
        "ControlCenter": .init(
            description: "Control Center. Provides quick-access toggles for Wi-Fi, Bluetooth, Focus, display brightness, and more.",
            category: .windowManager, expectation: .alwaysRunning
        ),
        "NotificationCenter": .init(
            description: "Notification Center. Displays banners, alerts, and the notification sidebar with widgets.",
            category: .windowManager, expectation: .alwaysRunning
        ),
        "loginwindow": .init(
            description: "Login window manager. Handles user login, logout, and fast user switching. One instance per logged-in user.",
            category: .windowManager, expectation: .alwaysRunning
        ),
        "universalcontrol": .init(
            description: "Universal Control. Allows a single keyboard and mouse to control multiple Macs and iPads nearby.",
            category: .continuity, expectation: .usuallyRunning
        ),

        // ━━ Security & Privacy ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "securityd": .init(
            description: "Security daemon. Manages the Keychain, code signing verification, and cryptographic operations for the system.",
            category: .security, expectation: .alwaysRunning
        ),
        "trustd": .init(
            description: "Trust evaluation daemon. Validates TLS/SSL certificates for all secure connections on your Mac.",
            category: .security, expectation: .alwaysRunning
        ),
        "secinitd": .init(
            description: "Security initialization daemon. Sets up App Sandbox restrictions and entitlements when apps launch.",
            category: .security, expectation: .alwaysRunning
        ),
        "coreauthd": .init(
            description: "Core Authentication daemon. Handles Touch ID, Apple Watch unlock, and LocalAuthentication framework requests.",
            category: .security, expectation: .alwaysRunning
        ),
        "opendirectoryd": .init(
            description: "Open Directory daemon. Manages user accounts, groups, and directory service lookups (local and LDAP/Active Directory).",
            category: .security, expectation: .alwaysRunning
        ),
        "authd": .init(
            description: "Authorization daemon. Handles privilege escalation prompts ('enter your password to make changes').",
            category: .security, expectation: .alwaysRunning
        ),
        "SecurityAgent": .init(
            description: "Security Agent. Displays authentication dialogs for password entry, Touch ID prompts, and keychain access requests.",
            category: .security, expectation: .transient
        ),
        "XProtect": .init(
            description: "XProtect. Apple's built-in malware scanner. Runs silently to check apps and files against known malware signatures.",
            category: .security, expectation: .transient
        ),
        "XProtectService": .init(
            description: "XProtect background service. Performs periodic malware scans and updates malware signature definitions.",
            category: .security, expectation: .periodic
        ),
        "MRT": .init(
            description: "Malware Removal Tool. Apple's built-in tool that removes known malware if detected.",
            category: .security, expectation: .periodic
        ),
        "GatekeeperConfigAgent": .init(
            description: "Gatekeeper configuration. Downloads updated app notarization and signing policy data from Apple.",
            category: .security, expectation: .periodic
        ),
        "TCCd": .init(
            description: "Transparency, Consent, and Control daemon. Manages privacy permissions (camera, microphone, screen recording, etc.).",
            category: .security, expectation: .alwaysRunning
        ),
        "biomed": .init(
            description: "Biometric daemon. Manages Touch ID fingerprint data and biometric authentication state.",
            category: .security, expectation: .alwaysRunning
        ),

        // ━━ Storage & Filesystem ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "mds": .init(
            description: "Metadata server (Spotlight). The core indexing daemon that coordinates Spotlight search across all volumes.",
            category: .storage, expectation: .alwaysRunning
        ),
        "mds_stores": .init(
            description: "Spotlight index store. Reads and writes the Spotlight search index database.",
            category: .storage, expectation: .alwaysRunning
        ),
        "mdworker": .init(
            description: "Spotlight index worker. Processes files to extract metadata (text content, image data, etc.) for the Spotlight index.",
            category: .storage, expectation: .transient
        ),
        "mdworker_shared": .init(
            description: "Shared Spotlight worker. Indexes files using importer plugins shared across the system.",
            category: .storage, expectation: .transient
        ),
        "fseventsd": .init(
            description: "File System Events daemon. Tracks all file changes and maintains the FSEvents log used by Spotlight, Time Machine, and apps.",
            category: .storage, expectation: .alwaysRunning
        ),
        "diskarbitrationd": .init(
            description: "Disk Arbitration daemon. Manages disk mounting, unmounting, and ejection. Notifies apps when volumes appear or disappear.",
            category: .storage, expectation: .alwaysRunning
        ),
        "diskmanagementd": .init(
            description: "Disk Management daemon. Handles disk partitioning, formatting, and RAID operations via Disk Utility.",
            category: .storage, expectation: .transient
        ),
        "revisiond": .init(
            description: "Versions daemon. Manages the document versions system that powers 'Revert To' in apps that support it.",
            category: .storage, expectation: .alwaysRunning
        ),
        "backupd": .init(
            description: "Time Machine daemon. Creates incremental backups to local or network drives on a schedule.",
            category: .storage, expectation: .periodic
        ),
        "backupd-helper": .init(
            description: "Time Machine helper. Performs the actual file copying during Time Machine backup operations.",
            category: .storage, expectation: .transient
        ),
        "fsck": .init(
            description: "File system check. Verifies and repairs disk file system integrity. Runs at boot or when errors are detected.",
            category: .storage, expectation: .transient
        ),
        "apfsd": .init(
            description: "APFS daemon. Manages Apple File System volumes, snapshots, and encryption.",
            category: .storage, expectation: .alwaysRunning
        ),
        "filecoordinationd": .init(
            description: "File Coordination daemon. Manages NSFileCoordinator to prevent conflicts when multiple apps access the same file.",
            category: .storage, expectation: .alwaysRunning
        ),

        // ━━ Networking ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "mDNSResponder": .init(
            description: "Bonjour / mDNS. Apple's zero-configuration networking. Discovers printers, AirPlay devices, and services on the local network. Also handles system DNS resolution.",
            category: .networking, expectation: .alwaysRunning
        ),
        "configd": .init(
            description: "System Configuration daemon. Monitors network interfaces, manages DNS settings, and detects network changes.",
            category: .networking, expectation: .alwaysRunning
        ),
        "networkd": .init(
            description: "Network daemon. Handles low-level networking operations for the Network.framework used by modern apps.",
            category: .networking, expectation: .alwaysRunning
        ),
        "airportd": .init(
            description: "Wi-Fi manager. Controls Wi-Fi hardware, scans for networks, and manages wireless connections.",
            category: .networking, expectation: .alwaysRunning
        ),
        "wifip2pd": .init(
            description: "Wi-Fi Peer-to-Peer. Manages Wi-Fi Direct connections used by AirDrop for file transfers.",
            category: .networking, expectation: .usuallyRunning
        ),
        "symptomsd": .init(
            description: "Network Symptoms. Monitors network quality and helps the system choose the best interface (Wi-Fi vs Ethernet vs cellular).",
            category: .networking, expectation: .alwaysRunning
        ),
        "nsurlsessiond": .init(
            description: "NSURLSession daemon. Completes background downloads and uploads for apps, even when the app is suspended.",
            category: .networking, expectation: .usuallyRunning
        ),
        "cfnetworkd": .init(
            description: "CFNetwork daemon. Handles background URL tasks for apps using the CFNetwork framework.",
            category: .networking, expectation: .usuallyRunning
        ),
        "netbiosd": .init(
            description: "NetBIOS daemon. Provides Windows network name resolution for SMB file sharing.",
            category: .networking, expectation: .usuallyRunning
        ),
        "nesessionmanager": .init(
            description: "Network Extension session manager. Manages VPN connections, DNS proxies, and content filters.",
            category: .networking, expectation: .usuallyRunning
        ),
        "networkserviceproxy": .init(
            description: "Network Service Proxy. Routes traffic through HTTP/SOCKS proxies configured in System Settings.",
            category: .networking, expectation: .transient
        ),
        "apsd": .init(
            description: "Apple Push Notification Service. Maintains a persistent connection to Apple's servers to receive push notifications for all apps.",
            category: .networking, expectation: .alwaysRunning
        ),
        "WiFiAgent": .init(
            description: "Wi-Fi Agent. Manages the Wi-Fi menu bar item and handles Wi-Fi network selection UI.",
            category: .networking, expectation: .alwaysRunning
        ),
        "InternetSharing": .init(
            description: "Internet Sharing. Shares your Mac's internet connection via Wi-Fi, Ethernet, or Bluetooth.",
            category: .networking, expectation: .transient
        ),
        "socketfilterfw": .init(
            description: "Application Firewall. The macOS built-in firewall that controls incoming connections on a per-app basis.",
            category: .networking, expectation: .alwaysRunning
        ),

        // ━━ iCloud & Sync ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "cloudd": .init(
            description: "iCloud core daemon. Syncs Contacts, Calendars, Reminders, Notes, and other iCloud data.",
            category: .cloud, expectation: .alwaysRunning
        ),
        "bird": .init(
            description: "iCloud Drive sync daemon. Uploads and downloads files to/from iCloud Drive.",
            category: .cloud, expectation: .alwaysRunning
        ),
        "replicatord": .init(
            description: "CloudKit replication. Syncs CloudKit-based app data between your devices via iCloud.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "accountsd": .init(
            description: "Internet Accounts. Manages credentials for iCloud, Google, Exchange, and other configured accounts.",
            category: .cloud, expectation: .alwaysRunning
        ),
        "identityservicesd": .init(
            description: "Identity Services. Authenticates iMessage, FaceTime, and iCloud sign-in. Manages your Apple ID sessions.",
            category: .cloud, expectation: .alwaysRunning
        ),
        "cloudpaird": .init(
            description: "Cloud Pairing. Manages device pairing for Apple Watch, Handoff, and Continuity features via iCloud.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "cloudphotod": .init(
            description: "iCloud Photos sync. Uploads and downloads photos and videos to/from your iCloud Photo Library.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "photolibraryd": .init(
            description: "Photos Library daemon. Manages the local Photos database, runs on-device ML analysis, and coordinates with iCloud Photos.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "remindd": .init(
            description: "Reminders daemon. Syncs reminders with iCloud and manages location/time-based reminder triggers.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "callservicesd": .init(
            description: "FaceTime call services. Handles incoming and outgoing FaceTime audio/video calls and Continuity phone relay.",
            category: .cloud, expectation: .alwaysRunning
        ),
        "imagent": .init(
            description: "iMessage agent. Manages iMessage connections, message delivery, and end-to-end encryption.",
            category: .cloud, expectation: .alwaysRunning
        ),
        "IMDPersistenceAgent": .init(
            description: "iMessage persistence. Stores and indexes your Messages chat history database.",
            category: .cloud, expectation: .alwaysRunning
        ),
        "CalendarAgent": .init(
            description: "Calendar agent. Syncs calendar events with iCloud, Google, Exchange, and other CalDAV servers.",
            category: .cloud, expectation: .alwaysRunning
        ),
        "ContactsAgent": .init(
            description: "Contacts agent. Syncs contacts with iCloud, Google, Exchange, and other CardDAV servers.",
            category: .cloud, expectation: .alwaysRunning
        ),

        // ━━ Input & Accessibility ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "bluetoothd": .init(
            description: "Bluetooth daemon. Manages all Bluetooth hardware, device pairing, and connections (keyboards, mice, AirPods, etc.).",
            category: .input, expectation: .alwaysRunning
        ),
        "universalaccessd": .init(
            description: "Universal Access daemon. Provides accessibility services like VoiceOver, Switch Control, and display accommodations.",
            category: .input, expectation: .alwaysRunning
        ),
        "VoiceOver": .init(
            description: "VoiceOver screen reader. Reads screen content aloud for visually impaired users.",
            category: .input, expectation: .userLaunched
        ),
        "TextInputMenuAgent": .init(
            description: "Text Input menu agent. Manages the input source menu (keyboard layouts, dictation, emoji picker).",
            category: .input, expectation: .alwaysRunning
        ),
        "TextInputSwitcher": .init(
            description: "Text Input Switcher. Handles automatic keyboard layout switching between apps.",
            category: .input, expectation: .alwaysRunning
        ),
        "imklaunchagent": .init(
            description: "Input Method Kit launch agent. Manages third-party input methods and keyboard layouts.",
            category: .input, expectation: .usuallyRunning
        ),

        // ━━ Audio & Media ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "coreaudiod": .init(
            description: "Core Audio daemon. Manages all audio input/output on your Mac — speakers, microphones, Bluetooth audio, and audio routing.",
            category: .audio, expectation: .alwaysRunning
        ),
        "mediaremoted": .init(
            description: "Media Remote daemon. Handles Now Playing information, media controls, and AirPlay session management.",
            category: .audio, expectation: .alwaysRunning
        ),
        "AMPDeviceDiscoveryAgent": .init(
            description: "AirPlay device discovery. Scans the network for AirPlay receivers (Apple TV, HomePod, AirPlay speakers).",
            category: .audio, expectation: .usuallyRunning
        ),
        "audioaccessoryd": .init(
            description: "Audio Accessory daemon. Manages AirPods, Beats, and other Apple audio accessories including firmware updates.",
            category: .audio, expectation: .transient
        ),
        "Music": .init(
            description: "Apple Music. Streams music from Apple Music and plays your local music library.",
            category: .appleApp, expectation: .userLaunched
        ),
        "Podcasts": .init(
            description: "Apple Podcasts. Streams and downloads podcast episodes.",
            category: .appleApp, expectation: .userLaunched
        ),

        // ━━ Printing & Scanning ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "cupsd": .init(
            description: "CUPS printing daemon. Manages print jobs, printer discovery, and driver communication for all printers.",
            category: .printing, expectation: .usuallyRunning
        ),

        // ━━ Location Services ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "locationd": .init(
            description: "Location daemon. Provides location data to apps via GPS, Wi-Fi positioning, and Bluetooth beacons. Enforces privacy permissions.",
            category: .location, expectation: .alwaysRunning
        ),
        "geod": .init(
            description: "Geo services daemon. Handles map tile downloads, geocoding, and routing for Maps and apps using MapKit.",
            category: .location, expectation: .transient
        ),

        // ━━ Diagnostics & Reporting ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "diagnosticd": .init(
            description: "Diagnostics daemon. Collects crash reports, hang reports, and diagnostic data for Apple and app developers.",
            category: .diagnostics, expectation: .alwaysRunning
        ),
        "ReportCrash": .init(
            description: "Crash reporter. Generates crash reports when an app or process crashes unexpectedly.",
            category: .diagnostics, expectation: .transient
        ),
        "spindump": .init(
            description: "Spin dump. Captures stack traces when an app hangs (shows the beach ball) to help diagnose unresponsiveness.",
            category: .diagnostics, expectation: .transient
        ),
        "sysdiagnose": .init(
            description: "System Diagnose. Gathers comprehensive system diagnostic data (logs, profiles, state) for Apple support.",
            category: .diagnostics, expectation: .transient
        ),
        "analyticsd": .init(
            description: "Analytics daemon. Collects and submits anonymized usage analytics to Apple (if opted in via Privacy settings).",
            category: .diagnostics, expectation: .alwaysRunning
        ),
        "wifianalyticsd": .init(
            description: "Wi-Fi Analytics. Collects anonymized Wi-Fi performance data for Apple diagnostics (if opted in).",
            category: .diagnostics, expectation: .usuallyRunning
        ),
        "osanalyticshelper": .init(
            description: "OS Analytics Helper. Processes and submits macOS diagnostic and usage data to Apple.",
            category: .diagnostics, expectation: .periodic
        ),
        "tailspind": .init(
            description: "Tailspin daemon. Continuously records lightweight system trace data that can be captured retroactively when an issue occurs.",
            category: .diagnostics, expectation: .alwaysRunning
        ),

        // ━━ App Store & Updates ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "storeagent": .init(
            description: "App Store agent. Handles App Store purchases, downloads, and license verification.",
            category: .appStore, expectation: .usuallyRunning
        ),
        "softwareupdated": .init(
            description: "Software Update daemon. Checks for and downloads macOS and system updates in the background.",
            category: .appStore, expectation: .periodic
        ),
        "appstoreagent": .init(
            description: "App Store background agent. Processes automatic app updates and manages download queues.",
            category: .appStore, expectation: .transient
        ),

        // ━━ Continuity & Handoff ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "rapportd": .init(
            description: "Rapport daemon. Powers Universal Control, Handoff, and Sidecar by discovering and communicating with nearby Apple devices.",
            category: .continuity, expectation: .alwaysRunning
        ),
        "sharingd": .init(
            description: "Sharing daemon. Manages AirDrop, screen sharing, file sharing, and Nearby Interactions.",
            category: .continuity, expectation: .alwaysRunning
        ),
        "wirelessproxd": .init(
            description: "Wireless Proximity daemon. Detects nearby Apple devices for Handoff, Auto Unlock, and Instant Hotspot.",
            category: .continuity, expectation: .alwaysRunning
        ),
        "sidecar-relay": .init(
            description: "Sidecar relay. Streams your Mac display to an iPad for use as a secondary monitor.",
            category: .continuity, expectation: .transient
        ),

        // ━━ Apple Applications ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "Safari": .init(
            description: "Apple's web browser. Network activity is handled by WebKit subprocess processes.",
            category: .appleApp, expectation: .userLaunched
        ),
        "com.apple.WebKit.Networking": .init(
            description: "Safari WebKit networking. Handles all HTTP requests made by Safari and WebKit-based apps.",
            category: .appleApp, expectation: .transient
        ),
        "com.apple.WebKit.WebContent": .init(
            description: "Safari WebKit content. Renders web pages in a sandboxed process, isolated from the main Safari process for security.",
            category: .appleApp, expectation: .transient
        ),
        "Mail": .init(
            description: "Apple Mail. Fetches, sends, and indexes email from IMAP, Exchange, and other mail accounts.",
            category: .appleApp, expectation: .userLaunched
        ),
        "Notes": .init(
            description: "Apple Notes. Syncs notes with iCloud and provides rich text, sketches, and document scanning.",
            category: .appleApp, expectation: .userLaunched
        ),
        "Preview": .init(
            description: "Preview. Views PDFs and images. Can annotate, sign, and do basic image editing.",
            category: .appleApp, expectation: .userLaunched
        ),
        "Terminal": .init(
            description: "Terminal. Provides command-line access to macOS via shells like zsh and bash.",
            category: .appleApp, expectation: .userLaunched
        ),
        "Activity Monitor": .init(
            description: "Activity Monitor. Displays real-time CPU, memory, energy, disk, and network usage per process.",
            category: .appleApp, expectation: .userLaunched
        ),
        "TextEdit": .init(
            description: "TextEdit. Simple text and rich text editor bundled with macOS.",
            category: .appleApp, expectation: .userLaunched
        ),
        "System Preferences": .init(
            description: "System Settings. Configures macOS system preferences, accounts, security, and hardware settings.",
            category: .appleApp, expectation: .userLaunched
        ),
        "System Settings": .init(
            description: "System Settings. The modern replacement for System Preferences on macOS Ventura and later.",
            category: .appleApp, expectation: .userLaunched
        ),

        // ━━ Developer Tools ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "Xcode": .init(
            description: "Apple's IDE for developing macOS, iOS, watchOS, and tvOS apps.",
            category: .developerTool, expectation: .userLaunched
        ),
        "sourcekit-lsp": .init(
            description: "SourceKit LSP. Provides code completion, jump-to-definition, and diagnostics for Swift and C-family languages.",
            category: .developerTool, expectation: .transient
        ),
        "swift-frontend": .init(
            description: "Swift compiler frontend. Parses, type-checks, and compiles Swift source files.",
            category: .developerTool, expectation: .transient
        ),
        "swift-build": .init(
            description: "Swift Package Manager build tool. Resolves dependencies and orchestrates compilation of Swift packages.",
            category: .developerTool, expectation: .transient
        ),
        "lldb": .init(
            description: "LLDB debugger. The default debugger for Xcode, used for setting breakpoints and inspecting running programs.",
            category: .developerTool, expectation: .transient
        ),
        "clang": .init(
            description: "Clang compiler. Compiles C, C++, and Objective-C source files.",
            category: .developerTool, expectation: .transient
        ),
        "swiftc": .init(
            description: "Swift compiler driver. Orchestrates Swift compilation, linking, and module generation.",
            category: .developerTool, expectation: .transient
        ),
        "IBDDSimulator": .init(
            description: "Interface Builder device simulator. Renders storyboard/XIB previews in Xcode's Interface Builder.",
            category: .developerTool, expectation: .transient
        ),
        "Simulator": .init(
            description: "iOS/watchOS/tvOS Simulator. Runs simulated devices for testing apps during development.",
            category: .developerTool, expectation: .userLaunched
        ),
        "Instruments": .init(
            description: "Instruments. Apple's profiling tool for analyzing CPU, memory, disk, network, and GPU performance.",
            category: .developerTool, expectation: .userLaunched
        ),
        "FileMerge": .init(
            description: "FileMerge. Visual file and directory comparison and merging tool.",
            category: .developerTool, expectation: .userLaunched
        ),
        "git": .init(
            description: "Git version control. Manages source code history. Connects to remote repositories when pushing, pulling, or cloning.",
            category: .developerTool, expectation: .transient
        ),
        "ssh": .init(
            description: "Secure Shell. Creates encrypted connections to remote servers for terminal access and file transfer.",
            category: .developerTool, expectation: .transient
        ),
        "ssh-agent": .init(
            description: "SSH agent. Caches SSH private keys in memory so you don't need to enter passphrases repeatedly.",
            category: .developerTool, expectation: .usuallyRunning
        ),

        // ━━ Language Runtimes ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "node": .init(
            description: "Node.js JavaScript runtime. Used for web servers, build tools, and command-line applications.",
            category: .runtime, expectation: .transient
        ),
        "python3": .init(
            description: "Python 3 interpreter. General-purpose scripting language used for automation, data science, and web apps.",
            category: .runtime, expectation: .transient
        ),
        "python": .init(
            description: "Python interpreter. May be Python 2 (deprecated) or a symlink to Python 3.",
            category: .runtime, expectation: .transient
        ),
        "ruby": .init(
            description: "Ruby interpreter. Used for scripting, web development (Rails), and system automation.",
            category: .runtime, expectation: .transient
        ),
        "perl": .init(
            description: "Perl interpreter. Used for text processing, system administration scripts, and legacy tools.",
            category: .runtime, expectation: .transient
        ),
        "java": .init(
            description: "Java Virtual Machine. Runs Java applications and servers.",
            category: .runtime, expectation: .transient
        ),

        // ━━ System Utilities ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "curl": .init(
            description: "Command-line HTTP client. Fetches URLs and transfers data over HTTP, HTTPS, FTP, and other protocols.",
            category: .utility, expectation: .transient
        ),
        "periodic": .init(
            description: "Periodic maintenance. Runs daily, weekly, and monthly maintenance scripts (log rotation, temp cleanup).",
            category: .utility, expectation: .periodic
        ),
        "cron": .init(
            description: "Cron scheduler. Runs scheduled tasks at specified times (legacy — most tasks now use launchd).",
            category: .utility, expectation: .alwaysRunning
        ),
        "mtmfs": .init(
            description: "Memory Technology File System. Manages RAM disk volumes used for temporary high-speed storage.",
            category: .utility, expectation: .transient
        ),
        "taskgated": .init(
            description: "Task gate daemon. Validates code signatures before allowing processes to use certain system features (like debugging).",
            category: .security, expectation: .alwaysRunning
        ),

        // ━━ Common Third-Party Apps ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "Slack": .init(
            description: "Slack team messaging. Uses WebSockets for real-time messages and HTTP for file uploads.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Slack Helper": .init(
            description: "Slack helper process. Handles rendering and background tasks for the Slack Electron app.",
            category: .thirdParty, expectation: .transient
        ),
        "zoom.us": .init(
            description: "Zoom video conferencing. Uses UDP for video/audio streams and TCP for meeting control.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Spotify": .init(
            description: "Spotify music streaming. Streams audio from Spotify's CDN and syncs playback state.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Discord": .init(
            description: "Discord voice and text chat. Uses WebRTC for voice/video and WebSockets for messages.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Discord Helper": .init(
            description: "Discord helper. Handles rendering and background tasks for the Discord Electron app.",
            category: .thirdParty, expectation: .transient
        ),
        "Signal": .init(
            description: "Signal encrypted messenger. All messages are end-to-end encrypted using the Signal Protocol.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Signal Helper (Renderer)": .init(
            description: "Signal renderer helper. Handles UI rendering for the Signal Electron app.",
            category: .thirdParty, expectation: .transient
        ),
        "Dropbox": .init(
            description: "Dropbox file sync. Watches local folders and syncs changes with Dropbox cloud storage.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "OneDrive": .init(
            description: "Microsoft OneDrive. Syncs files with your Microsoft 365 / OneDrive cloud storage.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Google Drive": .init(
            description: "Google Drive sync client. Syncs files between your Mac and Google Drive / Google Workspace.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "1Password": .init(
            description: "1Password password manager. Syncs your encrypted vault with 1Password servers.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Bitwarden": .init(
            description: "Bitwarden open-source password manager. Syncs your encrypted vault with Bitwarden servers.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Tailscale": .init(
            description: "Tailscale mesh VPN. Creates a WireGuard-based peer-to-peer network between your devices.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "io.tailscale.ipn": .init(
            description: "Tailscale network extension. The background process that maintains your Tailscale VPN connection.",
            category: .thirdParty, expectation: .usuallyRunning
        ),
        "Docker": .init(
            description: "Docker Desktop. Manages Linux containers and virtual machines for development environments.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "com.docker.vmnetd": .init(
            description: "Docker VM networking daemon. Provides networking for Docker containers running in the Linux VM.",
            category: .thirdParty, expectation: .usuallyRunning
        ),
        "Figma": .init(
            description: "Figma collaborative design tool. Syncs designs and multiplayer editing in real time.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Figma Helper": .init(
            description: "Figma helper. Handles rendering for the Figma Electron app.",
            category: .thirdParty, expectation: .transient
        ),
        "Code Helper": .init(
            description: "VS Code helper. Handles extension host and rendering for Visual Studio Code.",
            category: .thirdParty, expectation: .transient
        ),
        "Electron": .init(
            description: "Electron framework process. A Chromium-based runtime used by many desktop apps (Slack, Discord, VS Code, etc.).",
            category: .runtime, expectation: .transient
        ),
        "iTerm2": .init(
            description: "iTerm2 terminal emulator. Popular replacement for Terminal.app with split panes, profiles, and scripting.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Alfred": .init(
            description: "Alfred launcher and productivity tool. Provides quick launch, clipboard history, workflows, and snippets.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Raycast": .init(
            description: "Raycast launcher. Extensible productivity tool for quick actions, calculations, and developer workflows.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "CleanMyMac": .init(
            description: "CleanMyMac system cleaner. Scans for junk files, malware, and performance optimizations.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Little Snitch": .init(
            description: "Little Snitch network monitor. Monitors and filters outgoing network connections per-app.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Bartender": .init(
            description: "Bartender menu bar manager. Organizes and hides menu bar icons.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Amphetamine": .init(
            description: "Amphetamine keep-awake utility. Prevents your Mac from sleeping based on triggers and schedules.",
            category: .thirdParty, expectation: .userLaunched
        ),

        // ━━ Apple System Core (Additional) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "AccessibilityUIServer": .init(
            description: "Accessibility UI Server. Renders accessibility overlays and manages assistive technology interfaces.",
            category: .input, expectation: .alwaysRunning
        ),
        "accessoryupdaterd": .init(
            description: "Accessory updater daemon. Downloads and installs firmware updates for connected Apple accessories.",
            category: .kernel, expectation: .transient
        ),
        "adid": .init(
            description: "Advertising identifier daemon. Manages the device advertising identifier used for ad tracking.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "adprivacyd": .init(
            description: "Ad privacy daemon. Enforces Apple's privacy restrictions on advertising and attribution data.",
            category: .security, expectation: .usuallyRunning
        ),
        "AirPlayUIAgent": .init(
            description: "AirPlay UI Agent. Displays AirPlay mirroring and streaming controls in the menu bar and Control Center.",
            category: .continuity, expectation: .usuallyRunning
        ),
        "AirPlayXPCHelper": .init(
            description: "AirPlay XPC Helper. Handles inter-process communication for AirPlay streaming sessions.",
            category: .continuity, expectation: .transient
        ),
        "AKAuthorizationRemoteViewService": .init(
            description: "AuthenticationServices remote view. Renders Sign in with Apple and passkey authorization UI in apps.",
            category: .security, expectation: .transient
        ),
        "akd": .init(
            description: "AuthKit daemon. Manages Apple ID authentication, two-factor verification, and account tokens.",
            category: .security, expectation: .alwaysRunning
        ),
        "amfid": .init(
            description: "Apple Mobile File Integrity daemon. Validates code signatures and entitlements before processes execute.",
            category: .security, expectation: .alwaysRunning
        ),
        "amsaccountsd": .init(
            description: "Apple Media Services accounts daemon. Manages App Store and iTunes Store account authentication.",
            category: .appStore, expectation: .usuallyRunning
        ),
        "amsengagementd": .init(
            description: "Apple Media Services engagement daemon. Tracks user engagement metrics for App Store recommendations.",
            category: .appStore, expectation: .usuallyRunning
        ),
        "amsondevicestoraged": .init(
            description: "Apple Media Services on-device storage daemon. Manages local caches for App Store and media content.",
            category: .appStore, expectation: .usuallyRunning
        ),
        "aned": .init(
            description: "Apple Neural Engine daemon. Manages the Neural Engine hardware for on-device machine learning inference.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "aneuserd": .init(
            description: "Apple Neural Engine user daemon. Handles user-space requests to the Neural Engine for ML model execution.",
            category: .kernel, expectation: .transient
        ),
        "appleaccountd": .init(
            description: "Apple Account daemon. Manages Apple ID account information, authentication state, and account settings.",
            category: .cloud, expectation: .alwaysRunning
        ),
        "AppleCredentialManagerDaemon": .init(
            description: "Apple Credential Manager. Manages system-wide credentials, passwords, and authentication tokens.",
            category: .security, expectation: .alwaysRunning
        ),
        "appleeventsd": .init(
            description: "Apple Events daemon. Routes Apple Events for inter-application scripting and AppleScript automation.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "appleh16camerad": .init(
            description: "Apple H16 camera daemon. Manages the FaceTime camera hardware and image signal processing pipeline.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "applekeystored": .init(
            description: "Apple Keystore daemon. Manages encrypted key storage backed by the Secure Enclave hardware.",
            category: .security, expectation: .alwaysRunning
        ),
        "AppleSpell": .init(
            description: "Apple spell-checking service. Provides system-wide spelling and grammar checking for all apps.",
            category: .kernel, expectation: .transient
        ),
        "appplaceholdersyncd": .init(
            description: "App placeholder sync daemon. Syncs app placeholder data across devices for Continuity and Handoff.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "AppPredictionIntentsHelperService": .init(
            description: "App prediction intents helper. Processes app usage patterns to power Siri Suggestions and app predictions.",
            category: .kernel, expectation: .transient
        ),
        "AppSSOAgent": .init(
            description: "App Single Sign-On agent. Manages enterprise SSO authentication extensions for apps.",
            category: .security, expectation: .usuallyRunning
        ),
        "AppSSODaemon": .init(
            description: "App Single Sign-On daemon. Provides Extensible SSO framework services for enterprise authentication.",
            category: .security, expectation: .usuallyRunning
        ),
        "appstorecomponentsd": .init(
            description: "App Store components daemon. Manages App Store components, in-app purchases, and receipt validation.",
            category: .appStore, expectation: .usuallyRunning
        ),
        "AquaAppearanceHelper": .init(
            description: "Aqua appearance helper. Assists with rendering legacy Aqua UI elements and appearance transitions.",
            category: .windowManager, expectation: .transient
        ),
        "ASPCarryLog": .init(
            description: "Apple System Profiler carry log. Collects and carries system profile information for diagnostics.",
            category: .diagnostics, expectation: .transient
        ),
        "assessmentagent": .init(
            description: "Assessment agent. Evaluates app notarization and security assessments for Gatekeeper policy.",
            category: .security, expectation: .transient
        ),
        "AssetCacheLocatorService": .init(
            description: "Asset Cache Locator. Discovers Content Caching servers on the local network to speed up Apple software downloads.",
            category: .networking, expectation: .transient
        ),
        "assistant_cdmd": .init(
            description: "Siri assistant context data manager. Manages contextual data used by Siri for personalized suggestions.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "assistantd": .init(
            description: "Siri assistant daemon. Core daemon that processes Siri requests and manages voice assistant sessions.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "audioanalyticsd": .init(
            description: "Audio analytics daemon. Analyzes ambient sounds for Sound Recognition features like doorbells and alarms.",
            category: .audio, expectation: .usuallyRunning
        ),
        "audioclocksyncd": .init(
            description: "Audio clock sync daemon. Synchronizes audio clocks across devices for multi-device audio playback.",
            category: .audio, expectation: .alwaysRunning
        ),
        "AudioComponentRegistrar": .init(
            description: "Audio component registrar. Registers and validates Audio Units and audio plugins for Core Audio.",
            category: .audio, expectation: .transient
        ),
        "audiomxd": .init(
            description: "Audio multiplexer daemon. Manages audio mixing and routing between multiple audio streams and devices.",
            category: .audio, expectation: .alwaysRunning
        ),
        "autofsd": .init(
            description: "Automount daemon. Automatically mounts network file systems (NFS, SMB) based on autofs maps.",
            category: .storage, expectation: .alwaysRunning
        ),
        "automationmode-writer": .init(
            description: "Automation mode writer. Manages the Automation Mode state for UI testing and accessibility automation.",
            category: .kernel, expectation: .transient
        ),
        "automountd": .init(
            description: "Automount daemon. Handles automatic mounting and unmounting of network volumes on demand.",
            category: .storage, expectation: .alwaysRunning
        ),
        "avatarsd": .init(
            description: "Avatars daemon. Manages Memoji and Animoji avatar creation, rendering, and syncing.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "avconferenced": .init(
            description: "AV conference daemon. Manages audio/video conferencing sessions for FaceTime and other calling apps.",
            category: .audio, expectation: .transient
        ),
        "axassetsd": .init(
            description: "Accessibility assets daemon. Manages downloadable accessibility resources like voices and language data.",
            category: .input, expectation: .transient
        ),

        // ━━ Apple Background Services ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "BackgroundShortcutRunner": .init(
            description: "Background shortcut runner. Executes Shortcuts automations that run in the background without user interaction.",
            category: .kernel, expectation: .transient
        ),
        "BackgroundTaskManagementAgent": .init(
            description: "Background task management agent. Controls which apps and login items are allowed to run in the background.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "backgroundtaskmanagementd": .init(
            description: "Background task management daemon. System daemon that enforces background task policies and manages login items.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "betaenrollmentagent": .init(
            description: "Beta enrollment agent. Manages enrollment in macOS beta programs and seed profiles.",
            category: .appStore, expectation: .usuallyRunning
        ),
        "betaenrollmentd": .init(
            description: "Beta enrollment daemon. Handles device enrollment state for Apple beta software programs.",
            category: .appStore, expectation: .usuallyRunning
        ),
        "BiomeAgent": .init(
            description: "Biome agent. Collects on-device behavioral data for Siri Suggestions, app predictions, and proactive features.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "BiomeSELFIngestor": .init(
            description: "Biome SELF ingestor. Ingests structured event data into the Biome knowledge store for on-device intelligence.",
            category: .kernel, expectation: .transient
        ),
        "biometrickitd": .init(
            description: "BiometricKit daemon. Provides low-level Touch ID and biometric sensor management services.",
            category: .security, expectation: .alwaysRunning
        ),
        "bluetoothuserd": .init(
            description: "Bluetooth user daemon. Manages user-level Bluetooth services and device preferences.",
            category: .input, expectation: .alwaysRunning
        ),
        "BTLEServerAgent": .init(
            description: "Bluetooth Low Energy server agent. Manages BLE GATT server operations for nearby device communication.",
            category: .input, expectation: .usuallyRunning
        ),
        "businessservicesd": .init(
            description: "Business services daemon. Manages Apple Business Manager and enterprise service integrations.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "calaccessd": .init(
            description: "Calendar access daemon. Manages calendar database access and enforces calendar privacy permissions.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "cameracaptured": .init(
            description: "Camera capture daemon. Manages camera capture sessions and coordinates camera access between apps.",
            category: .kernel, expectation: .transient
        ),
        "captiveagent": .init(
            description: "Captive network agent. Detects captive Wi-Fi portals (hotel, airport) and shows the login page.",
            category: .networking, expectation: .transient
        ),
        "CategoriesService": .init(
            description: "Categories service. Manages content categorization for Spotlight, Siri, and on-device intelligence.",
            category: .kernel, expectation: .transient
        ),
        "cdpd": .init(
            description: "Continuity device pairing daemon. Manages secure pairing between Apple devices for Continuity features.",
            category: .continuity, expectation: .alwaysRunning
        ),
        "CGPDFService": .init(
            description: "Core Graphics PDF service. Renders PDF content in a sandboxed process for security.",
            category: .kernel, expectation: .transient
        ),
        "chronod": .init(
            description: "Chrono daemon. Manages WidgetKit timeline scheduling and widget refresh intervals.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "ClassroomSettings": .init(
            description: "Classroom settings. Manages Apple Classroom education settings for managed devices.",
            category: .kernel, expectation: .transient
        ),
        "CloudTelemetryService": .init(
            description: "Cloud telemetry service. Collects anonymized telemetry data about iCloud service performance.",
            category: .cloud, expectation: .transient
        ),
        "CMFSyncAgent": .init(
            description: "Core Media Framework sync agent. Synchronizes media playback state across devices and apps.",
            category: .audio, expectation: .usuallyRunning
        ),
        "colorsync.useragent": .init(
            description: "ColorSync user agent. Manages per-user color profiles and display calibration settings.",
            category: .windowManager, expectation: .usuallyRunning
        ),
        "colorsyncd": .init(
            description: "ColorSync daemon. Manages system-wide color management, ICC profiles, and display calibration.",
            category: .windowManager, expectation: .alwaysRunning
        ),
        "CommCenter": .init(
            description: "Communications Center. Manages cellular modem communication on Macs with cellular capability.",
            category: .networking, expectation: .usuallyRunning
        ),
        "commerce": .init(
            description: "Commerce service. Handles in-app purchases and payment processing through StoreKit.",
            category: .appStore, expectation: .transient
        ),
        "communicationtrustd": .init(
            description: "Communication trust daemon. Evaluates communication safety for Messages and other apps to protect children.",
            category: .security, expectation: .usuallyRunning
        ),
        "contactsd": .init(
            description: "Contacts daemon. Manages the local contacts database and handles contact data queries from apps.",
            category: .cloud, expectation: .alwaysRunning
        ),
        "contactsdonationagent": .init(
            description: "Contacts donation agent. Processes contact interaction data to improve Siri Suggestions for contacts.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "ContainerMetadataExtractor": .init(
            description: "Container metadata extractor. Extracts metadata from sandboxed app containers for Spotlight indexing.",
            category: .storage, expectation: .transient
        ),
        "contentlinkingd": .init(
            description: "Content linking daemon. Manages deep links and content associations across apps and system services.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "ContextService": .init(
            description: "Context service. Provides contextual information about user activity to system intelligence features.",
            category: .kernel, expectation: .transient
        ),
        "ContextStoreAgent": .init(
            description: "Context store agent. Manages the on-device context store for personalized suggestions and predictions.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "contextstored": .init(
            description: "Context store daemon. Maintains the persistent on-device store of user context and activity data.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "ContinuityCaptureAgent": .init(
            description: "Continuity Camera agent. Enables using an iPhone as a webcam or document scanner for your Mac.",
            category: .continuity, expectation: .usuallyRunning
        ),
        "coreautha": .init(
            description: "Core Authentication agent. User-facing agent for Touch ID, password prompts, and Apple Watch authentication.",
            category: .security, expectation: .usuallyRunning
        ),
        "corebrightnessd": .init(
            description: "Core Brightness daemon. Manages display brightness, True Tone, Night Shift, and ambient light sensor.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "CoreDeviceService": .init(
            description: "Core Device service. Manages connections to developer devices for Xcode wireless debugging and deployment.",
            category: .developerTool, expectation: .transient
        ),
        "coreduetd": .init(
            description: "Core Duet daemon. Collects device usage patterns to optimize battery, performance, and predictive features.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "CoreLocationAgent": .init(
            description: "Core Location agent. Handles user-facing location permission prompts and location status indicators.",
            category: .location, expectation: .usuallyRunning
        ),
        "corerepaird": .init(
            description: "Core Repair daemon. Manages system repair and recovery operations for macOS components.",
            category: .kernel, expectation: .transient
        ),
        "CoreServicesUIAgent": .init(
            description: "Core Services UI agent. Displays system dialogs such as app launch confirmations and file association prompts.",
            category: .windowManager, expectation: .usuallyRunning
        ),
        "corespeechd": .init(
            description: "Core Speech daemon. Manages speech recognition, 'Hey Siri' detection, and voice processing.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "corespeechd_system": .init(
            description: "Core Speech system daemon. System-level speech recognition service for always-on 'Hey Siri' listening.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "corespotlightd": .init(
            description: "Core Spotlight daemon. Manages the Core Spotlight index used by apps to make their content searchable.",
            category: .storage, expectation: .alwaysRunning
        ),
        "coresymbolicationd": .init(
            description: "Core Symbolication daemon. Resolves memory addresses to function names in crash reports and diagnostics.",
            category: .diagnostics, expectation: .transient
        ),
        "countryd": .init(
            description: "Country daemon. Determines the device's geographic region for regulatory and locale settings.",
            category: .location, expectation: .usuallyRunning
        ),
        "CrashReporterSupportHelper": .init(
            description: "Crash Reporter support helper. Assists in collecting and formatting crash report data for submission.",
            category: .diagnostics, expectation: .transient
        ),
        "CredentialProviderExtensionHelper": .init(
            description: "Credential provider extension helper. Hosts password manager AutoFill extensions for Safari and apps.",
            category: .security, expectation: .transient
        ),
        "csnameddatad": .init(
            description: "Core Services named data daemon. Manages named data blobs for Core Services inter-process sharing.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "ctkahp": .init(
            description: "CryptoTokenKit authentication helper. Manages smart card and hardware token authentication sessions.",
            category: .security, expectation: .transient
        ),
        "ctkd": .init(
            description: "CryptoTokenKit daemon. Provides smart card, hardware security key, and token-based authentication services.",
            category: .security, expectation: .alwaysRunning
        ),
        "CursorUIViewService": .init(
            description: "Cursor UI view service. Renders custom cursor appearances and animations for accessibility and apps.",
            category: .windowManager, expectation: .transient
        ),
        "CVMServer": .init(
            description: "Core Virtual Machine server. Manages compiled GPU shader caches for Metal and OpenGL rendering.",
            category: .kernel, expectation: .alwaysRunning
        ),

        // ━━ Apple Data & Storage (Additional) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "dataaccessd": .init(
            description: "Data access daemon. Provides sandboxed access to Calendar, Contacts, and Reminders databases for apps.",
            category: .cloud, expectation: .alwaysRunning
        ),
        "deleted": .init(
            description: "Deleted daemon. Manages the trash and purges expired files to reclaim disk space.",
            category: .storage, expectation: .alwaysRunning
        ),
        "deleted_helper": .init(
            description: "Deleted helper. Assists the deleted daemon with disk space reclamation and purgeable file management.",
            category: .storage, expectation: .transient
        ),
        "diagnostics_agent": .init(
            description: "Diagnostics agent. Collects and manages diagnostic logs and reports for system health analysis.",
            category: .diagnostics, expectation: .usuallyRunning
        ),
        "diskimagesiod": .init(
            description: "Disk Images I/O daemon. Handles mounting and I/O for DMG disk images and sparse bundles.",
            category: .storage, expectation: .transient
        ),
        "DiskUnmountWatcher": .init(
            description: "Disk unmount watcher. Monitors disk unmount events and notifies apps to save data before ejection.",
            category: .storage, expectation: .usuallyRunning
        ),
        "DisplayControls": .init(
            description: "Display controls. Manages external display settings including brightness, resolution, and arrangement.",
            category: .windowManager, expectation: .transient
        ),
        "dmd": .init(
            description: "Device management daemon. Handles MDM (Mobile Device Management) profile installation and policy enforcement.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "donotdisturbd": .init(
            description: "Do Not Disturb daemon. Manages Focus modes, scheduling, and notification filtering rules.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "dprivacyd": .init(
            description: "Differential privacy daemon. Applies differential privacy techniques to analytics data before submission to Apple.",
            category: .diagnostics, expectation: .usuallyRunning
        ),
        "duetexpertd": .init(
            description: "Duet expert daemon. Provides expert system predictions for battery charging, app preloading, and resource scheduling.",
            category: .kernel, expectation: .alwaysRunning
        ),

        // ━━ Apple Services ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "EAUpdaterService": .init(
            description: "External Accessory updater service. Manages firmware updates for MFi-certified external accessories.",
            category: .kernel, expectation: .transient
        ),
        "eligibilityd": .init(
            description: "Eligibility daemon. Determines feature eligibility based on device capabilities, region, and account status.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "EscrowSecurityAlert": .init(
            description: "Escrow security alert. Displays alerts related to iCloud Keychain escrow and recovery key security.",
            category: .security, expectation: .transient
        ),
        "extensionkitservice": .init(
            description: "ExtensionKit service. Hosts and manages app extensions in isolated processes for security and stability.",
            category: .kernel, expectation: .transient
        ),
        "facetimemessagestored": .init(
            description: "FaceTime message store daemon. Stores FaceTime call history and manages call-related message data.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "fairplayd": .init(
            description: "FairPlay DRM daemon. Manages Apple's FairPlay digital rights management for purchased media and apps.",
            category: .security, expectation: .usuallyRunning
        ),
        "familycircled": .init(
            description: "Family Circle daemon. Manages Family Sharing group membership, shared purchases, and family settings.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "FamilySettings": .init(
            description: "Family Settings. Manages Screen Time, parental controls, and Family Sharing restriction policies.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "FeatureAccessAgent": .init(
            description: "Feature access agent. Manages access to system features based on device enrollment and restrictions.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "feedbackd": .init(
            description: "Feedback daemon. Handles Feedback Assistant data collection and submission for Apple beta programs.",
            category: .diagnostics, expectation: .transient
        ),
        "filevaultd": .init(
            description: "FileVault daemon. Manages full-disk encryption state, key escrow, and recovery key operations.",
            category: .security, expectation: .alwaysRunning
        ),
        "findmybeaconingd": .init(
            description: "Find My beaconing daemon. Broadcasts Bluetooth beacons so your Mac can be located via the Find My network.",
            category: .location, expectation: .alwaysRunning
        ),
        "findmydevice-user-agent": .init(
            description: "Find My Device user agent. Handles user-facing Find My interactions like playing sounds and showing alerts.",
            category: .location, expectation: .usuallyRunning
        ),
        "findmydeviced": .init(
            description: "Find My Device daemon. Reports device location to Apple's Find My network and handles remote lock/wipe.",
            category: .location, expectation: .alwaysRunning
        ),
        "FindMyDeviceSharedConfigurationXPCService": .init(
            description: "Find My Device shared configuration. XPC service for sharing Find My configuration between system components.",
            category: .location, expectation: .transient
        ),
        "findmylocateagent": .init(
            description: "Find My locate agent. Performs device location lookups and processes Find My network proximity data.",
            category: .location, expectation: .transient
        ),
        "fontd": .init(
            description: "Font daemon. Manages system font registration, font activation, and font file validation.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "fontworker": .init(
            description: "Font worker. Processes font files for registration, validation, and rendering preparation.",
            category: .kernel, expectation: .transient
        ),
        "fskit_agent": .init(
            description: "FSKit agent. User-space agent for third-party file system extensions via the FSKit framework.",
            category: .storage, expectation: .transient
        ),
        "fskit_helper": .init(
            description: "FSKit helper. Assists with file system extension operations and volume management.",
            category: .storage, expectation: .transient
        ),
        "fskitd": .init(
            description: "FSKit daemon. Manages user-space file system extensions and coordinates volume mounting.",
            category: .storage, expectation: .alwaysRunning
        ),
        "gamecontrolleragentd": .init(
            description: "Game controller agent. Manages game controller connections and input mapping for user sessions.",
            category: .input, expectation: .usuallyRunning
        ),
        "gamecontrollerd": .init(
            description: "Game controller daemon. Provides system-wide game controller discovery and HID event processing.",
            category: .input, expectation: .alwaysRunning
        ),
        "gamepolicyd": .init(
            description: "Game policy daemon. Enforces Game Center policies and parental controls for gaming features.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "generativeexperiencesd": .init(
            description: "Generative experiences daemon. Manages Apple Intelligence generative AI features and on-device model orchestration.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "GenerativeExperiencesSafetyInferenceProvider": .init(
            description: "Generative experiences safety inference. Runs safety classifiers for Apple Intelligence content generation.",
            category: .kernel, expectation: .transient
        ),
        "geoanalyticsd": .init(
            description: "Geo analytics daemon. Collects anonymized location analytics to improve Maps and location services.",
            category: .location, expectation: .usuallyRunning
        ),
        "GMSSELFIngestor": .init(
            description: "GMS SELF ingestor. Ingests structured telemetry data from Game Center and media services.",
            category: .kernel, expectation: .transient
        ),
        "GPUToolsAgentService": .init(
            description: "GPU Tools agent service. Provides GPU debugging and profiling capabilities for Metal development tools.",
            category: .developerTool, expectation: .transient
        ),
        "GPUToolsCompatService": .init(
            description: "GPU Tools compatibility service. Ensures backward compatibility for GPU profiling across macOS versions.",
            category: .developerTool, expectation: .transient
        ),
        "gputoolsserviced": .init(
            description: "GPU Tools service daemon. Hosts GPU profiling and debugging infrastructure for Xcode Instruments.",
            category: .developerTool, expectation: .transient
        ),
        "GSSCred": .init(
            description: "GSS Credential helper. Manages Kerberos and GSS-API credentials for enterprise authentication.",
            category: .security, expectation: .transient
        ),
        "HeadphoneSettingsExtension": .init(
            description: "Headphone settings extension. Manages headphone audio settings like Spatial Audio and Conversation Boost.",
            category: .audio, expectation: .transient
        ),
        "homed": .init(
            description: "Home daemon. Core daemon for HomeKit smart home management, automations, and accessory communication.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "homeenergyd": .init(
            description: "Home energy daemon. Manages HomeKit energy monitoring and grid forecast integration for smart home devices.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "homeeventsd": .init(
            description: "Home events daemon. Processes HomeKit automation triggers and executes home automation rules.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "HostInferenceProviderService": .init(
            description: "Host inference provider service. Runs on-device machine learning model inference for Apple Intelligence features.",
            category: .kernel, expectation: .transient
        ),

        // ━━ Apple iCloud & Communication ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "iCloudNotificationAgent": .init(
            description: "iCloud notification agent. Processes push notifications for iCloud data changes and sync events.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "iconservicesagent": .init(
            description: "Icon Services agent. Caches and provides app and document icons to the UI on demand.",
            category: .windowManager, expectation: .usuallyRunning
        ),
        "iconservicesd": .init(
            description: "Icon Services daemon. Generates, caches, and serves app and file type icons system-wide.",
            category: .windowManager, expectation: .alwaysRunning
        ),
        "IDSBlastDoorService": .init(
            description: "IDS BlastDoor service. Sandboxed parser for incoming iMessage content to prevent exploitation.",
            category: .security, expectation: .transient
        ),
        "IFTelemetrySELFIngestor": .init(
            description: "Intelligence Foundation telemetry ingestor. Ingests telemetry data from Apple Intelligence features.",
            category: .kernel, expectation: .transient
        ),
        "IFTranscriptSELFIngestor": .init(
            description: "Intelligence Foundation transcript ingestor. Processes transcription data for on-device intelligence.",
            category: .kernel, expectation: .transient
        ),
        "IMTranscoderAgent": .init(
            description: "iMessage transcoder agent. Transcodes media attachments (images, videos) for iMessage delivery.",
            category: .cloud, expectation: .transient
        ),
        "IMTransferAgent": .init(
            description: "iMessage transfer agent. Manages file and media transfers in iMessage conversations.",
            category: .cloud, expectation: .transient
        ),
        "inputanalyticsd": .init(
            description: "Input analytics daemon. Collects anonymized keyboard and input usage data to improve autocorrect and predictions.",
            category: .input, expectation: .usuallyRunning
        ),
        "intelligencecontextd": .init(
            description: "Intelligence context daemon. Manages contextual data for Apple Intelligence features and on-device processing.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "IntelligencePlatformComputeService": .init(
            description: "Intelligence Platform compute service. Executes on-device ML workloads for Apple Intelligence features.",
            category: .kernel, expectation: .transient
        ),
        "intelligentroutingd": .init(
            description: "Intelligent routing daemon. Routes Apple Intelligence requests between on-device and Private Cloud Compute.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "intents_helper": .init(
            description: "Intents helper. Processes SiriKit intents and action extensions for app integration with Siri.",
            category: .kernel, expectation: .transient
        ),
        "itunescloudd": .init(
            description: "iTunes Cloud daemon. Syncs iTunes and Apple Music library metadata, purchases, and playback state with iCloud.",
            category: .cloud, expectation: .usuallyRunning
        ),

        // ━━ Apple Hardware & Drivers ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "IOMFB_bics_daemon": .init(
            description: "IOMFB display daemon. Manages the display frame buffer and brightness control for Apple Silicon displays.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "IOUserBluetoothSerialDriver": .init(
            description: "IO User Bluetooth serial driver. User-space DriverKit driver for Bluetooth serial communication.",
            category: .input, expectation: .usuallyRunning
        ),
        "KernelEventAgent": .init(
            description: "Kernel event agent. Monitors kernel-level events and forwards them to user-space listeners.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "kernelmanagerd": .init(
            description: "Kernel manager daemon. Manages kernel extension loading, system extension approval, and driver registration.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "keybagd": .init(
            description: "Keybag daemon. Manages the system keybag that stores data protection encryption keys.",
            category: .security, expectation: .alwaysRunning
        ),
        "keyboardservicesd": .init(
            description: "Keyboard services daemon. Manages keyboard firmware, settings, and hardware keyboard communication.",
            category: .input, expectation: .alwaysRunning
        ),
        "keyboxd": .init(
            description: "Keybox daemon. Manages secure key storage and retrieval for authentication credentials.",
            category: .security, expectation: .alwaysRunning
        ),
        "knowledge-agent": .init(
            description: "Knowledge agent. Collects on-device activity data for Siri Suggestions and Spotlight predictions.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "knowledgeconstructiond": .init(
            description: "Knowledge construction daemon. Builds the on-device knowledge graph used for Siri and search intelligence.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "liquiddetectiond": .init(
            description: "Liquid detection daemon. Monitors for liquid intrusion in ports and connectors on supported hardware.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "liveactivitiesd": .init(
            description: "Live Activities daemon. Manages Live Activities and Dynamic Island updates from apps.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "LocalAuthenticationRemoteService": .init(
            description: "Local Authentication remote service. Handles biometric and password authentication requests from sandboxed apps.",
            category: .security, expectation: .transient
        ),
        "localizationswitcherd": .init(
            description: "Localization switcher daemon. Manages language and locale switching for apps and system UI.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "logd_helper": .init(
            description: "Log daemon helper. Assists the unified logging system with log storage, compression, and rotation.",
            category: .kernel, expectation: .transient
        ),
        "logind": .init(
            description: "Login daemon. Manages user login sessions, authentication, and session lifecycle.",
            category: .security, expectation: .alwaysRunning
        ),
        "lsd": .init(
            description: "Launch Services daemon helper. Resolves file type associations and app registrations for Launch Services.",
            category: .kernel, expectation: .alwaysRunning
        ),

        // ━━ Apple Mail & Messages ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "maild": .init(
            description: "Mail daemon. Handles background email fetching, indexing, and push notification processing for Mail.app.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "managedappdistributionagent": .init(
            description: "Managed app distribution agent. Manages enterprise app distribution via MDM for user sessions.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "managedappdistributiond": .init(
            description: "Managed app distribution daemon. Handles MDM-managed app installation and updates for enterprise environments.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "managedcorespotlightd": .init(
            description: "Managed Core Spotlight daemon. Indexes content for managed and enterprise apps in the Spotlight database.",
            category: .storage, expectation: .transient
        ),
        "ManagedSettingsAgent": .init(
            description: "Managed Settings agent. Enforces Screen Time and MDM restriction policies on the user session.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "mapssyncd": .init(
            description: "Maps sync daemon. Syncs Maps favorites, guides, and collections across devices via iCloud.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "mdbulkimport": .init(
            description: "Spotlight bulk import. Performs batch indexing of large numbers of files into the Spotlight database.",
            category: .storage, expectation: .transient
        ),
        "mdwrite": .init(
            description: "Spotlight write worker. Writes metadata entries into the Spotlight search index database.",
            category: .storage, expectation: .transient
        ),
        "media-indexer": .init(
            description: "Media indexer. Indexes photos and videos for the Photos library and on-device ML analysis.",
            category: .storage, expectation: .transient
        ),
        "mediaanalysisd": .init(
            description: "Media analysis daemon. Performs on-device ML analysis of photos and videos (faces, objects, scenes, text).",
            category: .kernel, expectation: .usuallyRunning
        ),
        "mediaanalysisd-access": .init(
            description: "Media analysis access service. Provides controlled access to media analysis results for apps.",
            category: .kernel, expectation: .transient
        ),
        "mediaremoteagent": .init(
            description: "Media Remote agent. User-facing agent for Now Playing controls and media session management.",
            category: .audio, expectation: .usuallyRunning
        ),
        "MENotificationAgent": .init(
            description: "Mail Extension notification agent. Delivers notifications from Mail app extensions.",
            category: .cloud, expectation: .transient
        ),
        "Messages": .init(
            description: "Apple Messages. Sends and receives iMessages and SMS/MMS via Continuity with iPhone.",
            category: .appleApp, expectation: .userLaunched
        ),
        "MessagesActionExtension": .init(
            description: "Messages action extension. Hosts iMessage app extensions and sticker packs within Messages.",
            category: .appleApp, expectation: .transient
        ),
        "MessagesBlastDoorService": .init(
            description: "Messages BlastDoor service. Sandboxed parser for incoming message content to prevent security exploits.",
            category: .security, expectation: .transient
        ),
        "milod": .init(
            description: "Milo daemon. Manages on-device machine learning model lifecycle and inference scheduling.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "misagent": .init(
            description: "Mobile Installation agent. Manages provisioning profiles and app installation policies.",
            category: .security, expectation: .usuallyRunning
        ),
        "mlhostd": .init(
            description: "ML host daemon. Hosts Core ML model execution in isolated processes for security and resource management.",
            category: .kernel, expectation: .transient
        ),
        "mmaintenanced": .init(
            description: "Mobile maintenance daemon. Performs periodic maintenance tasks for system data and caches.",
            category: .kernel, expectation: .periodic
        ),
        "mobileactivationd": .init(
            description: "Mobile activation daemon. Manages device activation state and Apple activation server communication.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "mobileassetd": .init(
            description: "Mobile Asset daemon. Downloads on-demand system assets like voices, fonts, and ML models from Apple.",
            category: .appStore, expectation: .usuallyRunning
        ),
        "mobilerepaird": .init(
            description: "Mobile repair daemon. Handles device repair validation and component pairing authentication.",
            category: .kernel, expectation: .transient
        ),
        "mobiletimerd": .init(
            description: "Mobile timer daemon. Manages system timers, alarms, and scheduled wake events.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "MobileTimerIntents": .init(
            description: "Mobile Timer intents. Handles Siri intents for setting timers and alarms via voice commands.",
            category: .kernel, expectation: .transient
        ),
        "ModelCatalogAgent": .init(
            description: "Model Catalog agent. Manages the catalog of on-device ML models available for Apple Intelligence features.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "modelcatalogd": .init(
            description: "Model Catalog daemon. Downloads, manages, and serves ML models for on-device intelligence features.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "modelmanagerd": .init(
            description: "Model manager daemon. Manages lifecycle of on-device machine learning models including updates and storage.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "mscamerad-xpc": .init(
            description: "Camera XPC service. Provides sandboxed camera access to apps via XPC for privacy and security.",
            category: .kernel, expectation: .transient
        ),
        "MTLCompilerService": .init(
            description: "Metal compiler service. Compiles Metal GPU shaders at runtime for graphics and compute workloads.",
            category: .kernel, expectation: .transient
        ),

        // ━━ Apple Networking & Security (Additional) ━━━━━━━━━━━━━━━━━━━━━━━━━

        "naturallanguaged": .init(
            description: "Natural Language daemon. Provides on-device natural language processing for text analysis and entity recognition.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "nbagent": .init(
            description: "NetBoot agent. Manages NetBoot/NetInstall network boot image selection (enterprise environments).",
            category: .networking, expectation: .transient
        ),
        "neagent": .init(
            description: "Network Extension agent. Hosts user-facing UI for VPN, content filter, and DNS proxy extensions.",
            category: .networking, expectation: .usuallyRunning
        ),
        "nearbyd": .init(
            description: "Nearby daemon. Discovers nearby Apple devices for AirDrop, Handoff, and proximity-based features.",
            category: .continuity, expectation: .alwaysRunning
        ),
        "nehelper": .init(
            description: "Network Extension helper. Validates app entitlements and manages Network Extension plugin loading.",
            category: .networking, expectation: .transient
        ),
        "newsd": .init(
            description: "News daemon. Manages Apple News content fetching, caching, and personalized feed recommendations.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "nfcd": .init(
            description: "NFC daemon. Manages Near Field Communication hardware for Apple Pay and NFC tag reading.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "nsattributedstringagent": .init(
            description: "NSAttributedString agent. Renders rich text content in sandboxed processes for security.",
            category: .kernel, expectation: .transient
        ),
        "oahd": .init(
            description: "Rosetta translation daemon. Manages Rosetta 2 x86_64 binary translation on Apple Silicon Macs.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "online-auth-agent": .init(
            description: "Online authorization agent. Handles online authentication flows for Apple ID and third-party services.",
            category: .security, expectation: .transient
        ),
        "ospredictiond": .init(
            description: "OS prediction daemon. Provides predictive text, autocorrection, and typing suggestions system-wide.",
            category: .kernel, expectation: .usuallyRunning
        ),

        // ━━ Apple Services (More) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "parsecd": .init(
            description: "Parsec daemon. Powers Spotlight Suggestions and Siri knowledge by searching Apple's online knowledge base.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "parsec-fbf": .init(
            description: "Parsec feedback service. Provides relevance feedback for Spotlight and Siri search results.",
            category: .kernel, expectation: .transient
        ),
        "passd": .init(
            description: "Passes daemon. Manages Apple Wallet passes, boarding passes, tickets, and loyalty cards.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "PasswordBreachAgent": .init(
            description: "Password Breach agent. Checks saved passwords against known data breaches and alerts for compromised credentials.",
            category: .security, expectation: .periodic
        ),
        "pboard": .init(
            description: "Pasteboard server. Manages the system clipboard for copy/paste and drag-and-drop operations.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "pbs": .init(
            description: "Pasteboard server helper. Provides Services menu items and pasteboard type conversion between apps.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "peopled": .init(
            description: "People daemon. Manages the people suggestion database for Siri, Spotlight, and sharing suggestions.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "PerfPowerServices": .init(
            description: "Performance and Power services. Monitors system performance metrics and power consumption for optimization.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "PerfPowerTelemetryClientRegistrationService": .init(
            description: "Performance power telemetry registration. Registers clients for performance and power usage telemetry collection.",
            category: .diagnostics, expectation: .transient
        ),
        "photoanalysisd": .init(
            description: "Photo analysis daemon. Runs on-device ML to detect faces, objects, and scenes in your Photos library.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "pidinfo": .init(
            description: "Process ID info helper. Provides process information lookups for system monitoring and diagnostics.",
            category: .kernel, expectation: .transient
        ),
        "pkd": .init(
            description: "PlugInKit daemon. Discovers, registers, and manages app extensions (share, today, finder, etc.).",
            category: .kernel, expectation: .alwaysRunning
        ),
        "PlugInLibraryService": .init(
            description: "PlugIn library service. Hosts and manages loadable bundles and plugin libraries for system frameworks.",
            category: .kernel, expectation: .transient
        ),
        "postersyncd": .init(
            description: "Poster sync daemon. Syncs Lock Screen poster designs and configurations across devices via iCloud.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "PowerChime": .init(
            description: "Power chime. Plays the charging sound when connecting your Mac to power.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "powerexperienced": .init(
            description: "Power experience daemon. Manages battery health, optimized charging, and power-related user experiences.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "PowerUIAgent": .init(
            description: "Power UI agent. Displays battery status, low battery warnings, and charging notifications in the UI.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "proactived": .init(
            description: "Proactive daemon. Coordinates proactive suggestions across Siri, Spotlight, and system intelligence features.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "progressd": .init(
            description: "Progress daemon. Tracks and reports progress of long-running system operations like updates and migrations.",
            category: .kernel, expectation: .transient
        ),
        "promotedcontentd": .init(
            description: "Promoted content daemon. Manages promoted content and personalized recommendations in App Store and News.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "ProtectedCloudKeySyncing": .init(
            description: "Protected Cloud Key Syncing. Securely syncs encryption keys across devices via iCloud Keychain.",
            category: .security, expectation: .usuallyRunning
        ),
        "ptpcamerad": .init(
            description: "PTP camera daemon. Manages connections to cameras via Picture Transfer Protocol for photo import.",
            category: .kernel, expectation: .transient
        ),

        // ━━ Apple QuickLook & Safari (Additional) ━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "QLPreviewGenerationExtension": .init(
            description: "QuickLook preview generation extension. Generates document previews for Quick Look and Finder thumbnails.",
            category: .kernel, expectation: .transient
        ),
        "QuickLookUIService": .init(
            description: "QuickLook UI service. Renders Quick Look preview panels when pressing Space in Finder.",
            category: .kernel, expectation: .transient
        ),
        "recentsd": .init(
            description: "Recents daemon. Tracks recently opened files and applications for Finder and app menus.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "remoted": .init(
            description: "Remote daemon. Manages remote device connections for Xcode debugging and device management.",
            category: .continuity, expectation: .alwaysRunning
        ),
        "remotepairingd": .init(
            description: "Remote pairing daemon. Handles device pairing for wireless Xcode debugging and remote device connections.",
            category: .continuity, expectation: .alwaysRunning
        ),
        "replayd": .init(
            description: "Replay daemon. Manages screen recording and replay features for capturing system and app activity.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "reversetemplated": .init(
            description: "Reverse template daemon. Processes reverse templates for document and content recognition.",
            category: .kernel, expectation: .transient
        ),
        "routined": .init(
            description: "Routine daemon. Learns your daily routines and location patterns for proactive suggestions and Focus modes.",
            category: .location, expectation: .alwaysRunning
        ),
        "rtcreportingd": .init(
            description: "RTC reporting daemon. Collects and reports real-time communication quality metrics for FaceTime and calls.",
            category: .diagnostics, expectation: .usuallyRunning
        ),
        "SAExtensionOrchestrator": .init(
            description: "Screen Time extension orchestrator. Manages Screen Time app extension lifecycle and data flow.",
            category: .kernel, expectation: .transient
        ),
        "SafariBookmarksSyncAgent": .init(
            description: "Safari Bookmarks sync agent. Syncs Safari bookmarks, reading list, and tabs via iCloud.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "SafariLaunchAgent": .init(
            description: "Safari launch agent. Manages Safari background tasks, extension updates, and prewarming.",
            category: .appleApp, expectation: .usuallyRunning
        ),
        "SafariNotificationAgent": .init(
            description: "Safari notification agent. Handles web push notifications from websites via Safari.",
            category: .appleApp, expectation: .usuallyRunning
        ),
        "sandboxd": .init(
            description: "Sandbox daemon. Enforces App Sandbox policies and logs sandbox violation attempts.",
            category: .security, expectation: .alwaysRunning
        ),
        "ScopedBookmarkAgent": .init(
            description: "Scoped bookmark agent. Manages security-scoped bookmarks for sandboxed app file access.",
            category: .security, expectation: .usuallyRunning
        ),
        "ScreenTimeAgent": .init(
            description: "Screen Time agent. Tracks app usage, enforces time limits, and manages Screen Time reports.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "searchpartyd": .init(
            description: "Search Party daemon. Participates in the Find My network to help locate lost Apple devices and AirTags.",
            category: .location, expectation: .alwaysRunning
        ),
        "searchpartyuseragent": .init(
            description: "Search Party user agent. Handles user-facing Find My network operations and item tracking notifications.",
            category: .location, expectation: .usuallyRunning
        ),
        "secd": .init(
            description: "Security daemon (user). Manages per-user Keychain access, certificate trust, and secure key operations.",
            category: .security, expectation: .alwaysRunning
        ),
        "securityd_system": .init(
            description: "Security daemon (system). System-level Keychain management and certificate trust evaluation.",
            category: .security, expectation: .alwaysRunning
        ),
        "seputil": .init(
            description: "Secure Enclave Processor utility. Communicates with the Secure Enclave for key management and biometric data.",
            category: .security, expectation: .transient
        ),
        "seserviced": .init(
            description: "Secure Element service daemon. Manages NFC Secure Element operations for Apple Pay and contactless payments.",
            category: .security, expectation: .alwaysRunning
        ),
        "SetStoreUpdateService": .init(
            description: "Settings Store update service. Manages updates to system settings and preference data stores.",
            category: .kernel, expectation: .transient
        ),
        "sharedfilelistd": .init(
            description: "Shared file list daemon. Manages login items, recent documents, and favorite servers lists.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "ShareSheetUI": .init(
            description: "Share Sheet UI service. Renders the system share sheet when sharing content from apps.",
            category: .windowManager, expectation: .transient
        ),
        "SidecarRelay": .init(
            description: "Sidecar relay. Relays display data between your Mac and iPad when using Sidecar.",
            category: .continuity, expectation: .transient
        ),
        "Siri": .init(
            description: "Siri voice assistant. Processes voice commands and queries using on-device and server-based intelligence.",
            category: .appleApp, expectation: .usuallyRunning
        ),
        "siriactionsd": .init(
            description: "Siri Actions daemon. Manages Siri Shortcuts actions, automation triggers, and intent donations.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "siriinferenced": .init(
            description: "Siri inference daemon. Runs on-device ML models for Siri natural language understanding.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "siriknowledged": .init(
            description: "Siri knowledge daemon. Manages Siri's on-device knowledge base for personalized responses.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "SiriNCService": .init(
            description: "Siri Notification Center service. Displays Siri results and suggestions in Notification Center.",
            category: .kernel, expectation: .transient
        ),
        "SiriSuggestionsBookkeepingService": .init(
            description: "Siri Suggestions bookkeeping. Maintains usage statistics for improving Siri Suggestion relevance.",
            category: .kernel, expectation: .transient
        ),
        "sirittsd": .init(
            description: "Siri text-to-speech daemon. Generates synthesized speech output for Siri responses.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "smd": .init(
            description: "Service management daemon. Manages background services, login items, and launch agent registration.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "sociallayerd": .init(
            description: "Social layer daemon. Manages social interactions data for contact suggestions and sharing predictions.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "SoftwareUpdateNotificationManager": .init(
            description: "Software Update notification manager. Displays notifications about available macOS and app updates.",
            category: .appStore, expectation: .usuallyRunning
        ),
        "SourceKitService": .init(
            description: "SourceKit service. Provides Swift and Objective-C code intelligence for IDEs (syntax highlighting, completion).",
            category: .developerTool, expectation: .transient
        ),
        "SpeechSynthesisServerXPC": .init(
            description: "Speech synthesis server. Generates text-to-speech audio output for VoiceOver and spoken content.",
            category: .input, expectation: .transient
        ),
        "Spotlight": .init(
            description: "Spotlight search UI. The search interface accessed via Cmd+Space for finding files, apps, and information.",
            category: .appleApp, expectation: .usuallyRunning
        ),
        "spotlightknowledged": .init(
            description: "Spotlight knowledge daemon. Manages the knowledge graph that powers Spotlight Suggestions and rich results.",
            category: .storage, expectation: .usuallyRunning
        ),
        "StatusKitAgent": .init(
            description: "StatusKit agent. Manages system status indicators and status bar items for system services.",
            category: .windowManager, expectation: .usuallyRunning
        ),
        "storagekitd": .init(
            description: "StorageKit daemon. Manages disk and volume operations for Disk Utility and system storage management.",
            category: .storage, expectation: .alwaysRunning
        ),
        "studentd": .init(
            description: "Student daemon. Supports Apple Classroom for students, allowing teachers to manage devices in educational settings.",
            category: .kernel, expectation: .transient
        ),
        "SubmitDiagInfo": .init(
            description: "Submit diagnostic info. Sends crash reports and diagnostic data to Apple when user opts in.",
            category: .diagnostics, expectation: .periodic
        ),
        "suggestd": .init(
            description: "Suggestions daemon. Generates proactive suggestions for contacts, locations, and events across the system.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "SWBBuildService": .init(
            description: "Swift Build service. Xcode's build system service that manages project compilation and linking.",
            category: .developerTool, expectation: .transient
        ),
        "swcd": .init(
            description: "Shared Web Credentials daemon. Manages AutoFill credential sharing between apps and their associated websites.",
            category: .security, expectation: .usuallyRunning
        ),
        "swift-plugin-server": .init(
            description: "Swift plugin server. Hosts Swift compiler plugins and macro expansions in isolated processes.",
            category: .developerTool, expectation: .transient
        ),
        "symptomsd-diag": .init(
            description: "Symptoms diagnostic service. Collects network diagnostics data for analyzing connectivity issues.",
            category: .diagnostics, expectation: .transient
        ),
        "syncdefaultsd": .init(
            description: "Sync defaults daemon. Synchronizes user defaults and preferences across devices via iCloud.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "sysextd": .init(
            description: "System Extensions daemon. Manages system extension installation, updates, and approval for kext replacements.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "sysmond": .init(
            description: "System monitor daemon. Monitors system resource usage and triggers alerts for abnormal conditions.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "systemsoundserverd": .init(
            description: "System Sound server. Plays system alert sounds, UI feedback sounds, and notification tones.",
            category: .audio, expectation: .alwaysRunning
        ),
        "systemstats": .init(
            description: "System statistics. Collects long-term system performance statistics for diagnostics and energy reporting.",
            category: .diagnostics, expectation: .alwaysRunning
        ),
        "systemstatusd": .init(
            description: "System status daemon. Monitors and reports overall system health status to other services.",
            category: .kernel, expectation: .alwaysRunning
        ),

        // ━━ Apple System UI (Additional) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "talagentd": .init(
            description: "TAL agent daemon. Manages Transparency, Audit, and Logging data for system accountability.",
            category: .security, expectation: .usuallyRunning
        ),
        "tccd": .init(
            description: "TCC daemon. Enforces privacy permissions (camera, microphone, location, etc.) at the system level.",
            category: .security, expectation: .alwaysRunning
        ),
        "textcomposerd": .init(
            description: "Text composer daemon. Manages text composition, autocorrect, and predictive text input.",
            category: .input, expectation: .usuallyRunning
        ),
        "textunderstandingd": .init(
            description: "Text understanding daemon. Provides on-device text analysis for data detection (dates, addresses, links).",
            category: .kernel, expectation: .usuallyRunning
        ),
        "TGOnDeviceInferenceProviderService": .init(
            description: "Text Generation on-device inference. Runs on-device large language model inference for Apple Intelligence.",
            category: .kernel, expectation: .transient
        ),
        "ThemeWidgetControlViewService": .init(
            description: "Theme widget control view service. Renders themed widget controls for Lock Screen and Home Screen widgets.",
            category: .windowManager, expectation: .transient
        ),
        "timed": .init(
            description: "Time daemon. Manages system clock synchronization via NTP and time zone detection.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "tipsd": .init(
            description: "Tips daemon. Manages and delivers Tips app content and proactive feature discovery notifications.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "translationd": .init(
            description: "Translation daemon. Provides on-device text and speech translation for the Translate app and system-wide translation.",
            category: .kernel, expectation: .transient
        ),
        "transparencyd": .init(
            description: "Transparency daemon. Manages Apple's Certificate Transparency and system integrity verification logs.",
            category: .security, expectation: .alwaysRunning
        ),
        "TrialArchivingService": .init(
            description: "Trial archiving service. Archives experimental feature flag data and A/B testing results.",
            category: .kernel, expectation: .transient
        ),
        "triald": .init(
            description: "Trial daemon. Manages feature flags, experiments, and gradual feature rollouts from Apple.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "triald_system": .init(
            description: "Trial system daemon. System-level feature flag management for macOS configuration experiments.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "trustdFileHelper": .init(
            description: "Trust daemon file helper. Assists trustd with reading and caching certificate trust data from disk.",
            category: .security, expectation: .transient
        ),
        "TrustedPeersHelper": .init(
            description: "Trusted Peers helper. Manages the iCloud Keychain trusted device circle and peer verification.",
            category: .security, expectation: .usuallyRunning
        ),
        "UARPUpdaterServiceUSBPD": .init(
            description: "UARP USB-PD updater service. Updates firmware on USB Power Delivery accessories via Apple's UARP protocol.",
            category: .kernel, expectation: .transient
        ),
        "UIKitSystem": .init(
            description: "UIKit system service. Provides UIKit framework support for Catalyst and iOS apps running on macOS.",
            category: .windowManager, expectation: .usuallyRunning
        ),
        "universalAccessAuthWarn": .init(
            description: "Universal Access auth warning. Displays warnings when apps request accessibility permissions.",
            category: .input, expectation: .transient
        ),
        "UniversalControl": .init(
            description: "Universal Control. Allows a single keyboard and mouse to control multiple Macs and iPads nearby.",
            category: .continuity, expectation: .usuallyRunning
        ),
        "UsageTrackingAgent": .init(
            description: "Usage tracking agent. Tracks app and device usage for Screen Time reporting and analytics.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "usbmuxd": .init(
            description: "USB multiplexer daemon. Multiplexes connections to iOS devices over USB for syncing and development.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "useractivityd": .init(
            description: "User Activity daemon. Manages NSUserActivity data for Handoff, Spotlight indexing, and Siri Suggestions.",
            category: .continuity, expectation: .usuallyRunning
        ),
        "usermanagerd": .init(
            description: "User manager daemon. Manages user account creation, modification, and session management.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "usernoted": .init(
            description: "User notification daemon. Delivers and manages user-facing notifications for system services.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "UserNotificationCenter": .init(
            description: "User Notification Center. Processes and displays user notification alerts and permission requests.",
            category: .windowManager, expectation: .usuallyRunning
        ),
        "usernotificationsd": .init(
            description: "User notifications daemon. Routes user notifications from apps to Notification Center and manages delivery.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "UVCAssistant": .init(
            description: "UVC Assistant. Manages USB Video Class webcams and external cameras connected via USB.",
            category: .kernel, expectation: .transient
        ),
        "ViewBridgeAuxiliary": .init(
            description: "ViewBridge auxiliary. Bridges AppKit and UIKit views for system services and preference panes.",
            category: .windowManager, expectation: .transient
        ),

        // ━━ Apple Media & Widgets ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "WallpaperAerialsExtension": .init(
            description: "Wallpaper Aerials extension. Renders animated aerial screensaver and wallpaper content.",
            category: .windowManager, expectation: .transient
        ),
        "WallpaperAgent": .init(
            description: "Wallpaper agent. Manages desktop wallpaper, dynamic wallpapers, and wallpaper shuffle schedules.",
            category: .windowManager, expectation: .usuallyRunning
        ),
        "watchdogd": .init(
            description: "Watchdog daemon. Monitors system health and restarts critical services that become unresponsive.",
            category: .kernel, expectation: .alwaysRunning
        ),
        "webinspectord": .init(
            description: "Web Inspector daemon. Provides Web Inspector debugging for Safari and WebKit-based apps.",
            category: .developerTool, expectation: .transient
        ),
        "webprivacyd": .init(
            description: "Web privacy daemon. Manages Intelligent Tracking Prevention and privacy protections for Safari.",
            category: .security, expectation: .usuallyRunning
        ),
        "wifivelocityd": .init(
            description: "Wi-Fi velocity daemon. Measures Wi-Fi performance and throughput for network quality assessments.",
            category: .networking, expectation: .usuallyRunning
        ),
        "WindowManager": .init(
            description: "Window Manager. Provides Stage Manager, window tiling, and window management features on macOS.",
            category: .windowManager, expectation: .alwaysRunning
        ),
        "WirelessRadioManagerd": .init(
            description: "Wireless Radio Manager daemon. Coordinates wireless radio state for Wi-Fi, Bluetooth, and Airplane Mode.",
            category: .networking, expectation: .alwaysRunning
        ),
        "XPCTimeStampingService": .init(
            description: "XPC time-stamping service. Provides trusted timestamps for code signing and document verification.",
            category: .security, expectation: .transient
        ),
        "XProtectBridgeService": .init(
            description: "XProtect Bridge service. Bridges XProtect malware definitions between legacy and modern scanning engines.",
            category: .security, expectation: .transient
        ),
        "xprotectd": .init(
            description: "XProtect daemon. Core malware scanning daemon that checks files against Apple's malware signature database.",
            category: .security, expectation: .alwaysRunning
        ),
        "XProtectPluginService": .init(
            description: "XProtect plugin service. Hosts XProtect scanning plugins for analyzing specific file types and behaviors.",
            category: .security, expectation: .transient
        ),

        // ━━ Third-Party (Additional) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "Fantastical": .init(
            description: "Fantastical calendar app. Feature-rich calendar with natural language event creation and multiple calendar set support.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "hugo": .init(
            description: "Hugo static site generator. Builds fast static websites from Markdown content and templates.",
            category: .thirdParty, expectation: .transient
        ),
        "ollama": .init(
            description: "Ollama local LLM runtime. Runs large language models locally on your Mac for private AI inference.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Superhuman": .init(
            description: "Superhuman email client. High-performance email app with keyboard-driven workflow and AI features.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "zed": .init(
            description: "Zed code editor. High-performance, multiplayer code editor built in Rust with GPU-accelerated rendering.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Claude": .init(
            description: "Claude by Anthropic. AI assistant desktop app for conversation, analysis, and coding assistance.",
            category: .thirdParty, expectation: .userLaunched
        ),
        "Codex": .init(
            description: "OpenAI Codex CLI tool. Command-line AI coding assistant for code generation and editing.",
            category: .thirdParty, expectation: .transient
        ),
        "Autoupdate": .init(
            description: "Sparkle Autoupdate. Background updater for apps using the Sparkle framework for automatic updates.",
            category: .thirdParty, expectation: .transient
        ),
        "ShipIt": .init(
            description: "Squirrel ShipIt updater. Background update installer used by Electron apps for applying updates.",
            category: .thirdParty, expectation: .transient
        ),

        // ━━ Apple com.apple.* Processes ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "com.apple.accessibility.mediaaccessibilityd": .init(
            description: "Media accessibility daemon. Provides closed captions, subtitles, and audio descriptions for media playback.",
            category: .input, expectation: .usuallyRunning
        ),
        "com.apple.appkit.xpc.openAndSavePanelService": .init(
            description: "AppKit Open/Save panel service. Renders file open and save dialogs in a sandboxed process.",
            category: .windowManager, expectation: .transient
        ),
        "com.apple.AppleUserHIDDrivers": .init(
            description: "Apple User HID Drivers. User-space DriverKit drivers for keyboards, mice, and other HID devices.",
            category: .input, expectation: .alwaysRunning
        ),
        "com.apple.audio.SandboxHelper": .init(
            description: "Audio sandbox helper. Provides sandboxed audio access for apps with restricted permissions.",
            category: .audio, expectation: .transient
        ),
        "com.apple.AuthenticationServices.Helper": .init(
            description: "Authentication Services helper. Hosts Sign in with Apple, passkey, and AutoFill password UI.",
            category: .security, expectation: .transient
        ),
        "com.apple.CloudDocs.iCloudDriveFileProvider": .init(
            description: "iCloud Drive file provider. Manages iCloud Drive file access, downloads, and uploads via the File Provider framework.",
            category: .cloud, expectation: .usuallyRunning
        ),
        "com.apple.CloudPhotosConfiguration": .init(
            description: "Cloud Photos configuration. Manages iCloud Photos settings and sync configuration.",
            category: .cloud, expectation: .transient
        ),
        "com.apple.cmio.registerassistantservice": .init(
            description: "CoreMediaIO register assistant. Registers camera and video capture devices with the CoreMediaIO framework.",
            category: .kernel, expectation: .transient
        ),
        "com.apple.cmio.videodriverkithostextension": .init(
            description: "CoreMediaIO video DriverKit host. Hosts user-space camera drivers via DriverKit for video capture.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "com.apple.CodeSigningHelper": .init(
            description: "Code Signing helper. Validates code signatures and entitlements for apps and system components.",
            category: .security, expectation: .transient
        ),
        "com.apple.ColorSyncXPCAgent": .init(
            description: "ColorSync XPC agent. Provides color profile management and conversion via XPC for sandboxed apps.",
            category: .windowManager, expectation: .transient
        ),
        "com.apple.CoreSimulator.CoreSimulatorService": .init(
            description: "CoreSimulator service. Manages iOS/watchOS/tvOS simulator device lifecycle for Xcode development.",
            category: .developerTool, expectation: .transient
        ),
        "com.apple.dock.external.extra.arm64": .init(
            description: "Dock external extra (ARM64). Provides additional Dock functionality for external displays on Apple Silicon.",
            category: .windowManager, expectation: .transient
        ),
        "com.apple.dock.extra": .init(
            description: "Dock extra. Renders additional Dock UI elements and animations.",
            category: .windowManager, expectation: .usuallyRunning
        ),
        "com.apple.DriverKit-AppleBCMWLAN": .init(
            description: "Apple BCM WLAN DriverKit driver. User-space Wi-Fi driver for Broadcom wireless chipsets.",
            category: .networking, expectation: .alwaysRunning
        ),
        "com.apple.DriverKit-IOUserDockChannelSerial": .init(
            description: "IOUser Dock Channel Serial driver. User-space DriverKit driver for dock and serial communication channels.",
            category: .kernel, expectation: .usuallyRunning
        ),
        "com.apple.dt.SKAgent": .init(
            description: "StoreKit agent (dev tools). Manages StoreKit testing and in-app purchase simulation during development.",
            category: .developerTool, expectation: .transient
        ),
        "com.apple.dt.Xcode.KeychainService": .init(
            description: "Xcode Keychain service. Manages code signing certificates and provisioning profile access for Xcode builds.",
            category: .developerTool, expectation: .transient
        ),
        "com.apple.dt.Xcode.sourcecontrol.WorkingCopyScanner": .init(
            description: "Xcode source control scanner. Scans working copy directories for source control status in Xcode navigator.",
            category: .developerTool, expectation: .transient
        ),
        "com.apple.FaceTime.FTConversationService": .init(
            description: "FaceTime conversation service. Manages active FaceTime call sessions and conversation state.",
            category: .cloud, expectation: .transient
        ),
        "com.apple.fskit.exfat": .init(
            description: "FSKit exFAT. User-space file system implementation for reading and writing exFAT-formatted volumes.",
            category: .storage, expectation: .transient
        ),
        "com.apple.fskit.msdos": .init(
            description: "FSKit MS-DOS/FAT. User-space file system implementation for reading and writing FAT/FAT32-formatted volumes.",
            category: .storage, expectation: .transient
        ),
        "com.apple.geod": .init(
            description: "Geo services daemon (bundled). Handles map data, geocoding, and routing for Maps and location-based apps.",
            category: .location, expectation: .transient
        ),
        "com.apple.hiservices-xpcservice": .init(
            description: "HI Services XPC. Provides Human Interface services for accessibility and UI element inspection.",
            category: .input, expectation: .transient
        ),
        "com.apple.PassKit.PaymentAuthorizationUIExtension": .init(
            description: "PassKit payment authorization UI. Renders Apple Pay payment authorization sheets in apps and Safari.",
            category: .security, expectation: .transient
        ),
        "com.apple.photos.ImageConversionService": .init(
            description: "Photos image conversion service. Converts between image formats (HEIF, JPEG, RAW) for the Photos app.",
            category: .kernel, expectation: .transient
        ),
        "com.apple.quicklook.ThumbnailsAgent": .init(
            description: "QuickLook thumbnails agent. Generates file thumbnails for Finder, Spotlight, and Quick Look previews.",
            category: .kernel, expectation: .transient
        ),
        "com.apple.Safari.History": .init(
            description: "Safari History service. Manages Safari browsing history storage and search in a sandboxed process.",
            category: .appleApp, expectation: .transient
        ),
        "com.apple.Safari.SafeBrowsing.Service": .init(
            description: "Safari Safe Browsing service. Checks URLs against known malicious sites to protect against phishing and malware.",
            category: .security, expectation: .transient
        ),
        "com.apple.Safari.SandboxBroker": .init(
            description: "Safari sandbox broker. Mediates file system access for sandboxed Safari web processes.",
            category: .appleApp, expectation: .transient
        ),
        "com.apple.Safari.SearchHelper": .init(
            description: "Safari search helper. Processes search queries and provides search suggestions for Safari's address bar.",
            category: .appleApp, expectation: .transient
        ),
        "com.apple.SafariPlatformSupport.Helper": .init(
            description: "Safari Platform Support helper. Provides platform integration services for Safari extensions and web features.",
            category: .appleApp, expectation: .transient
        ),
        "com.apple.sbd": .init(
            description: "Sandbox daemon (bundled). Enforces sandbox restrictions and manages sandbox profiles for system services.",
            category: .security, expectation: .alwaysRunning
        ),
        "com.apple.siri.embeddedspeech": .init(
            description: "Siri embedded speech. On-device speech recognition engine for offline Siri processing.",
            category: .kernel, expectation: .transient
        ),
        "com.apple.Virtualization.VirtualMachine": .init(
            description: "Virtualization framework VM. Hosts lightweight virtual machines using Apple's Virtualization framework.",
            category: .kernel, expectation: .transient
        ),
        "com.apple.WebKit.GPU": .init(
            description: "WebKit GPU process. Handles GPU-accelerated rendering for Safari and WebKit-based apps in an isolated process.",
            category: .appleApp, expectation: .transient
        ),

        // ━━ Widget Extensions ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "BatteriesAvocadoWidgetExtension": .init(
            description: "Batteries widget. Displays battery levels for your Mac and connected devices like AirPods and peripherals.",
            category: .appleApp, expectation: .transient
        ),
        "CalendarIntentsExtension": .init(
            description: "Calendar intents extension. Handles Siri intents for calendar operations like creating and querying events.",
            category: .appleApp, expectation: .transient
        ),
        "CalendarWidgetExtension": .init(
            description: "Calendar widget. Displays upcoming calendar events and date information on the desktop and Notification Center.",
            category: .appleApp, expectation: .transient
        ),
        "FindMyWidgetItems": .init(
            description: "Find My Items widget. Shows the location and status of tracked AirTags and Find My-compatible items.",
            category: .appleApp, expectation: .transient
        ),
        "FindMyWidgetPeople": .init(
            description: "Find My People widget. Displays the location of friends and family shared via Find My.",
            category: .appleApp, expectation: .transient
        ),
        "HomeEnergyWidgetsExtension": .init(
            description: "Home Energy widget. Displays energy usage data and grid forecasts from HomeKit-connected devices.",
            category: .appleApp, expectation: .transient
        ),
        "HomeWidget": .init(
            description: "Home widget. Shows HomeKit accessory status and provides quick controls for smart home devices.",
            category: .appleApp, expectation: .transient
        ),
        "JournalWidgets": .init(
            description: "Journal widgets. Displays journaling prompts and recent journal entries on the desktop.",
            category: .appleApp, expectation: .transient
        ),
        "JournalWidgetsSecure": .init(
            description: "Journal Widgets (secure). Renders journal widget content with additional privacy protections.",
            category: .appleApp, expectation: .transient
        ),
        "NewsTag": .init(
            description: "News Tag widget. Displays tagged or saved news articles from Apple News.",
            category: .appleApp, expectation: .transient
        ),
        "NewsToday2": .init(
            description: "News Today widget. Shows today's top news stories and personalized headlines from Apple News.",
            category: .appleApp, expectation: .transient
        ),
        "NewsTodayIntents": .init(
            description: "News Today intents. Handles Siri intents for Apple News queries and topic suggestions.",
            category: .appleApp, expectation: .transient
        ),
        "PhotosReliveWidget": .init(
            description: "Photos Relive widget. Displays photo memories and featured photos from your Photos library.",
            category: .appleApp, expectation: .transient
        ),
        "PodcastsWidget": .init(
            description: "Podcasts widget. Shows recently played and suggested podcast episodes from Apple Podcasts.",
            category: .appleApp, expectation: .transient
        ),
        "RecordWidgetExtension": .init(
            description: "Voice Memos record widget. Provides quick access to start voice recordings from the desktop.",
            category: .appleApp, expectation: .transient
        ),
        "StocksWidget": .init(
            description: "Stocks widget. Displays stock prices, watchlist, and market data from the Stocks app.",
            category: .appleApp, expectation: .transient
        ),
        "VoiceMemosSettingsWidgetExtension": .init(
            description: "Voice Memos settings widget. Displays Voice Memos settings and recent recordings on the desktop.",
            category: .appleApp, expectation: .transient
        ),
        "WeatherIntents": .init(
            description: "Weather intents. Handles Siri intents for weather queries and forecast information.",
            category: .appleApp, expectation: .transient
        ),
        "WeatherWidget": .init(
            description: "Weather widget. Displays current weather conditions and forecasts for configured locations.",
            category: .appleApp, expectation: .transient
        ),
        "WorldClockWidget": .init(
            description: "World Clock widget. Displays the current time in multiple time zones on the desktop.",
            category: .appleApp, expectation: .transient
        ),

        // ━━ Apple Call/Communication Helpers ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "CallHistoryPluginHelper": .init(
            description: "Call History plugin helper. Processes call history data for Spotlight indexing and Siri Suggestions.",
            category: .cloud, expectation: .transient
        ),
        "CallHistorySyncHelper": .init(
            description: "Call History sync helper. Syncs FaceTime and phone call history across devices via iCloud.",
            category: .cloud, expectation: .transient
        ),
        "AppleIDSettings": .init(
            description: "Apple ID Settings. Manages Apple ID account settings, iCloud preferences, and subscription management UI.",
            category: .appleApp, expectation: .transient
        ),
    ]
}
