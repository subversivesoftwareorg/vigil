import Foundation
import CoreServices

/// Monitors file system events using the FSEvents API.
/// Watches specified directory paths and emits batches of FileEvent.
final class FileMonitor: FileEventSource, @unchecked Sendable {

    private(set) var isRunning = false
    private let watchedPaths: [String]
    private let latency: CFTimeInterval
    private let continuation: AsyncStream<[FileEvent]>.Continuation
    let events: AsyncStream<[FileEvent]>
    private var stream: FSEventStreamRef?

    /// - Parameters:
    ///   - paths: Directories to monitor. Defaults to user home.
    ///   - latency: Coalescing interval in seconds. Lower = more responsive, higher = fewer batches.
    init(paths: [String]? = nil, latency: CFTimeInterval = 1.0) {
        self.watchedPaths = paths ?? [NSHomeDirectory()]
        self.latency = latency
        var cont: AsyncStream<[FileEvent]>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    func start() async throws {
        guard !isRunning else { return }
        isRunning = true

        let pathsToWatch = watchedPaths as CFArray
        let contextPointer = Unmanaged.passUnretained(self).toOpaque()

        var context = FSEventStreamContext(
            version: 0,
            info: contextPointer,
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let eventStream = FSEventStreamCreate(
            nil,
            fsEventsCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else {
            isRunning = false
            return
        }

        stream = eventStream
        FSEventStreamSetDispatchQueue(eventStream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(eventStream)
    }

    func stop() async {
        isRunning = false
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
        continuation.finish()
    }

    // MARK: - Event Handling

    fileprivate func handleEvents(paths: [String], flags: [UInt32]) {
        let now = Date()
        let events = zip(paths, flags).map { path, flag in
            FileEvent(
                id: UUID(),
                path: path,
                kind: Self.eventKind(from: flag),
                timestamp: now
            )
        }
        continuation.yield(events)
    }

    private static func eventKind(from flags: UInt32) -> FileEvent.Kind {
        if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 { return .created }
        if flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 { return .deleted }
        if flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 { return .renamed }
        if flags & UInt32(kFSEventStreamEventFlagItemInodeMetaMod) != 0 { return .metadataChanged }
        return .modified
    }
}

// MARK: - FSEvents C Callback

private func fsEventsCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let monitor = Unmanaged<FileMonitor>.fromOpaque(info).takeUnretainedValue()

    let cfPaths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
    var paths: [String] = []
    for i in 0..<numEvents {
        if let path = CFArrayGetValueAtIndex(cfPaths, i) {
            let cfStr = Unmanaged<CFString>.fromOpaque(path).takeUnretainedValue()
            paths.append(cfStr as String)
        }
    }

    let flags = (0..<numEvents).map { eventFlags[$0] }
    monitor.handleEvents(paths: paths, flags: flags)
}
