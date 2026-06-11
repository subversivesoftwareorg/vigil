import Foundation
import SQLite3

/// Reads macOS privacy grants from the user-level TCC database
/// and scans LaunchAgents for AI tool persistence.
enum MacOSPrivacyReader {

    /// Bundle IDs for known AI tools, keyed by adapter toolID.
    private static let knownBundleIDs: [(toolID: String, displayName: String, bundleIDs: [String])] = [
        ("claude-code", "Claude Code", ["com.anthropic.claude-code"]),
        ("claude-desktop", "Claude Desktop", ["com.anthropic.claudefordesktop"]),
        ("codex-cli", "Codex CLI", ["com.openai.codex"]),
        ("cursor", "Cursor", ["com.todesktop.230313mzl4w4u92"]),
        ("github-copilot", "GitHub Copilot", ["com.github.copilot", "com.microsoft.VSCode"]),
        ("windsurf", "Windsurf", ["com.codeium.windsurf"]),
        ("chatgpt", "ChatGPT", ["com.openai.chat"]),
        ("ollama", "Ollama", ["com.ollama.ollama"]),
        ("lm-studio", "LM Studio", ["com.lmstudio.app"]),
        ("zed", "Zed", ["dev.zed.Zed"]),
    ]

    // MARK: - Public API

    static func readAll() -> [AIPrivacyPosture] {
        let tccGrants = readTCCDatabase()
        let launchAgents = scanLaunchAgents()

        return knownBundleIDs.map { entry in
            var posture = AIPrivacyPosture(
                toolID: entry.toolID,
                displayName: entry.displayName,
                bundleID: entry.bundleIDs.first ?? ""
            )

            for bundleID in entry.bundleIDs {
                if let grants = tccGrants[bundleID] {
                    posture.grants.append(contentsOf: grants)
                }
            }

            for agent in launchAgents {
                for bundleID in entry.bundleIDs {
                    if let agentBundle = agent.bundleID, agentBundle.contains(bundleID) {
                        posture.launchAgents.append(agent)
                    } else if agent.label.lowercased().contains(entry.displayName.lowercased()) {
                        posture.launchAgents.append(agent)
                    }
                }
            }

            return posture
        }.filter { !$0.grants.isEmpty || !$0.launchAgents.isEmpty }
    }

    // MARK: - TCC Database

    private static func readTCCDatabase() -> [String: [PrivacyGrant]] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let dbPath = "\(home)/Library/Application Support/com.apple.TCC/TCC.db"

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return [:]
        }
        defer { sqlite3_close(db) }

        var results: [String: [PrivacyGrant]] = [:]

        let sql = "SELECT service, client, auth_value FROM access"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }

        let serviceSet = Set(PrivacyService.allCases.map(\.rawValue))

        while sqlite3_step(stmt) == SQLITE_ROW {
            let service = String(cString: sqlite3_column_text(stmt, 0))
            let client = String(cString: sqlite3_column_text(stmt, 1))
            let authValue = Int(sqlite3_column_int(stmt, 2))

            guard serviceSet.contains(service),
                  let privacyService = PrivacyService(rawValue: service) else { continue }

            let grant = PrivacyGrant(service: privacyService, granted: authValue == 2)
            results[client, default: []].append(grant)
        }

        return results
    }

    // MARK: - LaunchAgents

    private static func scanLaunchAgents() -> [LaunchAgentEntry] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let agentsPath = "\(home)/Library/LaunchAgents"
        let fm = FileManager.default

        guard let files = try? fm.contentsOfDirectory(atPath: agentsPath) else { return [] }

        return files.filter { $0.hasSuffix(".plist") }.compactMap { file in
            let path = "\(agentsPath)/\(file)"
            guard let data = fm.contents(atPath: path),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                return LaunchAgentEntry(path: path, label: file, bundleID: nil)
            }

            let label = plist["Label"] as? String ?? file
            let bundleID = plist["Label"] as? String

            return LaunchAgentEntry(path: path, label: label, bundleID: bundleID)
        }
    }
}
