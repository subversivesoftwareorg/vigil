import Foundation
import Testing
@testable import Vigil

@Suite("RunningStats.merge")
struct RunningStatsMergeTests {

    @Test("merging empty stats returns the other")
    func mergeWithEmpty() {
        var a = RunningStats()
        a.add(10)
        a.add(20)

        let merged = RunningStats.merge(RunningStats(), a)
        #expect(merged.count == 2)
        #expect(merged.mean == 15.0)
    }

    @Test("merge produces correct mean for known values")
    func mergedMean() {
        // Group A: [2, 4] → mean = 3
        var a = RunningStats()
        a.add(2); a.add(4)

        // Group B: [6, 8] → mean = 7
        var b = RunningStats()
        b.add(6); b.add(8)

        let merged = RunningStats.merge(a, b)
        #expect(merged.count == 4)
        #expect(merged.mean == 5.0) // (2+4+6+8)/4
    }

    @Test("merge produces correct variance")
    func mergedVariance() {
        // Build stats for [1, 2, 3, 4, 5] in two groups
        var a = RunningStats()
        a.add(1); a.add(2); a.add(3)

        var b = RunningStats()
        b.add(4); b.add(5)

        let merged = RunningStats.merge(a, b)

        // All-at-once for comparison
        var reference = RunningStats()
        for v in [1.0, 2.0, 3.0, 4.0, 5.0] { reference.add(v) }

        #expect(merged.count == reference.count)
        #expect(abs(merged.mean - reference.mean) < 0.001)
        #expect(abs(merged.variance - reference.variance) < 0.001)
    }

    @Test("mergeAll combines multiple groups correctly")
    func mergeAll() {
        var groups: [RunningStats] = []
        for values in [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]] {
            var s = RunningStats()
            for v in values { s.add(v) }
            groups.append(s)
        }

        let merged = RunningStats.mergeAll(groups)

        var reference = RunningStats()
        for v in [1.0, 2.0, 3.0, 4.0, 5.0, 6.0] { reference.add(v) }

        #expect(merged.count == 6)
        #expect(abs(merged.mean - reference.mean) < 0.001)
        #expect(abs(merged.variance - reference.variance) < 0.001)
    }

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        var stats = RunningStats()
        for v in [10.0, 20.0, 30.0] { stats.add(v) }

        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(RunningStats.self, from: data)

        #expect(decoded.count == stats.count)
        #expect(decoded.mean == stats.mean)
        #expect(decoded.variance == stats.variance)
    }
}
