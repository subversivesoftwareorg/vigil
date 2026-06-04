import Foundation

/// Reads and summarizes AI agent configuration files to surface what permissions
/// and capabilities each tool has been granted.
///
/// Currently supports:
/// - Claude Code: layered settings.json (global → project)
/// - Extensible for Cursor, Aider, Codex, etc.
enum AISettingsReader {

    /// Discover and summarize all AI tool configurations.
    static func discoverAll() -> [AIToolConfig] {
        var configs: [AIToolConfig] = []

        if let claude = readClaudeSettings() {
            configs.append(claude)
        }
        if let cursor = readCursorSettings() {
            configs.append(cursor)
        }
        if let aider = readAiderSettings() {
            configs.append(aider)
        }

        return configs
    }

    // MARK: - Claude Code

    private static func readClaudeSettings() -> AIToolConfig? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // Global settings layers
        var layers: [(path: String, label: String)] = [
            ("\(home)/.claude/settings.json", "User global"),
            ("\(home)/.claude/settings.local.json", "User local"),
        ]

        // Discover project-level settings from common code directories
        for root in discoverProjectRoots(marker: ".claude/settings.json") {
            let projectName = URL(fileURLWithPath: root).lastPathComponent
            layers.append(("\(root)/.claude/settings.json", "Project: \(projectName)"))
            layers.append(("\(root)/.claude/settings.local.json", "Project local: \(projectName)"))
        }

        var foundLayers: [SettingsLayer] = []
        var mergedAllow: [String] = []
        var mergedDeny: [String] = []
        var mergedAsk: [String] = []
        var envVars: [String: String] = [:]
        var mcpServers: [String] = []
        var hooks = false

        for layer in layers {
            guard let data = FileManager.default.contents(atPath: layer.path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            foundLayers.append(SettingsLayer(path: layer.path, label: layer.label))

            if let perms = json["permissions"] as? [String: Any] {
                if let allow = perms["allow"] as? [String] {
                    mergedAllow.append(contentsOf: allow)
                }
                if let deny = perms["deny"] as? [String] {
                    mergedDeny.append(contentsOf: deny)
                }
                if let ask = perms["ask"] as? [String] {
                    mergedAsk.append(contentsOf: ask)
                }
            }

            if let env = json["env"] as? [String: String] {
                envVars.merge(env) { _, new in new }
            }

            if let servers = json["mcpServers"] as? [String: Any] {
                mcpServers.append(contentsOf: servers.keys)
            }

            if json["hooks"] != nil {
                hooks = true
            }
        }

        guard !foundLayers.isEmpty else { return nil }

        let permissions = categorizePermissions(
            allow: mergedAllow, deny: mergedDeny, ask: mergedAsk
        )

        return AIToolConfig(
            tool: "Claude Code",
            provider: "Anthropic",
            layers: foundLayers,
            permissions: permissions,
            envVarCount: envVars.count,
            mcpServers: mcpServers,
            hasHooks: hooks,
            summary: generateClaudeSummary(permissions: permissions, mcpServers: mcpServers,
                                           envVarCount: envVars.count, hasHooks: hooks)
        )
    }

    // MARK: - Cursor

    private static func readCursorSettings() -> AIToolConfig? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = [
            "\(home)/.cursor/settings.json",
            "\(home)/Library/Application Support/Cursor/User/settings.json",
        ]

        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return AIToolConfig(
                    tool: "Cursor",
                    provider: "Cursor Inc",
                    layers: [SettingsLayer(path: path, label: "User")],
                    permissions: PermissionSummary(
                        allowed: [PermissionGroup(category: "Editor", items: ["Full IDE access"])],
                        denied: [], requiresApproval: []
                    ),
                    envVarCount: 0,
                    mcpServers: [],
                    hasHooks: false,
                    summary: ["Cursor has full access to open projects via its IDE integration."]
                )
            }
        }
        return nil
    }

    // MARK: - Aider

    private static func readAiderSettings() -> AIToolConfig? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var configPaths: [SettingsLayer] = []

        // Global config
        let globalPath = "\(home)/.aider.conf.yml"
        if FileManager.default.fileExists(atPath: globalPath) {
            configPaths.append(SettingsLayer(path: globalPath, label: "User global"))
        }

        // Project-level configs discovered from common code directories
        for root in discoverProjectRoots(marker: ".aider.conf.yml") {
            let projectName = URL(fileURLWithPath: root).lastPathComponent
            configPaths.append(SettingsLayer(path: "\(root)/.aider.conf.yml", label: "Project: \(projectName)"))
        }

        guard !configPaths.isEmpty else { return nil }

        return AIToolConfig(
            tool: "Aider",
            provider: "Open Source",
            layers: configPaths,
            permissions: PermissionSummary(allowed: [], denied: [], requiresApproval: []),
            envVarCount: 0,
            mcpServers: [],
            hasHooks: false,
            summary: ["Aider configuration found across \(configPaths.count) location\(configPaths.count == 1 ? "" : "s")."]
        )
    }

    // MARK: - Project Root Discovery

    /// Scan common code directories for project roots containing a marker file.
    /// Searches 2 levels deep under well-known parent directories.
    private static func discoverProjectRoots(marker: String) -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let commonParents = [
            "\(home)/code", "\(home)/Code",
            "\(home)/Developer", "\(home)/dev",
            "\(home)/projects", "\(home)/Projects",
            "\(home)/src", "\(home)/repos",
            "\(home)/workspace", "\(home)/Workspace",
        ]

        let fm = FileManager.default
        var roots: [String] = []

        for parent in commonParents {
            guard let children = try? fm.contentsOfDirectory(atPath: parent) else { continue }
            for child in children where !child.hasPrefix(".") {
                let projectPath = "\(parent)/\(child)"
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: projectPath, isDirectory: &isDir), isDir.boolValue else { continue }
                if fm.fileExists(atPath: "\(projectPath)/\(marker)") {
                    roots.append(projectPath)
                    continue
                }
                // One level deeper for org/workspace structures (e.g., ~/code/org/repo)
                guard let grandchildren = try? fm.contentsOfDirectory(atPath: projectPath) else { continue }
                for grandchild in grandchildren where !grandchild.hasPrefix(".") {
                    let nestedPath = "\(projectPath)/\(grandchild)"
                    var nestedIsDir: ObjCBool = false
                    guard fm.fileExists(atPath: nestedPath, isDirectory: &nestedIsDir), nestedIsDir.boolValue else { continue }
                    if fm.fileExists(atPath: "\(nestedPath)/\(marker)") {
                        roots.append(nestedPath)
                    }
                }
            }
        }

        return roots
    }

    // MARK: - Permission Categorization

    private static func categorizePermissions(
        allow: [String], deny: [String], ask: [String]
    ) -> PermissionSummary {
        PermissionSummary(
            allowed: groupPermissions(allow),
            denied: groupPermissions(deny),
            requiresApproval: groupPermissions(ask)
        )
    }

    private static func groupPermissions(_ perms: [String]) -> [PermissionGroup] {
        var groups: [String: [String]] = [:]

        for perm in perms {
            if perm.hasPrefix("Bash(") {
                let cmd = String(perm.dropFirst(5).prefix(while: { $0 != ":" && $0 != ")" }))
                groups["Shell Commands", default: []].append(cmd)
            } else if perm.hasPrefix("Read(") {
                let path = String(perm.dropFirst(5).dropLast())
                groups["File Access", default: []].append(path)
            } else if perm.hasPrefix("Write(") || perm == "Edit" || perm == "Write" {
                groups["File Writing", default: []].append(perm)
            } else if perm.hasPrefix("WebFetch") {
                let domain = perm.contains("domain:") ?
                    String(perm.split(separator: ":").last?.dropLast() ?? "") : "any"
                groups["Web Access", default: []].append(domain)
            } else if perm == "WebSearch" {
                groups["Web Access", default: []].append("search")
            } else if perm.hasPrefix("mcp__") {
                let parts = perm.split(separator: "__")
                let server = parts.count > 1 ? String(parts[1]) : perm
                groups["MCP (\(server))", default: []].append(
                    parts.count > 2 ? String(parts[2]) : perm
                )
            } else {
                groups["Other", default: []].append(perm)
            }
        }

        return groups.map { PermissionGroup(category: $0.key, items: $0.value) }
            .sorted { $0.category < $1.category }
    }

    // MARK: - Summary Generation

    private static func generateClaudeSummary(
        permissions: PermissionSummary, mcpServers: [String],
        envVarCount: Int, hasHooks: Bool
    ) -> [String] {
        var summary: [String] = []

        // Allowed capabilities
        let allowedCategories = Set(permissions.allowed.map(\.category))
        let deniedCategories = Set(permissions.denied.map(\.category))

        if allowedCategories.contains("Shell Commands") {
            let cmds = permissions.allowed.first { $0.category == "Shell Commands" }?.items ?? []
            summary.append("Can run \(cmds.count) shell commands automatically (e.g., \(cmds.prefix(3).joined(separator: ", ")))")
        }

        if allowedCategories.contains("Web Access") {
            let domains = permissions.allowed.first { $0.category == "Web Access" }?.items ?? []
            summary.append("Can access \(domains.count) web domains and search the web")
        }

        if !mcpServers.isEmpty {
            summary.append("Connected to \(mcpServers.count) MCP server\(mcpServers.count == 1 ? "" : "s"): \(mcpServers.joined(separator: ", "))")
        }

        // Denied capabilities
        if deniedCategories.contains("Shell Commands") {
            let cmds = permissions.denied.first { $0.category == "Shell Commands" }?.items ?? []
            summary.append("Blocked from: \(cmds.joined(separator: ", "))")
        }

        if deniedCategories.contains("File Access") {
            summary.append("Cannot read sensitive files (SSH keys, credentials, .env)")
        }

        // Approval-required
        let askCategories = Set(permissions.requiresApproval.map(\.category))
        if askCategories.contains("Shell Commands") {
            let cmds = permissions.requiresApproval.first { $0.category == "Shell Commands" }?.items ?? []
            summary.append("Requires approval for: \(cmds.prefix(4).joined(separator: ", "))\(cmds.count > 4 ? ", ..." : "")")
        }

        if hasHooks {
            summary.append("Custom hooks are configured (automated actions on events)")
        }

        if envVarCount > 0 {
            summary.append("\(envVarCount) environment variables configured")
        }

        return summary
    }
}

// MARK: - Data Types

struct AIToolConfig {
    let tool: String
    let provider: String
    let layers: [SettingsLayer]
    let permissions: PermissionSummary
    let envVarCount: Int
    let mcpServers: [String]
    let hasHooks: Bool
    let summary: [String]
}

struct SettingsLayer {
    let path: String
    let label: String
}

struct PermissionSummary {
    let allowed: [PermissionGroup]
    let denied: [PermissionGroup]
    let requiresApproval: [PermissionGroup]

    var totalAllowed: Int { allowed.reduce(0) { $0 + $1.items.count } }
    var totalDenied: Int { denied.reduce(0) { $0 + $1.items.count } }
    var totalAsk: Int { requiresApproval.reduce(0) { $0 + $1.items.count } }
}

struct PermissionGroup {
    let category: String
    let items: [String]
}
