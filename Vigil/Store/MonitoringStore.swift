import Foundation

/// Central state store for all monitoring data.
/// Subscribes to monitor streams and aggregates snapshots for the UI.
@Observable @MainActor
final class MonitoringStore {

    // MARK: - State

    private(set) var processes: [ProcessSnapshot] = []
    private(set) var fileEvents: [FileEvent] = []
    private(set) var ioRates: [Int32: ProcessIORate] = [:]
    private(set) var isMonitoring = false

    /// The baseline tracker for building "normal" I/O profiles per process.
    let ioBaseline = IOBaseline()

    /// Cached heuristics analysis — recomputed each process snapshot so all views
    /// see the same health score and findings.
    private(set) var latestAnalysis: HeuristicsResult?

    /// Database for persistent storage of daily I/O aggregates.
    private(set) var database: Database?

    /// Persistent catalog of AI tools observed on this system.
    private(set) var aiInventory: [String: AIInventoryEntry] = [:]
    private var dirtyInventoryEntries: Set<String> = []

    /// Latest AI security scan result.
    private(set) var securityScanResult: AISecurityScanResult?
    private(set) var isScanningSecurity = false

    // MARK: - Monitors

    private var processSource: (any ProcessDataSource)?
    private var fileSource: (any FileEventSource)?
    private var monitoringTasks: [Task<Void, Never>] = []

    /// Previous snapshot keyed by PID, used to compute I/O deltas.
    private var previousSnapshots: [Int32: ProcessSnapshot] = [:]

    /// Accumulates I/O profiles for the current day, flushed to SQLite periodically.
    private var pendingDailyStats: [String: ProcessIOProfile] = [:]
    private var lastFlush: Date = .now

    /// How often to flush accumulated stats to SQLite.
    private static let flushInterval: TimeInterval = 60

    // MARK: - Configuration

    func configure(processSource: any ProcessDataSource, fileSource: any FileEventSource,
                   database: Database? = nil) {
        self.processSource = processSource
        self.fileSource = fileSource
        self.database = database
    }

    // MARK: - Lifecycle

    func startMonitoring() async {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Load persisted AI inventory and security findings
        if let database {
            let entries = database.loadAllAIInventory()
            for entry in entries {
                aiInventory[entry.toolID] = entry
            }
            loadPersistedSecurityFindings()
        }

        if let source = processSource {
            try? await source.start()
            let task = Task { [weak self] in
                for await snapshot in source.processes {
                    self?.handleProcessSnapshot(snapshot)
                }
            }
            monitoringTasks.append(task)
        }

        if let source = fileSource {
            try? await source.start()
            let task = Task { [weak self] in
                for await batch in source.events {
                    self?.handleFileEventBatch(batch)
                }
            }
            monitoringTasks.append(task)
        }
    }

    func stopMonitoring() async {
        isMonitoring = false
        monitoringTasks.forEach { $0.cancel() }
        monitoringTasks.removeAll()
        await processSource?.stop()
        await fileSource?.stop()

        // Final flush before stopping
        flushDailyStats()
        flushAIInventory()
    }

    // MARK: - I/O Rate Computation

    private func handleProcessSnapshot(_ snapshot: [ProcessSnapshot]) {
        var newRates: [Int32: ProcessIORate] = [:]

        for process in snapshot {
            if let previous = previousSnapshots[process.pid],
               let rate = ProcessIORate.from(previous: previous, current: process) {
                newRates[process.pid] = rate

                // Feed into the live baseline tracker
                ioBaseline.record(rate)

                // Accumulate for daily persistence
                accumulateDailyStat(rate)
            }
        }

        // Update state
        processes = snapshot
        ioRates = newRates
        previousSnapshots = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.pid, $0) })

        // Record AI process observations for the inventory
        for process in snapshot {
            if let match = AIProcessCatalog.match(process.displayName) {
                recordAIObservation(
                    toolID: AIInventoryEntry.toolID(from: match.entry.displayName),
                    displayName: match.entry.displayName,
                    provider: match.entry.provider,
                    category: match.entry.category.rawValue,
                    evidence: match.evidence,
                    processName: process.displayName
                )
            }
        }

        // Recompute heuristics so all views share the same result
        let engine = HeuristicsEngine(processes: processes, ioRates: ioRates, baseline: ioBaseline)
        latestAnalysis = engine.analyze()

        // Periodic flush to SQLite
        if Date.now.timeIntervalSince(lastFlush) >= Self.flushInterval {
            flushDailyStats()
            flushAIInventory()
        }
    }

    // MARK: - File Event Handling

    private func handleFileEventBatch(_ batch: [FileEvent]) {
        fileEvents.append(contentsOf: batch)
        if fileEvents.count > 10_000 {
            fileEvents = Array(fileEvents.suffix(5_000))
        }

        // Record AI path observations (deduplicate per tool per batch)
        var seen = Set<String>()
        for event in batch {
            if let match = AIProcessCatalog.matchPath(event.path) {
                let id = AIInventoryEntry.toolID(from: match.pattern.tool)
                if seen.insert(id).inserted {
                    recordAIObservation(
                        toolID: id,
                        displayName: match.pattern.tool,
                        provider: "",
                        category: match.pattern.category.rawValue,
                        evidence: match.evidence
                    )
                }
            }
        }
    }

    // MARK: - AI Inventory

    private func recordAIObservation(toolID: String, displayName: String, provider: String,
                                      category: String, evidence: AIEvidence,
                                      processName: String? = nil) {
        if var existing = aiInventory[toolID] {
            existing.lastSeen = .now
            existing.observationCount += 1
            if evidence.confidence > existing.highestConfidence {
                existing.highestConfidence = evidence.confidence
            }
            if evidence.basis.rank > existing.bestBasis.rank {
                existing.bestBasis = evidence.basis
            }
            existing.lastReason = evidence.reason
            if let processName { existing.processNames.insert(processName) }
            aiInventory[toolID] = existing
        } else {
            var names = Set<String>()
            if let processName { names.insert(processName) }
            aiInventory[toolID] = AIInventoryEntry(
                toolID: toolID,
                displayName: displayName,
                provider: provider,
                category: category,
                firstSeen: .now,
                lastSeen: .now,
                observationCount: 1,
                highestConfidence: evidence.confidence,
                bestBasis: evidence.basis,
                lastReason: evidence.reason,
                processNames: names
            )
        }
        dirtyInventoryEntries.insert(toolID)
    }

    /// Record a tool as configured when settings files are discovered.
    func recordConfiguredTool(_ config: AIToolConfig) {
        let toolID = AIInventoryEntry.toolID(from: config.tool)
        let evidence = AIEvidence(
            basis: .configured,
            confidence: .high,
            reason: "Configuration found: \(config.layers.map(\.label).joined(separator: ", "))"
        )
        recordAIObservation(
            toolID: toolID,
            displayName: config.tool,
            provider: config.provider,
            category: "Configured",
            evidence: evidence
        )
    }

    private func flushAIInventory() {
        guard let database, !dirtyInventoryEntries.isEmpty else { return }
        let toFlush = dirtyInventoryEntries
        dirtyInventoryEntries.removeAll()

        for toolID in toFlush {
            if let entry = aiInventory[toolID] {
                database.upsertAIInventory(entry)
            }
        }
    }

    // MARK: - AI Security Scanning

    /// Run a security scan on all AI session logs across all adapters.
    /// Also persists parsed sessions, config snapshots, and MCP server tracking.
    func runSecurityScan() {
        isScanningSecurity = true

        // Parse sessions from all adapters
        let sessions = AIAdapterRegistry.parseAllSessions()

        if let database {
            // Persist parsed sessions to the timeline database
            for adapter in AIAdapterRegistry.adapters {
                let adapterSessions = adapter.parseSessions(projectFilter: nil)
                for session in adapterSessions {
                    database.persistSession(session, toolID: adapter.toolID)
                }
            }

            // Snapshot configs and track MCP servers
            let configs = AIAdapterRegistry.discoverAllConfigs()
            for config in configs {
                let toolID = AIInventoryEntry.toolID(from: config.tool)
                recordConfiguredTool(config)

                // Config snapshot: serialize key fields to JSON for drift detection
                let snapshot = configSnapshotJSON(config)
                let hash = permissionsHash(config.permissions)
                database.insertConfigSnapshot(
                    toolID: toolID,
                    configJSON: snapshot,
                    layersCount: config.layers.count,
                    permissionsHash: hash
                )

                // MCP server tracking
                for server in config.mcpServerDetails {
                    let envSummary = server.envVars.keys.sorted().joined(separator: ",")
                    database.upsertMCPServer(
                        toolID: toolID,
                        serverName: server.name,
                        command: server.command,
                        envVars: envSummary
                    )
                }
            }
        }

        // Run risk detection across all adapters (pass database for drift detection)
        let result = AISecurityEngine.scan(sessions: sessions, database: database)
        securityScanResult = result
        database?.saveSecurityFindings(result.signals)
        database?.saveRiskSignals(result.signals)

        isScanningSecurity = false
    }

    // MARK: - Config Snapshot Helpers

    private func configSnapshotJSON(_ config: AIToolConfig) -> String {
        var dict: [String: Any] = [
            "tool": config.tool,
            "layers": config.layers.map(\.label),
            "mcpServers": config.mcpServers,
            "hasHooks": config.hasHooks,
            "autoMode": config.autoMode,
            "memoryEnabled": config.memoryEnabled,
            "managedPolicy": config.managedPolicy,
            "allowed": config.permissions.totalAllowed,
            "denied": config.permissions.totalDenied,
            "ask": config.permissions.totalAsk,
        ]
        if let sandbox = config.sandboxMode { dict["sandboxMode"] = sandbox }
        if let network = config.networkAccess { dict["networkAccess"] = network }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func permissionsHash(_ permissions: PermissionSummary) -> String {
        let parts = [
            "a:\(permissions.totalAllowed)",
            "d:\(permissions.totalDenied)",
            "q:\(permissions.totalAsk)"
        ]
        return parts.joined(separator: "|")
    }

    /// Resolve (dismiss) a risk signal by ID. Removes it from the current scan result
    /// and marks it resolved in the database.
    func resolveRiskSignal(id: UUID) {
        database?.resolveRiskSignal(id: id.uuidString)
        if let result = securityScanResult {
            let filtered = result.signals.filter { $0.id != id }
            securityScanResult = AISecurityScanResult(
                scanDate: result.scanDate,
                signals: filtered,
                sessions: result.sessions,
                projectCount: result.projectCount
            )
        }
    }

    /// Load previously persisted scan results from the database.
    private func loadPersistedSecurityFindings() {
        guard let database else { return }
        let signals = database.loadSecurityFindings()
        guard !signals.isEmpty else { return }
        securityScanResult = AISecurityScanResult(
            scanDate: signals.first?.detectedAt ?? .now,
            signals: signals,
            sessions: [],
            projectCount: 0
        )
    }

    // MARK: - Daily Stats Accumulation

    private func accumulateDailyStat(_ rate: ProcessIORate) {
        var profile = pendingDailyStats[rate.processName] ?? ProcessIOProfile(processName: rate.processName)
        profile.addSample(readBytesPerSec: rate.readBytesPerSec,
                          writeBytesPerSec: rate.writeBytesPerSec)
        pendingDailyStats[rate.processName] = profile
    }

    private func flushDailyStats() {
        guard let database, !pendingDailyStats.isEmpty else { return }

        let today = Database.dateString()
        let statsToFlush = pendingDailyStats
        pendingDailyStats.removeAll()
        lastFlush = .now

        // Write to SQLite (not on main thread for large flushes, but
        // the database is thread-safe with WAL mode)
        for (name, profile) in statsToFlush {
            database.upsertDailyStats(
                processName: name,
                date: today,
                readStats: profile.readStats,
                writeStats: profile.writeStats
            )
        }
    }
}
