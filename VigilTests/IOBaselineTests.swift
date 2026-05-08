import Foundation
import Testing
@testable import Vigil

@Suite("RunningStats")
struct RunningStatsTests {

    @Test("single value has zero variance")
    func singleValue() {
        var stats = RunningStats()
        stats.add(42.0)
        #expect(stats.mean == 42.0)
        #expect(stats.variance == 0)
        #expect(stats.standardDeviation == 0)
    }

    @Test("computes correct mean and stddev for known values")
    func knownValues() {
        var stats = RunningStats()
        // Values: 2, 4, 4, 4, 5, 5, 7, 9
        // Mean = 5.0, StdDev ≈ 2.0
        for v in [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0] {
            stats.add(v)
        }
        #expect(stats.count == 8)
        #expect(stats.mean == 5.0)
        #expect(abs(stats.standardDeviation - 2.138) < 0.01)
    }

    @Test("z-score measures distance from mean in stddevs")
    func zScore() {
        var stats = RunningStats()
        for v in [10.0, 10.0, 10.0, 10.0, 10.0, 20.0, 20.0, 20.0, 20.0, 20.0] {
            stats.add(v)
        }
        // Mean = 15, SD ≈ 5.27
        let z = stats.zScore(for: 25.27)
        #expect(abs(z - 1.945) < 0.1) // ~2 stddevs above mean
    }

    @Test("z-score is zero when stddev is zero")
    func zScoreZeroVariance() {
        var stats = RunningStats()
        stats.add(5.0)
        stats.add(5.0)
        stats.add(5.0)
        #expect(stats.zScore(for: 100.0) == 0)
    }
}

@Suite("IOBaseline")
struct IOBaselineTests {

    @Test("returns nil for insufficient samples")
    @MainActor func insufficientSamples() {
        let baseline = IOBaseline()
        let rate = ProcessIORate(pid: 1, processName: "test",
                                 readBytesPerSec: 100, writeBytesPerSec: 50,
                                 logicalWritesPerSec: 0, interval: 2)
        // Record fewer than minimum samples
        for _ in 0..<(IOBaseline.minimumSamples - 1) {
            baseline.record(rate)
        }
        #expect(baseline.anomalyScore(for: rate) == nil)
    }

    @Test("detects anomalous spike after building baseline")
    @MainActor func detectsSpike() {
        let baseline = IOBaseline()

        // Build a stable baseline: ~100 bytes/sec read
        for _ in 0..<50 {
            let normal = ProcessIORate(pid: 1, processName: "test",
                                       readBytesPerSec: 100 + Double.random(in: -5...5),
                                       writeBytesPerSec: 50,
                                       logicalWritesPerSec: 0, interval: 2)
            baseline.record(normal)
        }

        // Now hit it with a massive spike
        let spike = ProcessIORate(pid: 1, processName: "test",
                                   readBytesPerSec: 10_000_000,
                                   writeBytesPerSec: 50,
                                   logicalWritesPerSec: 0, interval: 2)

        let score = baseline.anomalyScore(for: spike)
        #expect(score != nil)
        #expect(score!.severity >= .extreme)
        #expect(score!.readZScore > 3.0)
    }

    @Test("normal behavior scores as normal")
    @MainActor func normalBehavior() {
        let baseline = IOBaseline()

        for _ in 0..<50 {
            let rate = ProcessIORate(pid: 1, processName: "test",
                                     readBytesPerSec: 100 + Double.random(in: -10...10),
                                     writeBytesPerSec: 50 + Double.random(in: -5...5),
                                     logicalWritesPerSec: 0, interval: 2)
            baseline.record(rate)
        }

        let check = ProcessIORate(pid: 1, processName: "test",
                                   readBytesPerSec: 105,
                                   writeBytesPerSec: 48,
                                   logicalWritesPerSec: 0, interval: 2)

        let score = baseline.anomalyScore(for: check)
        #expect(score != nil)
        #expect(score!.severity == .normal)
    }

    @Test("tracks separate profiles per process name")
    @MainActor func separateProfiles() {
        let baseline = IOBaseline()

        let rateA = ProcessIORate(pid: 1, processName: "processA",
                                   readBytesPerSec: 100, writeBytesPerSec: 0,
                                   logicalWritesPerSec: 0, interval: 2)
        let rateB = ProcessIORate(pid: 2, processName: "processB",
                                   readBytesPerSec: 5000, writeBytesPerSec: 0,
                                   logicalWritesPerSec: 0, interval: 2)

        for _ in 0..<20 {
            baseline.record(rateA)
            baseline.record(rateB)
        }

        #expect(baseline.profiles["processA"] != nil)
        #expect(baseline.profiles["processB"] != nil)
        #expect(baseline.profiles["processA"]!.readStats.mean < 200)
        #expect(baseline.profiles["processB"]!.readStats.mean > 4000)
    }
}

@Suite("IOAnomalyScore.Severity")
struct SeverityTests {

    @Test("severities are ordered correctly")
    func ordering() {
        #expect(IOAnomalyScore.Severity.normal < .unusual)
        #expect(IOAnomalyScore.Severity.unusual < .anomalous)
        #expect(IOAnomalyScore.Severity.anomalous < .extreme)
    }
}
