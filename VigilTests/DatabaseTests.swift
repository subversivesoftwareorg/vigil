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

    // MARK: - AI Inventory

    @Test("AI inventory upsert and load round-trips correctly")
    func aiInventoryRoundTrip() throws {
        let db = try makeDB()

        let entry = AIInventoryEntry(
            toolID: "claude-code",
            displayName: "Claude Code",
            provider: "Anthropic",
            category: "Coding Assistant",
            firstSeen: Date(timeIntervalSinceReferenceDate: 800_000_000),
            lastSeen: Date(timeIntervalSinceReferenceDate: 800_000_000),
            observationCount: 42,
            highestConfidence: .high,
            bestBasis: .observed,
            lastReason: "Exact process name match",
            processNames: ["claude", "claude-code"]
        )

        db.upsertAIInventory(entry)
        let loaded = db.loadAllAIInventory()
        #expect(loaded.count == 1)
        #expect(loaded.first?.toolID == "claude-code")
        #expect(loaded.first?.displayName == "Claude Code")
        #expect(loaded.first?.observationCount == 42)
        #expect(loaded.first?.highestConfidence == .high)
        #expect(loaded.first?.bestBasis == .observed)
        #expect(loaded.first?.processNames.contains("claude") == true)
        #expect(loaded.first?.processNames.contains("claude-code") == true)
    }

    @Test("AI inventory upsert updates existing entry")
    func aiInventoryUpdate() throws {
        let db = try makeDB()

        var entry = AIInventoryEntry(
            toolID: "ollama",
            displayName: "Ollama",
            provider: "Local",
            category: "Local Model Runner",
            firstSeen: Date(timeIntervalSinceReferenceDate: 800_000_000),
            lastSeen: Date(timeIntervalSinceReferenceDate: 800_000_000),
            observationCount: 10,
            highestConfidence: .medium,
            bestBasis: .inferred,
            lastReason: "Path match",
            processNames: ["ollama"]
        )
        db.upsertAIInventory(entry)

        entry.observationCount = 25
        entry.highestConfidence = .high
        entry.bestBasis = .observed
        entry.processNames.insert("ollama-runner")
        db.upsertAIInventory(entry)

        let loaded = db.loadAllAIInventory()
        #expect(loaded.count == 1)
        #expect(loaded.first?.observationCount == 25)
        #expect(loaded.first?.highestConfidence == .high)
        #expect(loaded.first?.bestBasis == .observed)
        #expect(loaded.first?.processNames.count == 2)
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

    // MARK: - AI Sessions (v3)

    @Test("session upsert and load round-trips correctly")
    func sessionRoundTrip() throws {
        let db = try makeDB()
        let session = AISessionLog(
            id: "test-session-1",
            projectPath: "/Users/dev/myproject",
            startedAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
            endedAt: Date(timeIntervalSinceReferenceDate: 800_003_600),
            humanTurns: 5,
            assistantTurns: 8,
            tokens: AITokenUsage(input: 10_000, output: 5_000, cacheCreation: 1_000, cacheRead: 2_000),
            modelsUsed: ["claude-sonnet-4-6"],
            toolsUsed: ["Bash": 3, "Read": 5],
            filesTouched: [
                AIFileTouched(path: "/src/main.swift", action: .read),
                AIFileTouched(path: "/src/app.swift", action: .edit)
            ],
            bashCommands: ["swift build", "swift test"],
            gitBranch: "feature/adapters"
        )

        db.upsertSession(session, toolID: "claude-code")
        let loaded = db.loadSession(id: "test-session-1")
        #expect(loaded != nil)
        #expect(loaded?.toolID == "claude-code")
        #expect(loaded?.projectPath == "/Users/dev/myproject")
        #expect(loaded?.humanTurns == 5)
        #expect(loaded?.assistantTurns == 8)
        #expect(loaded?.inputTokens == 10_000)
        #expect(loaded?.outputTokens == 5_000)
        #expect(loaded?.modelsUsed.contains("claude-sonnet-4-6") == true)
        #expect(loaded?.gitBranch == "feature/adapters")
    }

    @Test("session upsert updates existing session")
    func sessionUpdate() throws {
        let db = try makeDB()
        var session = AISessionLog(id: "update-test", projectPath: "/project")
        session.humanTurns = 2
        session.assistantTurns = 3

        db.upsertSession(session, toolID: "claude-code")

        session.humanTurns = 5
        session.assistantTurns = 10
        db.upsertSession(session, toolID: "claude-code")

        let loaded = db.loadSession(id: "update-test")
        #expect(loaded?.humanTurns == 5)
        #expect(loaded?.assistantTurns == 10)
    }

    @Test("loadSessions filters by tool ID")
    func sessionFilterByTool() throws {
        let db = try makeDB()

        var s1 = AISessionLog(id: "s1", projectPath: "/p1")
        s1.humanTurns = 1
        db.upsertSession(s1, toolID: "claude-code")

        var s2 = AISessionLog(id: "s2", projectPath: "/p2")
        s2.humanTurns = 1
        db.upsertSession(s2, toolID: "codex-cli")

        let claudeSessions = db.loadSessions(toolID: "claude-code")
        #expect(claudeSessions.count == 1)
        #expect(claudeSessions.first?.id == "s1")

        let allSessions = db.loadSessions()
        #expect(allSessions.count == 2)
    }

    // MARK: - AI Tool Uses (v3)

    @Test("tool uses insert and load round-trip")
    func toolUsesRoundTrip() throws {
        let db = try makeDB()
        var session = AISessionLog(id: "tu-test", projectPath: "/p")
        session.humanTurns = 1
        db.upsertSession(session, toolID: "claude-code")

        db.insertToolUses(sessionID: "tu-test", toolUses: ["Bash": 10, "Read": 25, "Edit": 3])
        let loaded = db.loadToolUses(sessionID: "tu-test")
        #expect(loaded["Bash"] == 10)
        #expect(loaded["Read"] == 25)
        #expect(loaded["Edit"] == 3)
    }

    // MARK: - AI File Accesses (v3)

    @Test("file accesses insert and load round-trip")
    func fileAccessesRoundTrip() throws {
        let db = try makeDB()
        var session = AISessionLog(id: "fa-test", projectPath: "/p")
        session.humanTurns = 1
        db.upsertSession(session, toolID: "claude-code")

        let files = [
            AIFileTouched(path: "/src/main.swift", action: .read),
            AIFileTouched(path: "/src/app.swift", action: .write),
            AIFileTouched(path: "/README.md", action: .edit),
        ]
        db.insertFileAccesses(sessionID: "fa-test", files: files, toolID: "claude-code")
        let loaded = db.loadFileAccesses(sessionID: "fa-test")
        #expect(loaded.count == 3)
        #expect(loaded.contains { $0.filePath == "/src/main.swift" && $0.action == "read" })
        #expect(loaded.contains { $0.filePath == "/src/app.swift" && $0.action == "write" })
    }

    // MARK: - AI Commands (v3)

    @Test("commands insert and load round-trip")
    func commandsRoundTrip() throws {
        let db = try makeDB()
        var session = AISessionLog(id: "cmd-test", projectPath: "/p")
        session.humanTurns = 1
        db.upsertSession(session, toolID: "claude-code")

        db.insertCommands(sessionID: "cmd-test", commands: ["swift build", "swift test", "git status"])
        let loaded = db.loadCommands(sessionID: "cmd-test")
        #expect(loaded.count == 3)
        #expect(loaded[0] == "swift build")
        #expect(loaded[2] == "git status")
    }

    // MARK: - AI MCP Servers (v3)

    @Test("MCP server upsert and load round-trip")
    func mcpServerRoundTrip() throws {
        let db = try makeDB()

        db.upsertMCPServer(toolID: "claude-code", serverName: "filesystem",
                           command: "npx @anthropic/mcp-fs", envVars: "HOME=/Users/dev")
        let loaded = db.loadMCPServers(toolID: "claude-code")
        #expect(loaded.count == 1)
        #expect(loaded.first?.serverName == "filesystem")
        #expect(loaded.first?.command == "npx @anthropic/mcp-fs")
    }

    @Test("MCP server upsert updates last_seen")
    func mcpServerUpdate() throws {
        let db = try makeDB()

        db.upsertMCPServer(toolID: "claude-code", serverName: "github", command: "npx mcp-github")
        let first = db.loadMCPServers(toolID: "claude-code").first
        #expect(first != nil)

        db.upsertMCPServer(toolID: "claude-code", serverName: "github", command: "npx mcp-github@2")
        let updated = db.loadMCPServers(toolID: "claude-code").first
        #expect(updated?.command == "npx mcp-github@2")
    }

    // MARK: - AI Risk Signals (v3)

    @Test("risk signals insert and load round-trip")
    func riskSignalsRoundTrip() throws {
        let db = try makeDB()

        let signal = AISecuritySignal(
            category: .sensitiveFileAccess,
            severity: .warning,
            title: "AI wrote to .env",
            detail: "Sensitive file modified",
            evidence: "/project/.env",
            sessionID: "sess-1",
            projectPath: "/project"
        )
        db.saveRiskSignals([signal], toolID: "claude-code")

        let loaded = db.loadRiskSignals()
        #expect(loaded.count == 1)
        #expect(loaded.first?.title == "AI wrote to .env")
        #expect(loaded.first?.toolID == "claude-code")
        #expect(loaded.first?.resolvedAt == nil)
    }

    @Test("risk signal can be resolved")
    func riskSignalResolve() throws {
        let db = try makeDB()

        let signal = AISecuritySignal(
            category: .suspiciousBash,
            severity: .concern,
            title: "Piped curl",
            detail: "Suspicious",
            evidence: "curl | sh",
            sessionID: nil,
            projectPath: nil
        )
        db.saveRiskSignals([signal])

        let before = db.loadRiskSignals()
        #expect(before.first?.resolvedAt == nil)

        db.resolveRiskSignal(id: before.first!.id)
        let after = db.loadRiskSignals()
        #expect(after.first?.resolvedAt != nil)
    }

    // MARK: - Full Session Persistence (v3)

    @Test("persistSession stores session with tool uses, files, and commands")
    func fullSessionPersistence() throws {
        let db = try makeDB()

        var session = AISessionLog(id: "full-test", projectPath: "/project")
        session.humanTurns = 3
        session.assistantTurns = 5
        session.toolsUsed = ["Bash": 4, "Read": 7]
        session.filesTouched = [
            AIFileTouched(path: "/src/main.swift", action: .read),
            AIFileTouched(path: "/src/app.swift", action: .edit),
        ]
        session.bashCommands = ["swift build", "swift test"]

        db.persistSession(session, toolID: "claude-code")

        #expect(db.loadSession(id: "full-test") != nil)
        #expect(db.loadToolUses(sessionID: "full-test")["Bash"] == 4)
        #expect(db.loadFileAccesses(sessionID: "full-test").count == 2)
        #expect(db.loadCommands(sessionID: "full-test").count == 2)
    }

    @Test("persistSession is idempotent for child records")
    func persistSessionIdempotent() throws {
        let db = try makeDB()

        var session = AISessionLog(id: "idem-test", projectPath: "/project")
        session.humanTurns = 2
        session.toolsUsed = ["Bash": 3]
        session.bashCommands = ["git status"]

        db.persistSession(session, toolID: "claude-code")
        db.persistSession(session, toolID: "claude-code")

        #expect(db.loadCommands(sessionID: "idem-test").count == 1)
        #expect(db.loadToolUses(sessionID: "idem-test")["Bash"] == 3)
    }
}
