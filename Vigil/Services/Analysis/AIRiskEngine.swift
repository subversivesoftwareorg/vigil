import Foundation

/// Cross-tool risk detections that operate on config posture, file sharing overlap,
/// and MCP server configurations. Complements per-session detections in each adapter.
enum AIRiskEngine {

    // MARK: - File Sharing Cross-Correlation

    static func detectFileSharingExposure(sessions: [AISessionLog]) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        for session in sessions {
            for file in session.filesTouched {
                guard file.action == .write || file.action == .edit || file.action == .multiEdit else { continue }
                let lower = file.path.lowercased()

                for pattern in FileSharingCatalog.pathPatterns {
                    if lower.contains(pattern.pattern.lowercased()) {
                        let isSensitive = isSensitivePath(file.path)
                        let severity: SignalSeverity = isSensitive ? .warning : .concern

                        signals.append(AISecuritySignal(
                            category: .fileSharingExposure,
                            severity: severity,
                            title: isSensitive
                                ? "AI wrote sensitive file in \(pattern.tool) directory"
                                : "AI wrote file in \(pattern.tool) synced directory",
                            detail: "File \(URL(fileURLWithPath: file.path).lastPathComponent) was \(file.action.rawValue) by an AI session in a \(pattern.tool)-synced directory. This file may be automatically uploaded.",
                            evidence: file.path,
                            sessionID: session.id,
                            projectPath: session.projectPath
                        ))
                        break
                    }
                }
            }
        }

        return signals
    }

    // MARK: - MCP Risk Detection

    static func detectMCPRisks(configs: [AIToolConfig]) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        for config in configs {
            for server in config.mcpServerDetails {
                // Auto-approved tools
                if !server.autoApprovedTools.isEmpty {
                    signals.append(AISecuritySignal(
                        category: .mcpRisk,
                        severity: .concern,
                        title: "MCP server has auto-approved tools",
                        detail: "\(server.name) in \(config.tool) has \(server.autoApprovedTools.count) auto-approved tool(s): \(server.autoApprovedTools.prefix(5).joined(separator: ", ")). These execute without user confirmation.",
                        evidence: "Source: \(server.source)"
                    ))
                }

                // Broad env var passthrough
                let riskyEnvVars = server.envVars.keys.filter { key in
                    let k = key.uppercased()
                    return k == "PATH" || k == "HOME" || k.hasPrefix("AWS_")
                        || k.hasPrefix("GOOGLE_") || k.hasPrefix("AZURE_")
                        || k == "GITHUB_TOKEN" || k == "NPM_TOKEN"
                        || k == "OPENAI_API_KEY" || k == "ANTHROPIC_API_KEY"
                }
                if !riskyEnvVars.isEmpty {
                    signals.append(AISecuritySignal(
                        category: .mcpRisk,
                        severity: .concern,
                        title: "MCP server receives sensitive env vars",
                        detail: "\(server.name) in \(config.tool) receives \(riskyEnvVars.count) sensitive environment variable(s).",
                        evidence: riskyEnvVars.joined(separator: ", ")
                    ))
                }

                // Unpinned npm/pip packages in startup command
                if let command = server.command {
                    if command.contains("npx ") && !command.contains("@") {
                        signals.append(AISecuritySignal(
                            category: .mcpRisk,
                            severity: .warning,
                            title: "MCP server uses unpinned npx package",
                            detail: "\(server.name) in \(config.tool) starts with an unpinned npx command. This could execute arbitrary code if the package is compromised.",
                            evidence: command
                        ))
                    }
                    if command.contains("uvx ") || command.contains("pipx run ") {
                        if !command.contains("==") {
                            signals.append(AISecuritySignal(
                                category: .mcpRisk,
                                severity: .concern,
                                title: "MCP server uses unpinned Python package",
                                detail: "\(server.name) in \(config.tool) starts with an unpinned Python package runner.",
                                evidence: command
                            ))
                        }
                    }
                }
            }
        }

        return signals
    }

    // MARK: - Excessive Agency Detection (Config-Based)

    static func detectExcessiveAgency(configs: [AIToolConfig]) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        for config in configs {
            if config.autoMode {
                signals.append(AISecuritySignal(
                    category: .excessiveAgency,
                    severity: .concern,
                    title: "\(config.tool) has broad auto-approval",
                    detail: "Configuration grants extensive automatic permissions, reducing human oversight over tool actions.",
                    evidence: "Allowed: \(config.permissions.totalAllowed) items, Denied: \(config.permissions.totalDenied) items"
                ))
            }

            // Network access without approval
            if let networkAccess = config.networkAccess, networkAccess {
                signals.append(AISecuritySignal(
                    category: .excessiveAgency,
                    severity: .info,
                    title: "\(config.tool) has network access enabled",
                    detail: "The tool can make outbound network requests.",
                    evidence: "Network access: enabled"
                ))
            }
        }

        return signals
    }

    // MARK: - Privacy Posture Risk Detection

    static func detectPrivacyRisks(postures: [AIPrivacyPosture]) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        for posture in postures {
            let elevated = posture.grants.filter { $0.granted && $0.service.isElevated }
            for grant in elevated {
                signals.append(AISecuritySignal(
                    category: .excessiveAgency,
                    severity: .warning,
                    title: "\(posture.displayName) has \(grant.service.displayName)",
                    detail: "\(posture.displayName) has been granted \(grant.service.displayName) access. Combined with AI agent capabilities, this significantly increases blast radius.",
                    evidence: "Bundle: \(posture.bundleID), Service: \(grant.service.rawValue)"
                ))
            }

            if !posture.launchAgents.isEmpty {
                let labels = posture.launchAgents.map(\.label).joined(separator: ", ")
                signals.append(AISecuritySignal(
                    category: .excessiveAgency,
                    severity: .info,
                    title: "\(posture.displayName) has LaunchAgent persistence",
                    detail: "\(posture.launchAgents.count) LaunchAgent(s) found for \(posture.displayName). These run at login without explicit user action.",
                    evidence: labels
                ))
            }
        }

        return signals
    }

    // MARK: - Shared Helpers

    private static let sensitivePatterns: [(pattern: String, matchType: PatternMatch)] = [
        (".env", .exact), (".env.local", .exact), (".env.production", .exact),
        (".env.development", .exact), (".env.staging", .exact),
        ("credentials", .prefix), ("credentials.json", .exact), ("credentials.yaml", .exact),
        ("id_rsa", .exact), ("id_ed25519", .exact), ("id_ecdsa", .exact),
        ("id_dsa", .exact), ("authorized_keys", .exact), ("known_hosts", .exact),
        (".pem", .suffix), (".key", .suffix), (".p12", .suffix), (".pfx", .suffix),
        (".jks", .suffix), (".keystore", .suffix), (".crt", .suffix),
        ("secret", .prefix), ("secrets.yaml", .exact), ("secrets.json", .exact),
        ("aws_access", .prefix), (".aws", .exact),
        ("service_account", .prefix), ("serviceAccountKey", .prefix),
        ("password", .prefix), ("passwords", .exact),
        ("kubeconfig", .exact), (".kube", .exact),
        (".npmrc", .exact), (".pypirc", .exact), (".netrc", .exact),
        (".tfstate", .suffix), ("terraform.tfvars", .exact),
        ("pulumi.yaml", .exact), ("Pulumi.yaml", .exact),
        (".gnupg", .exact), (".gpg", .suffix),
        (".sops.yaml", .exact), ("sops.yaml", .exact),
        (".docker/config.json", .exact), ("docker-compose.override", .prefix),
        ("token", .exact), ("tokens.json", .exact), (".token", .exact),
    ]

    private enum PatternMatch {
        case exact, prefix, suffix
    }

    static func isSensitivePath(_ path: String) -> Bool {
        let filename = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        for (pattern, matchType) in sensitivePatterns {
            let p = pattern.lowercased()
            switch matchType {
            case .exact:
                if filename == p { return true }
            case .prefix:
                if filename.hasPrefix(p) { return true }
            case .suffix:
                if filename.hasSuffix(p) { return true }
            }
        }
        return false
    }
}
