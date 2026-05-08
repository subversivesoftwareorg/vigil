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

    /// Database for persistent storage of daily I/O aggregates.
    private(set) var database: Database?

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
                    self?.fileEvents.append(contentsOf: batch)
                    // Keep a rolling window to avoid unbounded growth
                    if let self, self.fileEvents.count > 10_000 {
                        self.fileEvents = Array(self.fileEvents.suffix(5_000))
                    }
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

        // Periodic flush to SQLite
        if Date.now.timeIntervalSince(lastFlush) >= Self.flushInterval {
            flushDailyStats()
        }
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
