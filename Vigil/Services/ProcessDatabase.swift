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
    ]
}
