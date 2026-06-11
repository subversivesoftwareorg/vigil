import Foundation
import SQLite3

/// SQLite persistence for Vigil's daily I/O aggregates.
/// Stores Welford stats (count, mean, m2) per process per day,
/// enabling efficient time-windowed queries and cross-window comparison.
final class Database: @unchecked Sendable {

    private var db: OpaquePointer?

    /// Opens (or creates) the database at the standard location.
    /// Pass a custom path for testing.
    init(path: String? = nil) throws {
        let dbPath: String
        if let path {
            dbPath = path
        } else {
            let dir = try Self.appSupportDirectory()
            dbPath = dir.appendingPathComponent("vigil.db").path
        }
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw DatabaseError.openFailed(msg)
        }
        // WAL mode for better concurrent read/write performance
        execute("PRAGMA journal_mode=WAL")
        try createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Schema

    private func createTables() throws {
        let statements = [
            """
            CREATE TABLE IF NOT EXISTS daily_io_stats (
                process_name TEXT NOT NULL,
                date TEXT NOT NULL,
                read_count INTEGER NOT NULL DEFAULT 0,
                read_mean REAL NOT NULL DEFAULT 0,
                read_m2 REAL NOT NULL DEFAULT 0,
                write_count INTEGER NOT NULL DEFAULT 0,
                write_mean REAL NOT NULL DEFAULT 0,
                write_m2 REAL NOT NULL DEFAULT 0,
                PRIMARY KEY (process_name, date)
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_daily_io_date ON daily_io_stats(date)",
            """
            CREATE TABLE IF NOT EXISTS ai_inventory (
                tool_id TEXT PRIMARY KEY,
                display_name TEXT NOT NULL,
                provider TEXT NOT NULL,
                category TEXT NOT NULL,
                first_seen TEXT NOT NULL,
                last_seen TEXT NOT NULL,
                observation_count INTEGER NOT NULL DEFAULT 1,
                highest_confidence INTEGER NOT NULL DEFAULT 0,
                best_basis TEXT NOT NULL DEFAULT 'inferred',
                last_reason TEXT NOT NULL DEFAULT '',
                process_names TEXT NOT NULL DEFAULT ''
            )
            """,
            "CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)",
            "INSERT OR IGNORE INTO schema_version (version) VALUES (1)",
        ]
        for sql in statements {
            guard execute(sql) else {
                throw DatabaseError.schemaFailed
            }
        }
        try migrateSchema()
    }

    private func migrateSchema() throws {
        let version = currentSchemaVersion()

        if version < 2 {
            let statements = [
                """
                CREATE TABLE IF NOT EXISTS ai_security_findings (
                    id TEXT PRIMARY KEY,
                    category TEXT NOT NULL,
                    severity INTEGER NOT NULL,
                    title TEXT NOT NULL,
                    detail TEXT NOT NULL,
                    evidence TEXT NOT NULL DEFAULT '',
                    session_id TEXT,
                    project_path TEXT,
                    detected_at TEXT NOT NULL
                )
                """,
                "CREATE INDEX IF NOT EXISTS idx_security_severity ON ai_security_findings(severity)",
                "CREATE INDEX IF NOT EXISTS idx_security_detected ON ai_security_findings(detected_at)",
                "UPDATE schema_version SET version = 2",
            ]
            for sql in statements {
                guard execute(sql) else { throw DatabaseError.schemaFailed }
            }
        }

        if version < 3 {
            let statements = [
                """
                CREATE TABLE IF NOT EXISTS ai_sessions (
                    id TEXT PRIMARY KEY,
                    tool_id TEXT NOT NULL,
                    project_path TEXT NOT NULL,
                    started_at TEXT,
                    ended_at TEXT,
                    duration_seconds REAL,
                    human_turns INTEGER NOT NULL DEFAULT 0,
                    assistant_turns INTEGER NOT NULL DEFAULT 0,
                    input_tokens INTEGER NOT NULL DEFAULT 0,
                    output_tokens INTEGER NOT NULL DEFAULT 0,
                    cache_creation_tokens INTEGER NOT NULL DEFAULT 0,
                    cache_read_tokens INTEGER NOT NULL DEFAULT 0,
                    models_used TEXT NOT NULL DEFAULT '',
                    git_branch TEXT
                )
                """,
                "CREATE INDEX IF NOT EXISTS idx_sessions_tool ON ai_sessions(tool_id, started_at)",

                """
                CREATE TABLE IF NOT EXISTS ai_tool_uses (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT NOT NULL,
                    tool_name TEXT NOT NULL,
                    count INTEGER NOT NULL DEFAULT 1,
                    FOREIGN KEY (session_id) REFERENCES ai_sessions(id)
                )
                """,
                "CREATE INDEX IF NOT EXISTS idx_tool_uses_session ON ai_tool_uses(session_id)",

                """
                CREATE TABLE IF NOT EXISTS ai_file_accesses (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT NOT NULL,
                    file_path TEXT NOT NULL,
                    action TEXT NOT NULL,
                    tool_id TEXT,
                    timestamp TEXT,
                    FOREIGN KEY (session_id) REFERENCES ai_sessions(id)
                )
                """,
                "CREATE INDEX IF NOT EXISTS idx_file_accesses_session ON ai_file_accesses(session_id)",
                "CREATE INDEX IF NOT EXISTS idx_file_accesses_path ON ai_file_accesses(file_path)",

                """
                CREATE TABLE IF NOT EXISTS ai_commands (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT NOT NULL,
                    command TEXT NOT NULL,
                    timestamp TEXT,
                    FOREIGN KEY (session_id) REFERENCES ai_sessions(id)
                )
                """,
                "CREATE INDEX IF NOT EXISTS idx_commands_session ON ai_commands(session_id)",

                """
                CREATE TABLE IF NOT EXISTS ai_config_snapshots (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    tool_id TEXT NOT NULL,
                    snapshot_date TEXT NOT NULL,
                    config_json TEXT NOT NULL,
                    layers_count INTEGER NOT NULL DEFAULT 0,
                    permissions_hash TEXT
                )
                """,
                "CREATE INDEX IF NOT EXISTS idx_config_tool ON ai_config_snapshots(tool_id, snapshot_date)",

                """
                CREATE TABLE IF NOT EXISTS ai_mcp_servers (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    tool_id TEXT NOT NULL,
                    server_name TEXT NOT NULL,
                    command TEXT,
                    env_vars TEXT,
                    first_seen TEXT NOT NULL,
                    last_seen TEXT NOT NULL
                )
                """,
                "CREATE INDEX IF NOT EXISTS idx_mcp_tool ON ai_mcp_servers(tool_id)",

                """
                CREATE TABLE IF NOT EXISTS ai_risk_signals (
                    id TEXT PRIMARY KEY,
                    category TEXT NOT NULL,
                    severity INTEGER NOT NULL,
                    title TEXT NOT NULL,
                    detail TEXT NOT NULL,
                    evidence TEXT NOT NULL DEFAULT '',
                    tool_id TEXT,
                    session_id TEXT,
                    project_path TEXT,
                    detected_at TEXT NOT NULL,
                    resolved_at TEXT
                )
                """,
                "CREATE INDEX IF NOT EXISTS idx_risk_severity ON ai_risk_signals(severity, detected_at)",
                "CREATE INDEX IF NOT EXISTS idx_risk_tool ON ai_risk_signals(tool_id)",

                // Migrate existing ai_security_findings into ai_risk_signals
                """
                INSERT OR IGNORE INTO ai_risk_signals
                    (id, category, severity, title, detail, evidence, session_id, project_path, detected_at)
                SELECT id, category, severity, title, detail, evidence, session_id, project_path, detected_at
                FROM ai_security_findings
                """,

                "UPDATE schema_version SET version = 3",
            ]
            for sql in statements {
                guard execute(sql) else { throw DatabaseError.schemaFailed }
            }
        }
    }

    private func currentSchemaVersion() -> Int {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "SELECT version FROM schema_version LIMIT 1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
              sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    // MARK: - Write

    /// Upsert a daily aggregate for a process.
    /// If a row already exists for this (process, date), the stats are merged.
    func upsertDailyStats(processName: String, date: String,
                          readStats: RunningStats, writeStats: RunningStats) {
        // Try to load existing row and merge
        if let existing = loadDailyStats(processName: processName, date: date) {
            let mergedRead = RunningStats.merge(existing.readStats, readStats)
            let mergedWrite = RunningStats.merge(existing.writeStats, writeStats)
            let sql = """
            UPDATE daily_io_stats
            SET read_count = ?, read_mean = ?, read_m2 = ?,
                write_count = ?, write_mean = ?, write_m2 = ?
            WHERE process_name = ? AND date = ?
            """
            executeUpdate(sql, bindings: [
                .int(mergedRead.count), .double(mergedRead.mean), .double(mergedRead.m2),
                .int(mergedWrite.count), .double(mergedWrite.mean), .double(mergedWrite.m2),
                .text(processName), .text(date)
            ])
        } else {
            let sql = """
            INSERT INTO daily_io_stats
                (process_name, date, read_count, read_mean, read_m2,
                 write_count, write_mean, write_m2)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """
            executeUpdate(sql, bindings: [
                .text(processName), .text(date),
                .int(readStats.count), .double(readStats.mean), .double(readStats.m2),
                .int(writeStats.count), .double(writeStats.mean), .double(writeStats.m2)
            ])
        }
    }

    // MARK: - Read

    /// Load a single day's stats for a process.
    func loadDailyStats(processName: String, date: String) -> DailyIORecord? {
        let sql = """
        SELECT read_count, read_mean, read_m2, write_count, write_mean, write_m2
        FROM daily_io_stats WHERE process_name = ? AND date = ?
        """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(stmt, 1, processName, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, date, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        return DailyIORecord(
            processName: processName,
            date: date,
            readStats: RunningStats(
                count: Int(sqlite3_column_int(stmt, 0)),
                mean: sqlite3_column_double(stmt, 1),
                m2: sqlite3_column_double(stmt, 2)
            ),
            writeStats: RunningStats(
                count: Int(sqlite3_column_int(stmt, 3)),
                mean: sqlite3_column_double(stmt, 4),
                m2: sqlite3_column_double(stmt, 5)
            )
        )
    }

    /// Load daily stats for a process over a date range.
    func loadStats(processName: String, from startDate: String, to endDate: String) -> [DailyIORecord] {
        let sql = """
        SELECT date, read_count, read_mean, read_m2, write_count, write_mean, write_m2
        FROM daily_io_stats WHERE process_name = ? AND date >= ? AND date <= ?
        ORDER BY date
        """
        return executeQuery(sql, bindings: [.text(processName), .text(startDate), .text(endDate)]) { stmt in
            DailyIORecord(
                processName: processName,
                date: String(cString: sqlite3_column_text(stmt, 0)),
                readStats: RunningStats(
                    count: Int(sqlite3_column_int(stmt, 1)),
                    mean: sqlite3_column_double(stmt, 2),
                    m2: sqlite3_column_double(stmt, 3)
                ),
                writeStats: RunningStats(
                    count: Int(sqlite3_column_int(stmt, 4)),
                    mean: sqlite3_column_double(stmt, 5),
                    m2: sqlite3_column_double(stmt, 6)
                )
            )
        }
    }

    /// Load merged stats for a process over a date range, returning a single combined RunningStats pair.
    func loadMergedStats(processName: String, from startDate: String, to endDate: String) -> (read: RunningStats, write: RunningStats) {
        let records = loadStats(processName: processName, from: startDate, to: endDate)
        let read = RunningStats.mergeAll(records.map(\.readStats))
        let write = RunningStats.mergeAll(records.map(\.writeStats))
        return (read, write)
    }

    /// Returns all distinct process names that have data in the given date range.
    func processNames(from startDate: String, to endDate: String) -> [String] {
        let sql = """
        SELECT DISTINCT process_name FROM daily_io_stats
        WHERE date >= ? AND date <= ? ORDER BY process_name
        """
        return executeQuery(sql, bindings: [.text(startDate), .text(endDate)]) { stmt in
            String(cString: sqlite3_column_text(stmt, 0))
        }
    }

    // MARK: - AI Inventory

    func upsertAIInventory(_ entry: AIInventoryEntry) {
        let firstSeen = Self.dateFormatter.string(from: entry.firstSeen)
        let lastSeen = Self.dateFormatter.string(from: entry.lastSeen)
        let names = entry.processNames.sorted().joined(separator: ",")

        if loadAIInventoryEntry(toolID: entry.toolID) != nil {
            let sql = """
            UPDATE ai_inventory
            SET last_seen = ?, observation_count = ?, highest_confidence = ?,
                best_basis = ?, last_reason = ?, process_names = ?
            WHERE tool_id = ?
            """
            executeUpdate(sql, bindings: [
                .text(lastSeen), .int(entry.observationCount),
                .int(entry.highestConfidence.rawValue), .text(entry.bestBasis.rawValue),
                .text(entry.lastReason), .text(names), .text(entry.toolID)
            ])
        } else {
            let sql = """
            INSERT INTO ai_inventory
                (tool_id, display_name, provider, category, first_seen, last_seen,
                 observation_count, highest_confidence, best_basis, last_reason, process_names)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            executeUpdate(sql, bindings: [
                .text(entry.toolID), .text(entry.displayName), .text(entry.provider),
                .text(entry.category), .text(firstSeen), .text(lastSeen),
                .int(entry.observationCount), .int(entry.highestConfidence.rawValue),
                .text(entry.bestBasis.rawValue), .text(entry.lastReason), .text(names)
            ])
        }
    }

    private func loadAIInventoryEntry(toolID: String) -> AIInventoryEntry? {
        let results = loadAIInventory(where: "tool_id = ?", bindings: [.text(toolID)])
        return results.first
    }

    func loadAllAIInventory() -> [AIInventoryEntry] {
        loadAIInventory(where: "1=1", bindings: [])
    }

    private func loadAIInventory(where clause: String, bindings: [Binding]) -> [AIInventoryEntry] {
        let sql = """
        SELECT tool_id, display_name, provider, category, first_seen, last_seen,
               observation_count, highest_confidence, best_basis, last_reason, process_names
        FROM ai_inventory WHERE \(clause)
        ORDER BY last_seen DESC
        """
        return executeQuery(sql, bindings: bindings) { stmt in
            let firstStr = String(cString: sqlite3_column_text(stmt, 4))
            let lastStr = String(cString: sqlite3_column_text(stmt, 5))
            let namesStr = String(cString: sqlite3_column_text(stmt, 10))
            let names = namesStr.isEmpty ? Set<String>() : Set(namesStr.split(separator: ",").map(String.init))

            return AIInventoryEntry(
                toolID: String(cString: sqlite3_column_text(stmt, 0)),
                displayName: String(cString: sqlite3_column_text(stmt, 1)),
                provider: String(cString: sqlite3_column_text(stmt, 2)),
                category: String(cString: sqlite3_column_text(stmt, 3)),
                firstSeen: Self.dateFormatter.date(from: firstStr) ?? .now,
                lastSeen: Self.dateFormatter.date(from: lastStr) ?? .now,
                observationCount: Int(sqlite3_column_int(stmt, 6)),
                highestConfidence: ConfidenceLevel(rawValue: Int(sqlite3_column_int(stmt, 7))) ?? .low,
                bestBasis: EvidenceBasis(rawValue: String(cString: sqlite3_column_text(stmt, 8))) ?? .inferred,
                lastReason: String(cString: sqlite3_column_text(stmt, 9)),
                processNames: names
            )
        }
    }

    // MARK: - AI Security Findings

    func saveSecurityFindings(_ signals: [AISecuritySignal]) {
        execute("DELETE FROM ai_security_findings")
        for signal in signals {
            let sql = """
            INSERT INTO ai_security_findings
                (id, category, severity, title, detail, evidence, session_id, project_path, detected_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            executeUpdate(sql, bindings: [
                .text(signal.id.uuidString),
                .text(signal.category.rawValue),
                .int(signal.severity.rawValue),
                .text(signal.title),
                .text(signal.detail),
                .text(signal.evidence),
                .text(signal.sessionID ?? ""),
                .text(signal.projectPath ?? ""),
                .text(Self.iso8601Formatter.string(from: signal.detectedAt))
            ])
        }
    }

    func loadSecurityFindings() -> [AISecuritySignal] {
        let sql = """
        SELECT id, category, severity, title, detail, evidence, session_id, project_path, detected_at
        FROM ai_security_findings ORDER BY severity DESC, detected_at DESC
        """
        return executeQuery(sql, bindings: []) { stmt in
            let sessionID = String(cString: sqlite3_column_text(stmt, 6))
            let projectPath = String(cString: sqlite3_column_text(stmt, 7))

            return AISecuritySignal(
                category: SignalCategory(rawValue: String(cString: sqlite3_column_text(stmt, 1))) ?? .suspiciousBash,
                severity: SignalSeverity(rawValue: Int(sqlite3_column_int(stmt, 2))) ?? .info,
                title: String(cString: sqlite3_column_text(stmt, 3)),
                detail: String(cString: sqlite3_column_text(stmt, 4)),
                evidence: String(cString: sqlite3_column_text(stmt, 5)),
                sessionID: sessionID.isEmpty ? nil : sessionID,
                projectPath: projectPath.isEmpty ? nil : projectPath
            )
        }
    }

    // MARK: - AI Sessions

    func upsertSession(_ session: AISessionLog, toolID: String) {
        let startedAt = session.startedAt.map { Self.iso8601Formatter.string(from: $0) }
        let endedAt = session.endedAt.map { Self.iso8601Formatter.string(from: $0) }
        let duration = session.duration
        let models = session.modelsUsed.sorted().joined(separator: ",")

        if loadSession(id: session.id) != nil {
            let sql = """
            UPDATE ai_sessions
            SET ended_at = ?, duration_seconds = ?,
                human_turns = ?, assistant_turns = ?,
                input_tokens = ?, output_tokens = ?,
                cache_creation_tokens = ?, cache_read_tokens = ?,
                models_used = ?, git_branch = ?
            WHERE id = ?
            """
            executeUpdate(sql, bindings: [
                .text(endedAt ?? ""), .double(duration ?? 0),
                .int(session.humanTurns), .int(session.assistantTurns),
                .int(session.tokens.input), .int(session.tokens.output),
                .int(session.tokens.cacheCreation), .int(session.tokens.cacheRead),
                .text(models), .text(session.gitBranch ?? ""),
                .text(session.id)
            ])
        } else {
            let sql = """
            INSERT INTO ai_sessions
                (id, tool_id, project_path, started_at, ended_at, duration_seconds,
                 human_turns, assistant_turns, input_tokens, output_tokens,
                 cache_creation_tokens, cache_read_tokens, models_used, git_branch)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            executeUpdate(sql, bindings: [
                .text(session.id), .text(toolID), .text(session.projectPath),
                .text(startedAt ?? ""), .text(endedAt ?? ""), .double(duration ?? 0),
                .int(session.humanTurns), .int(session.assistantTurns),
                .int(session.tokens.input), .int(session.tokens.output),
                .int(session.tokens.cacheCreation), .int(session.tokens.cacheRead),
                .text(models), .text(session.gitBranch ?? "")
            ])
        }
    }

    func loadSession(id: String) -> AISessionRecord? {
        let sql = """
        SELECT id, tool_id, project_path, started_at, ended_at, duration_seconds,
               human_turns, assistant_turns, input_tokens, output_tokens,
               cache_creation_tokens, cache_read_tokens, models_used, git_branch
        FROM ai_sessions WHERE id = ?
        """
        let results = executeQuery(sql, bindings: [.text(id)]) { stmt in
            Self.mapSessionRow(stmt)
        }
        return results.first
    }

    func loadSessions(toolID: String? = nil, limit: Int = 100) -> [AISessionRecord] {
        let whereClause = toolID != nil ? "WHERE tool_id = ?" : ""
        let bindings: [Binding] = toolID != nil ? [.text(toolID!)] : []
        let sql = """
        SELECT id, tool_id, project_path, started_at, ended_at, duration_seconds,
               human_turns, assistant_turns, input_tokens, output_tokens,
               cache_creation_tokens, cache_read_tokens, models_used, git_branch
        FROM ai_sessions \(whereClause)
        ORDER BY started_at DESC LIMIT ?
        """
        return executeQuery(sql, bindings: bindings + [.int(limit)]) { stmt in
            Self.mapSessionRow(stmt)
        }
    }

    private static func mapSessionRow(_ stmt: OpaquePointer) -> AISessionRecord {
        let startedStr = String(cString: sqlite3_column_text(stmt, 3))
        let endedStr = String(cString: sqlite3_column_text(stmt, 4))
        let modelsStr = String(cString: sqlite3_column_text(stmt, 12))
        let branchStr = String(cString: sqlite3_column_text(stmt, 13))

        return AISessionRecord(
            id: String(cString: sqlite3_column_text(stmt, 0)),
            toolID: String(cString: sqlite3_column_text(stmt, 1)),
            projectPath: String(cString: sqlite3_column_text(stmt, 2)),
            startedAt: startedStr.isEmpty ? nil : iso8601Formatter.date(from: startedStr),
            endedAt: endedStr.isEmpty ? nil : iso8601Formatter.date(from: endedStr),
            durationSeconds: sqlite3_column_double(stmt, 5),
            humanTurns: Int(sqlite3_column_int(stmt, 6)),
            assistantTurns: Int(sqlite3_column_int(stmt, 7)),
            inputTokens: Int(sqlite3_column_int(stmt, 8)),
            outputTokens: Int(sqlite3_column_int(stmt, 9)),
            cacheCreationTokens: Int(sqlite3_column_int(stmt, 10)),
            cacheReadTokens: Int(sqlite3_column_int(stmt, 11)),
            modelsUsed: modelsStr.isEmpty ? [] : Set(modelsStr.split(separator: ",").map(String.init)),
            gitBranch: branchStr.isEmpty ? nil : branchStr
        )
    }

    // MARK: - AI Tool Uses

    func insertToolUses(sessionID: String, toolUses: [String: Int]) {
        let sql = """
        INSERT INTO ai_tool_uses (session_id, tool_name, count) VALUES (?, ?, ?)
        """
        for (name, count) in toolUses {
            executeUpdate(sql, bindings: [.text(sessionID), .text(name), .int(count)])
        }
    }

    func loadToolUses(sessionID: String) -> [String: Int] {
        let sql = "SELECT tool_name, count FROM ai_tool_uses WHERE session_id = ?"
        let rows = executeQuery(sql, bindings: [.text(sessionID)]) { stmt in
            (String(cString: sqlite3_column_text(stmt, 0)), Int(sqlite3_column_int(stmt, 1)))
        }
        return Dictionary(uniqueKeysWithValues: rows)
    }

    // MARK: - AI File Accesses

    func insertFileAccesses(sessionID: String, files: [AIFileTouched], toolID: String? = nil) {
        let sql = """
        INSERT INTO ai_file_accesses (session_id, file_path, action, tool_id) VALUES (?, ?, ?, ?)
        """
        for file in files {
            executeUpdate(sql, bindings: [
                .text(sessionID), .text(file.path),
                .text(file.action.rawValue), .text(toolID ?? "")
            ])
        }
    }

    func loadFileAccesses(sessionID: String) -> [AIFileAccessRecord] {
        let sql = """
        SELECT file_path, action, tool_id FROM ai_file_accesses WHERE session_id = ?
        """
        return executeQuery(sql, bindings: [.text(sessionID)]) { stmt in
            let toolStr = String(cString: sqlite3_column_text(stmt, 2))
            return AIFileAccessRecord(
                filePath: String(cString: sqlite3_column_text(stmt, 0)),
                action: String(cString: sqlite3_column_text(stmt, 1)),
                toolID: toolStr.isEmpty ? nil : toolStr
            )
        }
    }

    // MARK: - AI Commands

    func insertCommands(sessionID: String, commands: [String]) {
        let sql = "INSERT INTO ai_commands (session_id, command) VALUES (?, ?)"
        for command in commands {
            executeUpdate(sql, bindings: [.text(sessionID), .text(command)])
        }
    }

    func loadCommands(sessionID: String) -> [String] {
        let sql = "SELECT command FROM ai_commands WHERE session_id = ? ORDER BY id"
        return executeQuery(sql, bindings: [.text(sessionID)]) { stmt in
            String(cString: sqlite3_column_text(stmt, 0))
        }
    }

    // MARK: - AI Config Snapshots

    func insertConfigSnapshot(toolID: String, configJSON: String, layersCount: Int,
                              permissionsHash: String? = nil) {
        let sql = """
        INSERT INTO ai_config_snapshots
            (tool_id, snapshot_date, config_json, layers_count, permissions_hash)
        VALUES (?, ?, ?, ?, ?)
        """
        executeUpdate(sql, bindings: [
            .text(toolID), .text(Self.dateString()),
            .text(configJSON), .int(layersCount),
            .text(permissionsHash ?? "")
        ])
    }

    func loadLatestConfigSnapshot(toolID: String) -> AIConfigSnapshotRecord? {
        let sql = """
        SELECT tool_id, snapshot_date, config_json, layers_count, permissions_hash
        FROM ai_config_snapshots WHERE tool_id = ?
        ORDER BY snapshot_date DESC LIMIT 1
        """
        return executeQuery(sql, bindings: [.text(toolID)]) { stmt in
            let hashStr = String(cString: sqlite3_column_text(stmt, 4))
            return AIConfigSnapshotRecord(
                toolID: String(cString: sqlite3_column_text(stmt, 0)),
                snapshotDate: String(cString: sqlite3_column_text(stmt, 1)),
                configJSON: String(cString: sqlite3_column_text(stmt, 2)),
                layersCount: Int(sqlite3_column_int(stmt, 3)),
                permissionsHash: hashStr.isEmpty ? nil : hashStr
            )
        }.first
    }

    // MARK: - AI MCP Servers

    func upsertMCPServer(toolID: String, serverName: String, command: String?,
                         envVars: String? = nil) {
        let now = Self.iso8601Formatter.string(from: .now)
        if loadMCPServer(toolID: toolID, serverName: serverName) != nil {
            let sql = """
            UPDATE ai_mcp_servers SET last_seen = ?, command = ?, env_vars = ?
            WHERE tool_id = ? AND server_name = ?
            """
            executeUpdate(sql, bindings: [
                .text(now), .text(command ?? ""), .text(envVars ?? ""),
                .text(toolID), .text(serverName)
            ])
        } else {
            let sql = """
            INSERT INTO ai_mcp_servers
                (tool_id, server_name, command, env_vars, first_seen, last_seen)
            VALUES (?, ?, ?, ?, ?, ?)
            """
            executeUpdate(sql, bindings: [
                .text(toolID), .text(serverName),
                .text(command ?? ""), .text(envVars ?? ""),
                .text(now), .text(now)
            ])
        }
    }

    private func loadMCPServer(toolID: String, serverName: String) -> AIMCPServerRecord? {
        let sql = """
        SELECT tool_id, server_name, command, env_vars, first_seen, last_seen
        FROM ai_mcp_servers WHERE tool_id = ? AND server_name = ?
        """
        return executeQuery(sql, bindings: [.text(toolID), .text(serverName)]) { stmt in
            Self.mapMCPServerRow(stmt)
        }.first
    }

    func loadMCPServers(toolID: String? = nil) -> [AIMCPServerRecord] {
        let whereClause = toolID != nil ? "WHERE tool_id = ?" : ""
        let bindings: [Binding] = toolID != nil ? [.text(toolID!)] : []
        let sql = """
        SELECT tool_id, server_name, command, env_vars, first_seen, last_seen
        FROM ai_mcp_servers \(whereClause) ORDER BY last_seen DESC
        """
        return executeQuery(sql, bindings: bindings) { stmt in
            Self.mapMCPServerRow(stmt)
        }
    }

    private static func mapMCPServerRow(_ stmt: OpaquePointer) -> AIMCPServerRecord {
        let cmdStr = String(cString: sqlite3_column_text(stmt, 2))
        let envStr = String(cString: sqlite3_column_text(stmt, 3))
        return AIMCPServerRecord(
            toolID: String(cString: sqlite3_column_text(stmt, 0)),
            serverName: String(cString: sqlite3_column_text(stmt, 1)),
            command: cmdStr.isEmpty ? nil : cmdStr,
            envVars: envStr.isEmpty ? nil : envStr,
            firstSeen: String(cString: sqlite3_column_text(stmt, 4)),
            lastSeen: String(cString: sqlite3_column_text(stmt, 5))
        )
    }

    // MARK: - AI Risk Signals

    func saveRiskSignals(_ signals: [AISecuritySignal], toolID: String? = nil) {
        for signal in signals {
            let sql = """
            INSERT OR REPLACE INTO ai_risk_signals
                (id, category, severity, title, detail, evidence, tool_id,
                 session_id, project_path, detected_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            executeUpdate(sql, bindings: [
                .text(signal.id.uuidString),
                .text(signal.category.rawValue),
                .int(signal.severity.rawValue),
                .text(signal.title),
                .text(signal.detail),
                .text(signal.evidence),
                .text(toolID ?? ""),
                .text(signal.sessionID ?? ""),
                .text(signal.projectPath ?? ""),
                .text(Self.iso8601Formatter.string(from: signal.detectedAt))
            ])
        }
    }

    func loadRiskSignals(toolID: String? = nil, limit: Int = 200) -> [AIRiskSignalRecord] {
        let whereClause = toolID != nil ? "WHERE tool_id = ?" : ""
        let bindings: [Binding] = toolID != nil ? [.text(toolID!)] : []
        let sql = """
        SELECT id, category, severity, title, detail, evidence, tool_id,
               session_id, project_path, detected_at, resolved_at
        FROM ai_risk_signals \(whereClause)
        ORDER BY severity DESC, detected_at DESC LIMIT ?
        """
        return executeQuery(sql, bindings: bindings + [.int(limit)]) { stmt in
            let toolStr = String(cString: sqlite3_column_text(stmt, 6))
            let sessionStr = String(cString: sqlite3_column_text(stmt, 7))
            let projectStr = String(cString: sqlite3_column_text(stmt, 8))
            let resolvedText = sqlite3_column_text(stmt, 10)
            let resolvedStr = resolvedText != nil ? String(cString: resolvedText!) : nil

            return AIRiskSignalRecord(
                id: String(cString: sqlite3_column_text(stmt, 0)),
                category: String(cString: sqlite3_column_text(stmt, 1)),
                severity: Int(sqlite3_column_int(stmt, 2)),
                title: String(cString: sqlite3_column_text(stmt, 3)),
                detail: String(cString: sqlite3_column_text(stmt, 4)),
                evidence: String(cString: sqlite3_column_text(stmt, 5)),
                toolID: toolStr.isEmpty ? nil : toolStr,
                sessionID: sessionStr.isEmpty ? nil : sessionStr,
                projectPath: projectStr.isEmpty ? nil : projectStr,
                detectedAt: String(cString: sqlite3_column_text(stmt, 9)),
                resolvedAt: resolvedStr?.isEmpty == true ? nil : resolvedStr
            )
        }
    }

    func resolveRiskSignal(id: String) {
        let sql = "UPDATE ai_risk_signals SET resolved_at = ? WHERE id = ?"
        executeUpdate(sql, bindings: [
            .text(Self.iso8601Formatter.string(from: .now)), .text(id)
        ])
    }

    // MARK: - Full Session Persistence

    func persistSession(_ session: AISessionLog, toolID: String) {
        upsertSession(session, toolID: toolID)

        let existingTools = loadToolUses(sessionID: session.id)
        if existingTools.isEmpty && !session.toolsUsed.isEmpty {
            insertToolUses(sessionID: session.id, toolUses: session.toolsUsed)
        }

        let existingFiles = loadFileAccesses(sessionID: session.id)
        if existingFiles.isEmpty && !session.filesTouched.isEmpty {
            insertFileAccesses(sessionID: session.id, files: session.filesTouched, toolID: toolID)
        }

        let existingCommands = loadCommands(sessionID: session.id)
        if existingCommands.isEmpty && !session.bashCommands.isEmpty {
            insertCommands(sessionID: session.id, commands: session.bashCommands)
        }
    }

    // MARK: - Helpers

    private static func appSupportDirectory() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                    appropriateFor: nil, create: true)
        let dir = appSupport.appendingPathComponent("Vigil")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @discardableResult
    private func execute(_ sql: String) -> Bool {
        sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    private enum Binding {
        case text(String)
        case int(Int)
        case double(Double)
    }

    private func executeUpdate(_ sql: String, bindings: [Binding]) {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        bind(stmt: stmt, bindings: bindings)
        sqlite3_step(stmt)
    }

    private func executeQuery<T>(_ sql: String, bindings: [Binding], map: (OpaquePointer) -> T) -> [T] {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        bind(stmt: stmt, bindings: bindings)
        var results: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(map(stmt!))
        }
        return results
    }

    private func bind(stmt: OpaquePointer?, bindings: [Binding]) {
        for (i, binding) in bindings.enumerated() {
            let idx = Int32(i + 1)
            switch binding {
            case .text(let s):
                sqlite3_bind_text(stmt, idx, s, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case .int(let n):
                sqlite3_bind_int(stmt, idx, Int32(n))
            case .double(let d):
                sqlite3_bind_double(stmt, idx, d)
            }
        }
    }
}

// MARK: - Supporting Types

struct DailyIORecord {
    let processName: String
    let date: String
    let readStats: RunningStats
    let writeStats: RunningStats
}

struct AISessionRecord {
    let id: String
    let toolID: String
    let projectPath: String
    let startedAt: Date?
    let endedAt: Date?
    let durationSeconds: Double
    let humanTurns: Int
    let assistantTurns: Int
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let modelsUsed: Set<String>
    let gitBranch: String?
}

struct AIFileAccessRecord {
    let filePath: String
    let action: String
    let toolID: String?
}

struct AIConfigSnapshotRecord {
    let toolID: String
    let snapshotDate: String
    let configJSON: String
    let layersCount: Int
    let permissionsHash: String?
}

struct AIMCPServerRecord {
    let toolID: String
    let serverName: String
    let command: String?
    let envVars: String?
    let firstSeen: String
    let lastSeen: String
}

struct AIRiskSignalRecord {
    let id: String
    let category: String
    let severity: Int
    let title: String
    let detail: String
    let evidence: String
    let toolID: String?
    let sessionID: String?
    let projectPath: String?
    let detectedAt: String
    let resolvedAt: String?
}

enum DatabaseError: Error {
    case openFailed(String)
    case schemaFailed
}

// MARK: - Date Formatting

extension Database {
    /// Standard date format for storage: "2026-05-07"
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    static func dateString(for date: Date = .now) -> String {
        dateFormatter.string(from: date)
    }

    static func dateString(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        return dateFormatter.string(from: date)
    }

    static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
