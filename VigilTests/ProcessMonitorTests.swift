import Foundation
import Testing
@testable import Vigil

@Suite("ProcessMonitor")
struct ProcessMonitorTests {

    @Test("captureSnapshot returns non-empty list on a running system")
    func snapshotNotEmpty() {
        let monitor = ProcessMonitor()
        let snapshot = monitor.captureSnapshot()
        #expect(!snapshot.isEmpty, "A running macOS system should have at least one process")
    }

    @Test("snapshot contains the current process")
    func snapshotContainsSelf() {
        let monitor = ProcessMonitor()
        let snapshot = monitor.captureSnapshot()
        let myPid = ProcessInfo.processInfo.processIdentifier
        let found = snapshot.contains { $0.pid == myPid }
        #expect(found, "Snapshot should include our own process (pid \(myPid))")
    }

    @Test("all snapshots have positive pids")
    func positivePids() {
        let monitor = ProcessMonitor()
        let snapshot = monitor.captureSnapshot()
        for process in snapshot {
            #expect(process.pid > 0)
        }
    }
}
