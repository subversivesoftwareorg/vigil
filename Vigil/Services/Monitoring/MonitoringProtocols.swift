import Foundation

/// Base protocol for all system monitors.
/// Monitors are long-lived objects that can be started and stopped.
protocol SystemMonitor: Sendable {
    var isRunning: Bool { get }
    func start() async throws
    func stop() async
}

/// A source of process data. Implementations can use libproc, sysctl,
/// NSWorkspace, or any combination — the store doesn't care.
protocol ProcessDataSource: SystemMonitor {
    /// Emits periodic snapshots of all running processes.
    var processes: AsyncStream<[ProcessSnapshot]> { get }
}

/// A source of file system events. Implementations can use FSEvents,
/// kqueue, DispatchSource, or anything else.
protocol FileEventSource: SystemMonitor {
    /// Emits batches of file events as they occur.
    var events: AsyncStream<[FileEvent]> { get }
}
