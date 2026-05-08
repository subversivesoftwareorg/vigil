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
            "CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)",
            "INSERT OR IGNORE INTO schema_version (version) VALUES (1)",
        ]
        for sql in statements {
            guard execute(sql) else {
                throw DatabaseError.schemaFailed
            }
        }
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
}
