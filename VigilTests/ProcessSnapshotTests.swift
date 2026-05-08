import Foundation
import Testing
@testable import Vigil

@Suite("ProcessSnapshot")
struct ProcessSnapshotTests {

    @Test("displayName returns filename from path")
    func displayNameFromPath() {
        let snapshot = makeSnapshot(pid: 1, name: "test", path: "/usr/bin/someprocess")
        #expect(snapshot.displayName == "someprocess")
    }

    @Test("displayName falls back to name when path is nil")
    func displayNameFallback() {
        let snapshot = makeSnapshot(pid: 1, name: "kernel_task")
        #expect(snapshot.displayName == "kernel_task")
    }

    @Test("identity is based on pid")
    func identityByPid() {
        let a = makeSnapshot(pid: 42, name: "a")
        let b = makeSnapshot(pid: 42, name: "b")
        #expect(a.id == b.id)
    }
}

@Suite("ProcessIORate")
struct ProcessIORateTests {

    @Test("computes rates from two snapshots")
    func rateComputation() {
        let t0 = Date(timeIntervalSince1970: 1000)
        let t1 = Date(timeIntervalSince1970: 1002) // 2 seconds later
        let prev = makeSnapshot(pid: 1, name: "test", timestamp: t0,
                                diskBytesRead: 1000, diskBytesWritten: 500)
        let curr = makeSnapshot(pid: 1, name: "test", timestamp: t1,
                                diskBytesRead: 3000, diskBytesWritten: 1500)

        let rate = ProcessIORate.from(previous: prev, current: curr)
        #expect(rate != nil)
        #expect(rate!.readBytesPerSec == 1000.0)   // (3000-1000)/2
        #expect(rate!.writeBytesPerSec == 500.0)    // (1500-500)/2
    }

    @Test("returns nil for different PIDs")
    func differentPids() {
        let a = makeSnapshot(pid: 1, name: "a")
        let b = makeSnapshot(pid: 2, name: "b")
        #expect(ProcessIORate.from(previous: a, current: b) == nil)
    }

    @Test("handles counter underflow gracefully")
    func counterReset() {
        let t0 = Date(timeIntervalSince1970: 1000)
        let t1 = Date(timeIntervalSince1970: 1002)
        let prev = makeSnapshot(pid: 1, name: "test", timestamp: t0, diskBytesRead: 5000)
        let curr = makeSnapshot(pid: 1, name: "test", timestamp: t1, diskBytesRead: 100)

        let rate = ProcessIORate.from(previous: prev, current: curr)
        #expect(rate != nil)
        #expect(rate!.readBytesPerSec == 0.0) // Clamped to 0, not negative
    }
}

// MARK: - Test Helper

func makeSnapshot(
    pid: Int32 = 1,
    name: String = "test",
    path: String? = nil,
    parentPid: Int32 = 0,
    cpuUsage: Double = 0,
    memoryBytes: UInt64 = 0,
    timestamp: Date = .now,
    diskBytesRead: UInt64 = 0,
    diskBytesWritten: UInt64 = 0,
    logicalWrites: UInt64 = 0,
    physicalFootprint: UInt64 = 0,
    pageins: UInt64 = 0,
    energyNanojoules: UInt64 = 0
) -> ProcessSnapshot {
    ProcessSnapshot(
        pid: pid, name: name, path: path, parentPid: parentPid,
        cpuUsage: cpuUsage, memoryBytes: memoryBytes, timestamp: timestamp,
        diskBytesRead: diskBytesRead, diskBytesWritten: diskBytesWritten,
        logicalWrites: logicalWrites, physicalFootprint: physicalFootprint,
        pageins: pageins, energyNanojoules: energyNanojoules
    )
}
