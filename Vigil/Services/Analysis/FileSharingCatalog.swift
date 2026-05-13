import Foundation

/// Identifies file-sharing and cloud sync processes and file paths.
///
/// Tracks three categories:
/// - Cloud sync: Dropbox, OneDrive, Google Drive, iCloud Drive, Box
/// - Backup: Time Machine, Backblaze, Arq, Carbon Copy Cloner
/// - Transfer: AirDrop, rsync, rclone, Syncthing
enum FileSharingCatalog {

    static let knownProcesses: [FileSharingProcessEntry] = [
        // Cloud sync services
        FileSharingProcessEntry(patterns: ["Dropbox", "dropbox"],
                                displayName: "Dropbox", category: .cloudSync, provider: "Dropbox Inc"),
        FileSharingProcessEntry(patterns: ["OneDrive", "onedrive"],
                                displayName: "OneDrive", category: .cloudSync, provider: "Microsoft"),
        FileSharingProcessEntry(patterns: ["Google Drive", "GoogleDriveFS"],
                                displayName: "Google Drive", category: .cloudSync, provider: "Google"),
        FileSharingProcessEntry(patterns: ["bird", "brigd", "cloudd"],
                                displayName: "iCloud Drive", category: .cloudSync, provider: "Apple"),
        FileSharingProcessEntry(patterns: ["Box Sync", "Box Drive", "com.box"],
                                displayName: "Box", category: .cloudSync, provider: "Box Inc"),
        FileSharingProcessEntry(patterns: ["Creative Cloud", "CCLibrary", "CCXProcess", "CoreSync"],
                                displayName: "Adobe Creative Cloud", category: .cloudSync, provider: "Adobe"),
        FileSharingProcessEntry(patterns: ["Maestral", "maestral"],
                                displayName: "Maestral (Dropbox)", category: .cloudSync, provider: "Open Source"),
        FileSharingProcessEntry(patterns: ["pCloud"],
                                displayName: "pCloud", category: .cloudSync, provider: "pCloud"),
        FileSharingProcessEntry(patterns: ["Tresorit"],
                                displayName: "Tresorit", category: .cloudSync, provider: "Tresorit"),
        FileSharingProcessEntry(patterns: ["Nextcloud"],
                                displayName: "Nextcloud", category: .cloudSync, provider: "Nextcloud"),
        FileSharingProcessEntry(patterns: ["ownCloud", "owncloud"],
                                displayName: "ownCloud", category: .cloudSync, provider: "ownCloud"),
        FileSharingProcessEntry(patterns: ["SharePoint", "sharepoint"],
                                displayName: "SharePoint", category: .cloudSync, provider: "Microsoft"),
        FileSharingProcessEntry(patterns: ["Teams", "com.microsoft.teams"],
                                displayName: "Microsoft Teams", category: .cloudSync, provider: "Microsoft"),
        FileSharingProcessEntry(patterns: ["Slack"],
                                displayName: "Slack", category: .cloudSync, provider: "Salesforce"),

        // Backup services
        FileSharingProcessEntry(patterns: ["backupd", "tmutil", "com.apple.TimeMachine"],
                                displayName: "Time Machine", category: .backup, provider: "Apple"),
        FileSharingProcessEntry(patterns: ["Backblaze", "bztransmit", "bzserv"],
                                displayName: "Backblaze", category: .backup, provider: "Backblaze"),
        FileSharingProcessEntry(patterns: ["Arq", "arqagent"],
                                displayName: "Arq Backup", category: .backup, provider: "Haystack Software"),
        FileSharingProcessEntry(patterns: ["Carbon Copy", "com.bombich"],
                                displayName: "Carbon Copy Cloner", category: .backup, provider: "Bombich Software"),
        FileSharingProcessEntry(patterns: ["SuperDuper"],
                                displayName: "SuperDuper!", category: .backup, provider: "Shirt Pocket"),
        FileSharingProcessEntry(patterns: ["ChronoSync", "chronosync"],
                                displayName: "ChronoSync", category: .backup, provider: "Econ Technologies"),

        // Transfer / sync tools
        FileSharingProcessEntry(patterns: ["AirDrop", "sharingd"],
                                displayName: "AirDrop", category: .transfer, provider: "Apple"),
        FileSharingProcessEntry(patterns: ["rsync"],
                                displayName: "rsync", category: .transfer, provider: "Open Source"),
        FileSharingProcessEntry(patterns: ["rclone"],
                                displayName: "rclone", category: .transfer, provider: "Open Source"),
        FileSharingProcessEntry(patterns: ["syncthing", "Syncthing"],
                                displayName: "Syncthing", category: .transfer, provider: "Open Source"),
        FileSharingProcessEntry(patterns: ["Resilio", "rslsync"],
                                displayName: "Resilio Sync", category: .transfer, provider: "Resilio"),
        FileSharingProcessEntry(patterns: ["scp", "sftp"],
                                displayName: "SCP/SFTP", category: .transfer, provider: "System"),
    ]

    static let pathPatterns: [FileSharingPathPattern] = [
        // Cloud sync directories
        FileSharingPathPattern(pattern: "/Dropbox/", tool: "Dropbox", category: .cloudSync),
        FileSharingPathPattern(pattern: "/OneDrive", tool: "OneDrive", category: .cloudSync),
        FileSharingPathPattern(pattern: "/Google Drive/", tool: "Google Drive", category: .cloudSync),
        FileSharingPathPattern(pattern: "/Library/CloudStorage/", tool: "Cloud Storage", category: .cloudSync),
        FileSharingPathPattern(pattern: "/Library/Mobile Documents/", tool: "iCloud Drive", category: .cloudSync),
        FileSharingPathPattern(pattern: "/Box/", tool: "Box", category: .cloudSync),
        FileSharingPathPattern(pattern: "/Creative Cloud Files/", tool: "Adobe CC", category: .cloudSync),
        FileSharingPathPattern(pattern: "/pCloud Drive/", tool: "pCloud", category: .cloudSync),
        FileSharingPathPattern(pattern: "/Nextcloud/", tool: "Nextcloud", category: .cloudSync),
        FileSharingPathPattern(pattern: "/ownCloud/", tool: "ownCloud", category: .cloudSync),
        FileSharingPathPattern(pattern: "/SharePoint/", tool: "SharePoint", category: .cloudSync),

        // Backup directories
        FileSharingPathPattern(pattern: "/.MobileBackups/", tool: "Time Machine", category: .backup),
        FileSharingPathPattern(pattern: "/Backups.backupdb/", tool: "Time Machine", category: .backup),
        FileSharingPathPattern(pattern: "/Backblaze/", tool: "Backblaze", category: .backup),
        FileSharingPathPattern(pattern: "/Library/Arq/", tool: "Arq Backup", category: .backup),

        // App data sync
        FileSharingPathPattern(pattern: "/com.getdropbox", tool: "Dropbox", category: .cloudSync),
        FileSharingPathPattern(pattern: "/com.microsoft.OneDrive", tool: "OneDrive", category: .cloudSync),
        FileSharingPathPattern(pattern: "/com.google.GoogleDrive", tool: "Google Drive", category: .cloudSync),
    ]

    /// Check if a process name matches any known file sharing process.
    static func match(_ processName: String) -> FileSharingProcessEntry? {
        let lower = processName.lowercased()
        return knownProcesses.first { entry in
            entry.patterns.contains { pattern in
                lower.contains(pattern.lowercased())
            }
        }
    }

    /// Check if a file path matches any known file sharing path pattern.
    static func matchPath(_ path: String) -> FileSharingPathPattern? {
        let lower = path.lowercased()
        return pathPatterns.first { lower.contains($0.pattern.lowercased()) }
    }
}

// MARK: - Data Types

struct FileSharingProcessEntry {
    let patterns: [String]
    let displayName: String
    let category: FileSharingCategory
    let provider: String
}

struct FileSharingPathPattern {
    let pattern: String
    let tool: String
    let category: FileSharingCategory
}

enum FileSharingCategory: String, CaseIterable {
    case cloudSync = "Cloud Sync"
    case backup = "Backup"
    case transfer = "Transfer"

    var systemImage: String {
        switch self {
        case .cloudSync: "icloud"
        case .backup: "clock.arrow.2.circlepath"
        case .transfer: "arrow.left.arrow.right"
        }
    }
}
