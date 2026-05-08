import Foundation

/// Tracks rolling I/O statistics per process name to build a model of "normal" behavior.
/// Used by the heuristics engine to detect anomalous read/write patterns.
///
/// This uses Welford's online algorithm to compute running mean and variance
/// without storing every sample — O(1) memory per process.
@Observable @MainActor
final class IOBaseline {

    /// Per-process-name statistics.
    private(set) var profiles: [String: ProcessIOProfile] = [:]

    // MARK: - Recording

    /// Record a new I/O rate observation for a process.
    func record(_ rate: ProcessIORate) {
        let name = rate.processName
        var profile = profiles[name] ?? ProcessIOProfile(processName: name)
        profile.addSample(readBytesPerSec: rate.readBytesPerSec,
                          writeBytesPerSec: rate.writeBytesPerSec)
        profiles[name] = profile
    }

    /// Returns the anomaly score for a given I/O rate against the baseline.
    /// Score > 2.0 is unusual, > 3.0 is highly anomalous.
    /// Returns nil if we don't have enough samples for a baseline.
    func anomalyScore(for rate: ProcessIORate) -> IOAnomalyScore? {
        guard let profile = profiles[rate.processName],
              profile.sampleCount >= IOBaseline.minimumSamples else {
            return nil
        }

        let readZ = profile.readStats.zScore(for: rate.readBytesPerSec)
        let writeZ = profile.writeStats.zScore(for: rate.writeBytesPerSec)

        return IOAnomalyScore(
            processName: rate.processName,
            readZScore: readZ,
            writeZScore: writeZ,
            sampleCount: profile.sampleCount,
            baselineReadMean: profile.readStats.mean,
            baselineWriteMean: profile.writeStats.mean
        )
    }

    /// Minimum samples before we consider a baseline reliable.
    static let minimumSamples = 10
}

// MARK: - ProcessIOProfile

/// Rolling I/O statistics for a single process name.
struct ProcessIOProfile: Hashable {
    let processName: String
    private(set) var readStats = RunningStats()
    private(set) var writeStats = RunningStats()
    private(set) var sampleCount: Int = 0
    private(set) var lastSeen: Date = .now

    mutating func addSample(readBytesPerSec: Double, writeBytesPerSec: Double) {
        readStats.add(readBytesPerSec)
        writeStats.add(writeBytesPerSec)
        sampleCount += 1
        lastSeen = .now
    }
}

// MARK: - RunningStats (Welford's algorithm)

/// Online computation of mean and variance using Welford's algorithm.
/// Numerically stable, O(1) memory, and mergeable across time windows.
struct RunningStats: Hashable, Codable {
    private(set) var count: Int = 0
    private(set) var mean: Double = 0
    private(set) var m2: Double = 0

    var variance: Double {
        count < 2 ? 0 : m2 / Double(count - 1)
    }

    var standardDeviation: Double {
        variance.squareRoot()
    }

    /// How many standard deviations a value is from the mean.
    func zScore(for value: Double) -> Double {
        let sd = standardDeviation
        guard sd > 0 else { return 0 }
        return (value - mean) / sd
    }

    mutating func add(_ value: Double) {
        count += 1
        let delta = value - mean
        mean += delta / Double(count)
        let delta2 = value - mean
        m2 += delta * delta2
    }

    /// Merge two RunningStats using the parallel Welford formula.
    /// This allows combining daily aggregates into arbitrary time windows.
    static func merge(_ a: RunningStats, _ b: RunningStats) -> RunningStats {
        if a.count == 0 { return b }
        if b.count == 0 { return a }

        let n = a.count + b.count
        let delta = b.mean - a.mean
        let mergedMean = a.mean + delta * Double(b.count) / Double(n)
        let mergedM2 = a.m2 + b.m2 + delta * delta * Double(a.count) * Double(b.count) / Double(n)

        var result = RunningStats()
        result.count = n
        result.mean = mergedMean
        result.m2 = mergedM2
        return result
    }

    /// Merge an array of RunningStats into one.
    static func mergeAll(_ stats: [RunningStats]) -> RunningStats {
        stats.reduce(RunningStats()) { merge($0, $1) }
    }

    /// Initialize with known values (for loading from persistence).
    init(count: Int = 0, mean: Double = 0, m2: Double = 0) {
        self.count = count
        self.mean = mean
        self.m2 = m2
    }
}

// MARK: - IOAnomalyScore

/// The result of comparing current I/O against a baseline.
struct IOAnomalyScore {
    let processName: String
    let readZScore: Double
    let writeZScore: Double
    let sampleCount: Int
    let baselineReadMean: Double
    let baselineWriteMean: Double

    /// The maximum anomaly across read and write.
    var maxZScore: Double {
        max(abs(readZScore), abs(writeZScore))
    }

    var severity: Severity {
        switch maxZScore {
        case ..<2.0: .normal
        case 2.0..<3.0: .unusual
        case 3.0..<4.0: .anomalous
        default: .extreme
        }
    }

    enum Severity: String, Comparable {
        case normal = "Normal"
        case unusual = "Unusual"
        case anomalous = "Anomalous"
        case extreme = "Extreme"

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.order < rhs.order
        }

        private var order: Int {
            switch self {
            case .normal: 0
            case .unusual: 1
            case .anomalous: 2
            case .extreme: 3
            }
        }
    }
}
