import Foundation
import Darwin

/// Monitors running processes using libproc.
/// Emits periodic snapshots of all processes at a configurable interval.
final class ProcessMonitor: ProcessDataSource, @unchecked Sendable {

    private(set) var isRunning = false
    private let interval: TimeInterval
    private let continuation: AsyncStream<[ProcessSnapshot]>.Continuation
    let processes: AsyncStream<[ProcessSnapshot]>
    private var task: Task<Void, Never>?

    init(interval: TimeInterval = 2.0) {
        self.interval = interval
        var cont: AsyncStream<[ProcessSnapshot]>.Continuation!
        self.processes = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    func start() async throws {
        guard !isRunning else { return }
        isRunning = true

        task = Task.detached { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let snapshot = self.captureSnapshot()
                self.continuation.yield(snapshot)
                try? await Task.sleep(for: .seconds(self.interval))
            }
        }
    }

    func stop() async {
        isRunning = false
        task?.cancel()
        task = nil
        continuation.finish()
    }

    // MARK: - libproc

    /// Captures a snapshot of all running processes using proc_listallpids,
    /// proc_pidinfo (for basic info + task info), and proc_pid_rusage (for I/O counters).
    func captureSnapshot() -> [ProcessSnapshot] {
        let bufferSize = proc_listallpids(nil, 0)
        guard bufferSize > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: Int(bufferSize))
        let actualSize = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * pids.count))
        guard actualSize > 0 else { return [] }

        let now = Date()
        let pidCount = Int(actualSize)

        return (0..<pidCount).compactMap { i -> ProcessSnapshot? in
            let pid = pids[i]
            guard pid > 0 else { return nil }

            // Basic process info (name, parent PID)
            var info = proc_bsdinfo()
            let infoSize = proc_pidinfo(
                pid,
                PROC_PIDTBSDINFO,
                0,
                &info,
                Int32(MemoryLayout<proc_bsdinfo>.size)
            )

            // Executable path — resolve early so it can serve as a name fallback
            // PROC_PIDPATHINFO_MAXSIZE = 4 * MAXPATHLEN (macro not importable to Swift)
            var pathBuffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
            let pathLen = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
            let path = pathLen > 0 ? String(cString: pathBuffer) : nil

            let name: String
            let parentPid: Int32

            if infoSize > 0 {
                name = withUnsafePointer(to: info.pbi_name) { ptr in
                    ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) {
                        String(cString: $0)
                    }
                }
                parentPid = Int32(info.pbi_ppid)
            } else {
                // Fallback chain for privileged processes:
                // 1. proc_name — works for some daemons where proc_pidinfo fails
                // 2. proc_pidpath — last resort; derive name from executable path
                var nameBuffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
                proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
                let fallbackName = String(cString: nameBuffer)
                if !fallbackName.isEmpty {
                    name = fallbackName
                } else if let path {
                    name = URL(fileURLWithPath: path).lastPathComponent
                } else {
                    return nil
                }
                parentPid = 0
            }

            // Task info (memory, CPU time)
            var taskInfo = proc_taskinfo()
            let taskSize = proc_pidinfo(
                pid,
                PROC_PIDTASKINFO,
                0,
                &taskInfo,
                Int32(MemoryLayout<proc_taskinfo>.size)
            )

            let memBytes = taskSize > 0 ? taskInfo.pti_resident_size : 0
            let cpuTime = taskSize > 0
                ? Double(taskInfo.pti_total_user + taskInfo.pti_total_system) / 1_000_000_000.0
                : 0.0

            // Resource usage (I/O counters, energy)
            let rusage = Self.captureRusage(pid: pid)

            return ProcessSnapshot(
                pid: pid,
                name: name,
                path: path,
                parentPid: parentPid,
                cpuUsage: cpuTime,
                memoryBytes: memBytes,
                timestamp: now,
                diskBytesRead: rusage.diskBytesRead,
                diskBytesWritten: rusage.diskBytesWritten,
                logicalWrites: rusage.logicalWrites,
                physicalFootprint: rusage.physicalFootprint,
                pageins: rusage.pageins,
                energyNanojoules: rusage.energyNanojoules
            )
        }
    }

    // MARK: - rusage

    private struct RusageResult {
        var diskBytesRead: UInt64 = 0
        var diskBytesWritten: UInt64 = 0
        var logicalWrites: UInt64 = 0
        var physicalFootprint: UInt64 = 0
        var pageins: UInt64 = 0
        var energyNanojoules: UInt64 = 0
    }

    private static func captureRusage(pid: pid_t) -> RusageResult {
        var info = rusage_info_v6()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V6, $0)
            }
        }
        guard result == 0 else { return RusageResult() }

        return RusageResult(
            diskBytesRead: info.ri_diskio_bytesread,
            diskBytesWritten: info.ri_diskio_byteswritten,
            logicalWrites: info.ri_logical_writes,
            physicalFootprint: info.ri_phys_footprint,
            pageins: info.ri_pageins,
            energyNanojoules: info.ri_energy_nj
        )
    }
}
