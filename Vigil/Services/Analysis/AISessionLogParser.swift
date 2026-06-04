import Foundation

/// Parses Claude Code session logs from ~/.claude/projects/.
/// Each project directory contains .jsonl files (one per session) with
/// user turns, assistant turns, tool_use blocks, token counts, and timestamps.
enum AISessionLogParser {

    private static let claudeProjectsPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return home + "/.claude/projects"
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFallback: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Public API

    /// Parse all Claude Code sessions, optionally filtered to a specific project path.
    static func parseAll(projectFilter: String? = nil) -> [AISessionLog] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: claudeProjectsPath) else { return [] }

        var sessions: [AISessionLog] = []

        guard let projectDirs = try? fm.contentsOfDirectory(atPath: claudeProjectsPath) else {
            return []
        }

        for dirName in projectDirs {
            if let filter = projectFilter {
                let decoded = decodeDirName(dirName)
                guard decoded.localizedCaseInsensitiveContains(filter) else { continue }
            }

            let dirPath = claudeProjectsPath + "/" + dirName
            guard let files = try? fm.contentsOfDirectory(atPath: dirPath) else { continue }

            let projectPath = decodeDirName(dirName)

            for file in files where file.hasSuffix(".jsonl") {
                let sessionID = String(file.dropLast(6)) // remove .jsonl
                let filePath = dirPath + "/" + file
                if let session = parseSession(filePath: filePath, sessionID: sessionID,
                                              projectPath: projectPath) {
                    sessions.append(session)
                }
            }
        }

        return sessions
    }

    /// Decode a Claude Code directory name back to a filesystem path.
    /// e.g. "-Users-mkonda-code-project" → "/Users/mkonda/code/project"
    static func decodeDirName(_ name: String) -> String {
        "/" + name.dropFirst().replacingOccurrences(of: "-", with: "/")
    }

    // MARK: - Session Parsing

    private static func parseSession(filePath: String, sessionID: String,
                                     projectPath: String) -> AISessionLog? {
        guard let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        var session = AISessionLog(id: sessionID, projectPath: projectPath)
        var earliestTimestamp: Date?
        var latestTimestamp: Date?

        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            if let ts = parseTimestamp(obj["timestamp"]) {
                if earliestTimestamp == nil || ts < earliestTimestamp! {
                    earliestTimestamp = ts
                }
                if latestTimestamp == nil || ts > latestTimestamp! {
                    latestTimestamp = ts
                }
            }

            guard let type = obj["type"] as? String else { continue }

            if session.gitBranch == nil, let branch = obj["gitBranch"] as? String {
                session.gitBranch = branch
            }

            switch type {
            case "user":
                session.humanTurns += 1

            case "assistant":
                session.assistantTurns += 1
                parseAssistantEntry(obj, into: &session)

            default:
                break
            }
        }

        session.startedAt = earliestTimestamp
        session.endedAt = latestTimestamp

        guard session.totalTurns > 0 else { return nil }
        return session
    }

    private static func parseAssistantEntry(_ obj: [String: Any], into session: inout AISessionLog) {
        guard let message = obj["message"] as? [String: Any] else { return }

        // Model
        if let model = message["model"] as? String {
            session.modelsUsed.insert(model)
        }

        // Token usage
        if let usage = message["usage"] as? [String: Any] {
            session.tokens.input += usage["input_tokens"] as? Int ?? 0
            session.tokens.output += usage["output_tokens"] as? Int ?? 0
            session.tokens.cacheCreation += usage["cache_creation_input_tokens"] as? Int ?? 0
            session.tokens.cacheRead += usage["cache_read_input_tokens"] as? Int ?? 0
        }

        // Content blocks — look for tool_use
        guard let content = message["content"] as? [[String: Any]] else { return }

        for block in content {
            guard block["type"] as? String == "tool_use",
                  let toolName = block["name"] as? String else { continue }

            session.toolsUsed[toolName, default: 0] += 1

            guard let input = block["input"] as? [String: Any] else { continue }

            switch toolName {
            case "Bash":
                if let command = input["command"] as? String {
                    session.bashCommands.append(command)
                }
            case "Read":
                if let path = input["file_path"] as? String {
                    session.filesTouched.append(AIFileTouched(path: path, action: .read))
                }
            case "Write":
                if let path = input["file_path"] as? String {
                    session.filesTouched.append(AIFileTouched(path: path, action: .write))
                }
            case "Edit":
                if let path = input["file_path"] as? String {
                    session.filesTouched.append(AIFileTouched(path: path, action: .edit))
                }
            default:
                break
            }
        }
    }

    private static func parseTimestamp(_ value: Any?) -> Date? {
        guard let str = value as? String else { return nil }
        return isoFormatter.date(from: str) ?? isoFallback.date(from: str)
    }
}
