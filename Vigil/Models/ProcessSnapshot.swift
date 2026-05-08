import Foundation

/// A point-in-time snapshot of a running process.
struct ProcessSnapshot: Identifiable, Hashable, Codable {
    let pid: Int32
    let name: String
    let path: String?
    let parentPid: Int32
    let cpuUsage: Double
    let memoryBytes: UInt64
    let timestamp: Date

    // MARK: - I/O counters (cumulative since process start)

    let diskBytesRead: UInt64
    let diskBytesWritten: UInt64
    let logicalWrites: UInt64
    let physicalFootprint: UInt64
    let pageins: UInt64
    let energyNanojoules: UInt64

    var id: Int32 { pid }

    var displayName: String {
        if let path {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        return name
    }
}

/// Per-process I/O rates derived from diffing two consecutive snapshots.
struct ProcessIORate: Identifiable, Hashable {
    let pid: Int32
    let processName: String
    let readBytesPerSec: Double
    let writeBytesPerSec: Double
    let logicalWritesPerSec: Double
    let interval: TimeInterval

    var id: Int32 { pid }

    /// Compute rates by diffing two snapshots of the same process.
    static func from(previous: ProcessSnapshot, current: ProcessSnapshot) -> ProcessIORate? {
        guard previous.pid == current.pid else { return nil }
        let dt = current.timestamp.timeIntervalSince(previous.timestamp)
        guard dt > 0 else { return nil }

        return ProcessIORate(
            pid: current.pid,
            processName: current.displayName,
            readBytesPerSec: Double(current.diskBytesRead.subtractingClamped(previous.diskBytesRead)) / dt,
            writeBytesPerSec: Double(current.diskBytesWritten.subtractingClamped(previous.diskBytesWritten)) / dt,
            logicalWritesPerSec: Double(current.logicalWrites.subtractingClamped(previous.logicalWrites)) / dt,
            interval: dt
        )
    }
}

extension UInt64 {
    /// Subtraction that clamps to 0 if the result would underflow
    /// (handles counter resets on process restart).
    func subtractingClamped(_ other: UInt64) -> UInt64 {
        self >= other ? self - other : 0
    }
}
