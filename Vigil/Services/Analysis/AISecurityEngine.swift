import Foundation

/// Runs security detections on parsed AI session logs.
/// Ported from the conscience project's signal detection system.
///
/// Detection categories:
/// - Sensitive file access: AI reading/writing credentials, keys, secrets
/// - Suspicious bash commands: network exfiltration, encoding, credential access
/// - Tokenmaxxing: excessive token consumption patterns
/// - Long sessions: unusually long-running sessions
/// - Agent action concerns: autonomous actions without oversight
enum AISecurityEngine {

    // MARK: - Thresholds

    static let tokensPerFileWarn = 100_000
    static let tokensPerTurnWarn = 20_000
    static let maxSessionHours = 12.0

    // MARK: - Public API

    static func scan(sessions: [AISessionLog]) -> AISecurityScanResult {
        var signals: [AISecuritySignal] = []

        for session in sessions {
            signals.append(contentsOf: detectSensitiveFileAccess(session))
            signals.append(contentsOf: detectSuspiciousBash(session))
            signals.append(contentsOf: detectTokenmaxxing(session))
            signals.append(contentsOf: detectLongSession(session))
            signals.append(contentsOf: detectAgentActionConcerns(session))
        }

        let projects = Set(sessions.map(\.projectPath))

        return AISecurityScanResult(
            scanDate: .now,
            signals: signals.sorted { $0.severity > $1.severity },
            sessions: sessions,
            projectCount: projects.count
        )
    }

    // MARK: - Sensitive File Access

    private static let sensitivePatterns: [(pattern: String, matchType: PatternMatch)] = [
        (".env", .exact),
        (".env.local", .exact),
        (".env.production", .exact),
        ("credentials", .prefix),
        ("credentials.json", .exact),
        ("credentials.yaml", .exact),
        ("id_rsa", .exact),
        ("id_ed25519", .exact),
        ("id_ecdsa", .exact),
        (".pem", .suffix),
        (".key", .suffix),
        (".p12", .suffix),
        (".pfx", .suffix),
        (".jks", .suffix),
        (".keystore", .suffix),
        ("secret", .prefix),
        ("secrets.yaml", .exact),
        ("secrets.json", .exact),
        ("aws_access", .prefix),
        (".aws", .exact),
        ("service_account", .prefix),
        ("serviceAccountKey", .prefix),
        ("password", .prefix),
        ("passwords", .exact),
    ]

    private enum PatternMatch {
        case exact, prefix, suffix
    }

    private static func isSensitivePath(_ path: String) -> Bool {
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

    private static func detectSensitiveFileAccess(_ session: AISessionLog) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        let sensitiveFiles = session.filesTouched.filter { isSensitivePath($0.path) }
        guard !sensitiveFiles.isEmpty else { return [] }

        let writes = sensitiveFiles.filter { $0.action == .write || $0.action == .edit }
        let reads = sensitiveFiles.filter { $0.action == .read }

        if !writes.isEmpty {
            let paths = writes.map(\.path).joined(separator: "\n  ")
            signals.append(AISecuritySignal(
                category: .sensitiveFileAccess,
                severity: .warning,
                title: "AI wrote to sensitive files",
                detail: "AI session modified \(writes.count) sensitive file(s) that may contain credentials or secrets.",
                evidence: paths,
                sessionID: session.id,
                projectPath: session.projectPath
            ))
        }

        if !reads.isEmpty {
            let paths = reads.map(\.path).joined(separator: "\n  ")
            signals.append(AISecuritySignal(
                category: .sensitiveFileAccess,
                severity: .concern,
                title: "AI read sensitive files",
                detail: "AI session accessed \(reads.count) sensitive file(s) that may contain credentials or secrets.",
                evidence: paths,
                sessionID: session.id,
                projectPath: session.projectPath
            ))
        }

        return signals
    }

    // MARK: - Suspicious Bash Commands

    private static func detectSuspiciousBash(_ session: AISessionLog) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        for command in session.bashCommands {
            let lower = command.lowercased()

            // Network exfiltration patterns
            if (lower.contains("curl") || lower.contains("wget")) && lower.contains("|") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash,
                    severity: .warning,
                    title: "Piped network command",
                    detail: "Data piped to/from a network tool — could indicate exfiltration.",
                    evidence: truncateCommand(command),
                    sessionID: session.id,
                    projectPath: session.projectPath
                ))
            }

            if lower.contains("netcat") || lower.contains(" nc ") || lower.hasPrefix("nc ") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash,
                    severity: .warning,
                    title: "Netcat usage",
                    detail: "Netcat can establish arbitrary network connections.",
                    evidence: truncateCommand(command),
                    sessionID: session.id,
                    projectPath: session.projectPath
                ))
            }

            if (lower.contains("scp ") || lower.contains("rsync ")) && lower.contains("@") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash,
                    severity: .warning,
                    title: "Remote file transfer",
                    detail: "File transfer to a remote host detected.",
                    evidence: truncateCommand(command),
                    sessionID: session.id,
                    projectPath: session.projectPath
                ))
            }

            // Encoding/obfuscation
            if lower.contains("base64") && lower.contains("|") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash,
                    severity: .concern,
                    title: "Piped base64 encoding",
                    detail: "Base64 encoding in a pipeline — may be used to obfuscate data.",
                    evidence: truncateCommand(command),
                    sessionID: session.id,
                    projectPath: session.projectPath
                ))
            }

            if lower.contains("openssl enc") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash,
                    severity: .concern,
                    title: "OpenSSL encryption",
                    detail: "OpenSSL encryption command — data may be encrypted before exfiltration.",
                    evidence: truncateCommand(command),
                    sessionID: session.id,
                    projectPath: session.projectPath
                ))
            }

            // Credential directory access
            if lower.contains("/.ssh/") || lower.contains("/.aws/") || lower.contains("/.gnupg/") {
                signals.append(AISecuritySignal(
                    category: .suspiciousBash,
                    severity: .concern,
                    title: "Credential directory access",
                    detail: "Command accessed a directory commonly containing credentials.",
                    evidence: truncateCommand(command),
                    sessionID: session.id,
                    projectPath: session.projectPath
                ))
            }
        }

        return signals
    }

    // MARK: - Tokenmaxxing

    private static func detectTokenmaxxing(_ session: AISessionLog) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        let filesCount = max(Set(session.filesTouched.map(\.path)).count, 1)
        let tokensPerFile = session.tokens.output / filesCount

        if tokensPerFile > tokensPerFileWarn && session.tokens.output > 10_000 {
            signals.append(AISecuritySignal(
                category: .tokenmaxxing,
                severity: .concern,
                title: "High token-to-file ratio",
                detail: "\(formatTokens(session.tokens.output)) output tokens across \(filesCount) file(s) — \(formatTokens(tokensPerFile)) per file.",
                evidence: "Threshold: \(formatTokens(tokensPerFileWarn)) tokens/file",
                sessionID: session.id,
                projectPath: session.projectPath
            ))
        }

        if session.assistantTurns > 0 {
            let tokensPerTurn = session.tokens.output / session.assistantTurns
            if tokensPerTurn > tokensPerTurnWarn {
                signals.append(AISecuritySignal(
                    category: .tokenmaxxing,
                    severity: .info,
                    title: "High tokens per turn",
                    detail: "\(formatTokens(tokensPerTurn)) output tokens per assistant turn over \(session.assistantTurns) turns.",
                    evidence: "Threshold: \(formatTokens(tokensPerTurnWarn)) tokens/turn",
                    sessionID: session.id,
                    projectPath: session.projectPath
                ))
            }
        }

        return signals
    }

    // MARK: - Long Session

    private static func detectLongSession(_ session: AISessionLog) -> [AISecuritySignal] {
        guard let hours = session.durationHours, hours > maxSessionHours else { return [] }

        return [AISecuritySignal(
            category: .longSession,
            severity: .warning,
            title: "Extremely long session",
            detail: "Session ran for \(String(format: "%.1f", hours)) hours.",
            evidence: "Threshold: \(String(format: "%.0f", maxSessionHours)) hours",
            sessionID: session.id,
            projectPath: session.projectPath
        )]
    }

    // MARK: - Agent Action Concerns

    private static func detectAgentActionConcerns(_ session: AISessionLog) -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []

        let totalToolUses = session.toolsUsed.values.reduce(0, +)
        guard totalToolUses > 0 else { return signals }

        // Detect sessions with very high tool use relative to human turns
        if session.humanTurns > 0 {
            let ratio = Double(totalToolUses) / Double(session.humanTurns)
            if ratio > 50 {
                signals.append(AISecuritySignal(
                    category: .agentAction,
                    severity: .concern,
                    title: "High autonomous action rate",
                    detail: "\(totalToolUses) tool uses across \(session.humanTurns) human turn(s) — ratio of \(String(format: "%.0f", ratio)):1.",
                    evidence: "May indicate extended agentic loops with minimal human oversight.",
                    sessionID: session.id,
                    projectPath: session.projectPath
                ))
            } else if ratio > 20 {
                signals.append(AISecuritySignal(
                    category: .agentAction,
                    severity: .info,
                    title: "Elevated autonomous actions",
                    detail: "\(totalToolUses) tool uses across \(session.humanTurns) human turn(s) — ratio of \(String(format: "%.0f", ratio)):1.",
                    evidence: "Moderate level of autonomous tool use per human interaction.",
                    sessionID: session.id,
                    projectPath: session.projectPath
                ))
            }
        }

        // Large number of bash commands in a single session
        if session.bashCommands.count > 50 {
            signals.append(AISecuritySignal(
                category: .agentAction,
                severity: .info,
                title: "Heavy shell usage",
                detail: "\(session.bashCommands.count) bash commands executed in a single session.",
                evidence: "High command volume increases the surface area for unintended actions.",
                sessionID: session.id,
                projectPath: session.projectPath
            ))
        }

        return signals
    }

    // MARK: - Helpers

    private static func truncateCommand(_ command: String, maxLength: Int = 200) -> String {
        if command.count <= maxLength { return command }
        return String(command.prefix(maxLength)) + "..."
    }

    private static func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
