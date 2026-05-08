import Foundation

/// Compares process I/O behavior across time windows to detect behavioral changes.
///
/// Strategy: compare a recent window against a longer baseline.
/// - 7-day mean vs 30-day baseline → short-term shift
/// - 30-day mean vs 90-day baseline → medium-term drift
/// - 90-day mean vs 365-day baseline → long-term change
final class ReportingEngine {

    private let database: Database

    init(database: Database) {
        self.database = database
    }

    /// Analyze all processes and return those with behavioral changes, ranked by severity.
    func analyzeBehaviorChanges() -> [BehaviorReport] {
        let today = Database.dateString()
        let allProcesses = database.processNames(
            from: Database.dateString(daysAgo: 365),
            to: today
        )

        var reports: [BehaviorReport] = []

        for processName in allProcesses {
            let windows = loadWindows(processName: processName, today: today)
            let changes = detectChanges(processName: processName, windows: windows)

            if !changes.isEmpty {
                let knowledge = ProcessDatabase.lookup(processName)
                reports.append(BehaviorReport(
                    processName: processName,
                    knowledge: knowledge,
                    windows: windows,
                    changes: changes,
                    maxSeverity: changes.map(\.severity).max() ?? .stable
                ))
            }
        }

        return reports.sorted { $0.maxSeverity > $1.maxSeverity }
    }

    // MARK: - Window Loading

    private func loadWindows(processName: String, today: String) -> TimeWindows {
        TimeWindows(
            sevenDay: loadWindow(processName: processName, daysAgo: 7, to: today),
            thirtyDay: loadWindow(processName: processName, daysAgo: 30, to: today),
            ninetyDay: loadWindow(processName: processName, daysAgo: 90, to: today),
            yearLong: loadWindow(processName: processName, daysAgo: 365, to: today)
        )
    }

    private func loadWindow(processName: String, daysAgo: Int, to endDate: String) -> WindowStats {
        let startDate = Database.dateString(daysAgo: daysAgo)
        let (read, write) = database.loadMergedStats(
            processName: processName,
            from: startDate,
            to: endDate
        )
        return WindowStats(
            days: daysAgo,
            readStats: read,
            writeStats: write
        )
    }

    // MARK: - Change Detection

    private func detectChanges(processName: String, windows: TimeWindows) -> [BehaviorChange] {
        var changes: [BehaviorChange] = []

        // 7d vs 30d: short-term shift
        if let change = compareWindows(
            recent: windows.sevenDay, baseline: windows.thirtyDay,
            recentLabel: "7 days", baselineLabel: "30 days",
            comparison: .shortTerm
        ) {
            changes.append(change)
        }

        // 30d vs 90d: medium-term drift
        if let change = compareWindows(
            recent: windows.thirtyDay, baseline: windows.ninetyDay,
            recentLabel: "30 days", baselineLabel: "90 days",
            comparison: .mediumTerm
        ) {
            changes.append(change)
        }

        // 90d vs 365d: long-term change
        if let change = compareWindows(
            recent: windows.ninetyDay, baseline: windows.yearLong,
            recentLabel: "90 days", baselineLabel: "365 days",
            comparison: .longTerm
        ) {
            changes.append(change)
        }

        return changes
    }

    private func compareWindows(
        recent: WindowStats, baseline: WindowStats,
        recentLabel: String, baselineLabel: String,
        comparison: BehaviorChange.Comparison
    ) -> BehaviorChange? {
        // Need enough data in both windows
        guard recent.readStats.count >= 5, baseline.readStats.count >= 10 else {
            return nil
        }

        let readZ = baseline.readStats.zScore(for: recent.readStats.mean)
        let writeZ = baseline.writeStats.zScore(for: recent.writeStats.mean)
        let maxZ = max(abs(readZ), abs(writeZ))

        guard maxZ >= 2.0 else { return nil }

        let severity: BehaviorChange.Severity = switch maxZ {
        case 2.0..<3.0: .shifted
        case 3.0..<4.0: .changed
        default: .dramatically
        }

        return BehaviorChange(
            comparison: comparison,
            recentLabel: recentLabel,
            baselineLabel: baselineLabel,
            readZScore: readZ,
            writeZScore: writeZ,
            recentReadMean: recent.readStats.mean,
            recentWriteMean: recent.writeStats.mean,
            baselineReadMean: baseline.readStats.mean,
            baselineWriteMean: baseline.writeStats.mean,
            severity: severity
        )
    }
}

// MARK: - Data Types

struct TimeWindows {
    let sevenDay: WindowStats
    let thirtyDay: WindowStats
    let ninetyDay: WindowStats
    let yearLong: WindowStats

    func stats(for period: TimePeriod) -> WindowStats {
        switch period {
        case .sevenDays: sevenDay
        case .thirtyDays: thirtyDay
        case .ninetyDays: ninetyDay
        case .oneYear: yearLong
        }
    }
}

enum TimePeriod: String, CaseIterable, Identifiable {
    case sevenDays = "7 Days"
    case thirtyDays = "30 Days"
    case ninetyDays = "90 Days"
    case oneYear = "1 Year"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .sevenDays: 7
        case .thirtyDays: 30
        case .ninetyDays: 90
        case .oneYear: 365
        }
    }
}

struct WindowStats {
    let days: Int
    let readStats: RunningStats
    let writeStats: RunningStats

    var hasData: Bool { readStats.count > 0 }
    var sampleCount: Int { readStats.count }
}

struct BehaviorReport: Identifiable {
    let processName: String
    let knowledge: ProcessKnowledge?
    let windows: TimeWindows
    let changes: [BehaviorChange]
    let maxSeverity: BehaviorChange.Severity

    var id: String { processName }
}

struct BehaviorChange: Identifiable {
    let comparison: Comparison
    let recentLabel: String
    let baselineLabel: String
    let readZScore: Double
    let writeZScore: Double
    let recentReadMean: Double
    let recentWriteMean: Double
    let baselineReadMean: Double
    let baselineWriteMean: Double
    let severity: Severity

    var id: String { comparison.rawValue }

    var maxZScore: Double {
        max(abs(readZScore), abs(writeZScore))
    }

    /// Which metric is driving the change.
    var dominantMetric: String {
        abs(readZScore) > abs(writeZScore) ? "read" : "write"
    }

    /// Whether the change is an increase or decrease.
    var direction: String {
        let z = abs(readZScore) > abs(writeZScore) ? readZScore : writeZScore
        return z > 0 ? "increased" : "decreased"
    }

    enum Comparison: String {
        case shortTerm = "Short-term"
        case mediumTerm = "Medium-term"
        case longTerm = "Long-term"
    }

    enum Severity: String, Comparable {
        case stable = "Stable"
        case shifted = "Shifted"
        case changed = "Changed"
        case dramatically = "Dramatically Changed"

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.order < rhs.order
        }

        private var order: Int {
            switch self {
            case .stable: 0
            case .shifted: 1
            case .changed: 2
            case .dramatically: 3
            }
        }
    }
}
