import Foundation
import Testing
@testable import Vigil

@Suite("Database")
struct DatabaseTests {

    /// Each test gets its own in-memory database to avoid concurrency issues.
    private func makeDB() throws -> Database {
        try Database(path: ":memory:")
    }

    @Test("database opens and creates tables")
    func openAndCreate() throws {
        let db = try makeDB()
        let names = db.processNames(from: "2026-01-01", to: "2026-12-31")
        #expect(names.isEmpty)
    }

    @Test("upsert and load daily stats")
    func upsertAndLoad() throws {
        let db = try makeDB()
        var readStats = RunningStats()
        readStats.add(100); readStats.add(200)

        var writeStats = RunningStats()
        writeStats.add(50)

        db.upsertDailyStats(processName: "test_process", date: "2026-05-07",
                            readStats: readStats, writeStats: writeStats)

        let loaded = db.loadDailyStats(processName: "test_process", date: "2026-05-07")
        #expect(loaded != nil)
        #expect(loaded!.readStats.count == 2)
        #expect(loaded!.readStats.mean == 150.0)
        #expect(loaded!.writeStats.count == 1)
    }

    @Test("upsert merges with existing data")
    func upsertMerges() throws {
        let db = try makeDB()

        var stats1 = RunningStats()
        stats1.add(100)
        db.upsertDailyStats(processName: "merge_test", date: "2026-05-07",
                            readStats: stats1, writeStats: RunningStats())

        var stats2 = RunningStats()
        stats2.add(200)
        db.upsertDailyStats(processName: "merge_test", date: "2026-05-07",
                            readStats: stats2, writeStats: RunningStats())

        let loaded = db.loadDailyStats(processName: "merge_test", date: "2026-05-07")
        #expect(loaded!.readStats.count == 2)
        #expect(loaded!.readStats.mean == 150.0)
    }

    @Test("loadMergedStats combines across days")
    func mergedAcrossDays() throws {
        let db = try makeDB()

        for day in 1...3 {
            var stats = RunningStats()
            stats.add(Double(day * 100))
            db.upsertDailyStats(processName: "multi_day", date: "2026-05-0\(day)",
                                readStats: stats, writeStats: RunningStats())
        }

        let (read, _) = db.loadMergedStats(processName: "multi_day",
                                            from: "2026-05-01", to: "2026-05-03")
        #expect(read.count == 3)
        #expect(abs(read.mean - 200.0) < 0.001)
    }

    @Test("processNames returns distinct names in range")
    func processNamesInRange() throws {
        let db = try makeDB()

        db.upsertDailyStats(processName: "alpha", date: "2026-05-01",
                            readStats: RunningStats(count: 1, mean: 1, m2: 0), writeStats: RunningStats())
        db.upsertDailyStats(processName: "beta", date: "2026-05-01",
                            readStats: RunningStats(count: 1, mean: 1, m2: 0), writeStats: RunningStats())
        db.upsertDailyStats(processName: "gamma", date: "2026-06-01",
                            readStats: RunningStats(count: 1, mean: 1, m2: 0), writeStats: RunningStats())

        let mayNames = db.processNames(from: "2026-05-01", to: "2026-05-31")
        #expect(mayNames.contains("alpha"))
        #expect(mayNames.contains("beta"))
        #expect(!mayNames.contains("gamma"))
    }
}
