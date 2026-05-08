# Vigil

**A visual layer for what's happening on your Mac.** Vigil monitors processes, file activity, and system behavior — surfacing it all through an intuitive visualization interface. Think behavioral antivirus, minus the blocking: observe, analyze, understand.

Part of the Subversive Software family alongside [Elucidate](../survey) (Bluetooth discovery) and [Tapped](../tapped) (network visualization).

## Quick Reference

```
Bundle ID:    com.subversivesoftware.vigil
Platform:     macOS 15+
Swift:        6.x (language mode 5)
Build:        swift build / swift run Vigil
Test:         swift test
```

## Build & Run

```bash
swift build                  # Debug build
swift build -c release       # Release build
swift run Vigil              # Run debug build
swift test                   # Run all tests
```

## Architecture

### Project Layout

```
Vigil/
  App/
    VigilApp.swift              # @main entry point, window setup
  Models/                       # Plain structs — data shapes
  Services/
    Monitoring/                 # Protocol-based monitoring layer
      MonitoringProtocols.swift # Core protocols (SystemMonitor, ProcessDataSource, FileEventSource)
      ProcessMonitor.swift      # libproc-based process monitoring
      FileMonitor.swift         # FSEvents-based file monitoring
    Analysis/                   # Heuristics, scoring, pattern detection
  Store/                        # @Observable @MainActor state stores
    MonitoringStore.swift       # Central state for all monitoring data
  Persistence/                  # SQLite layer
  Views/
    MainWindowView.swift        # Root view with mode switching
    Simple/                     # Simple mode views
    Expert/                     # Expert mode views
    Heuristics/                 # Heuristics analysis views
    Reporting/                  # Broad reporting views
    Components/                 # Shared/reusable view components
  Extensions/                   # Swift extensions
  Resources/                    # Bundled data files
VigilTests/                     # Swift Testing test suite
```

### Patterns & Conventions

These conventions are shared with Elucidate and Tapped. Follow them strictly.

**State management:**
- `@Observable` macro on all service/store classes — never `ObservableObject`/`@Published`
- `@MainActor` on any class that touches UI state
- Environment injection via `.environment()` and `@Environment(Type.self)` — never `@EnvironmentObject`
- `@State private var` at top-level views for owning state objects
- `@AppStorage` for simple user preferences

**Code structure:**
- One primary type per file, filename matches type name
- Views use `*View`, `*Tab`, `*Sheet` suffixes
- Services are named descriptively: `ProcessMonitor`, `FileMonitor`, `HeuristicsEngine`
- `// MARK: -` comments for code organization within files
- Computed properties on models/enums for display logic (`displayName`, `systemImage`, `color`)

**Dependencies:**
- **Zero third-party dependencies.** Apple frameworks only.
- Allowed frameworks: SwiftUI, AppKit, Foundation, and system-level C APIs (`libproc`, `FSEvents`, `sqlite3`)

**Testing:**
- Swift Testing framework (`@Test`, `#expect`, `@Suite`) — not XCTest
- Test files mirror source structure in `VigilTests/`

**Naming:**
- Bundle ID: `com.subversivesoftware.vigil`
- Enum raw values: lowercase strings
- Models: plain structs with `Codable`, `Identifiable`, `Hashable` as needed
- Stores: `final class` with `@Observable @MainActor`

### Monitoring Architecture

The monitoring layer is **protocol-based and pluggable**, designed to evolve as we discover what data is most valuable.

```swift
// Core abstraction — all monitors conform to this
protocol SystemMonitor: Sendable {
    var isRunning: Bool { get }
    func start() async throws
    func stop() async
}

// Process data — implementations can use libproc, sysctl, NSWorkspace, etc.
protocol ProcessDataSource: SystemMonitor {
    var processes: AsyncStream<[ProcessSnapshot]> { get }
}

// File events — implementations can use FSEvents, kqueue, etc.
protocol FileEventSource: SystemMonitor {
    var events: AsyncStream<[FileEvent]> { get }
}
```

**Current implementations (user-space, no entitlements):**
- `ProcessMonitor` — uses `libproc.h` (`proc_listallpids`, `proc_pidinfo`) for process snapshots
- `FileMonitor` — uses `FSEvents` API for directory-level file change monitoring

**Design principles:**
- Monitors emit data via `AsyncStream` — stores subscribe and aggregate
- Multiple data sources can feed the same store (e.g., libproc + NSWorkspace for richer process info)
- New monitors can be added without changing existing code
- Temporal correlation between process and file data happens in the store layer, not in monitors

### Data Persistence

- **SQLite** via the C API (`import SQLite3`) — no ORM, no third-party wrapper
- High-throughput append-heavy writes (process snapshots, file events)
- Store at `~/Library/Application Support/Vigil/`
- Write batching to avoid overwhelming disk I/O
- Schema migrations handled manually with a version table

### View Modes (evolving)

Four planned visualization modes, to be fleshed out incrementally:

1. **Simple** — clean, glanceable overview for non-technical users
2. **Expert** — detailed process trees, file activity streams, raw data access
3. **Heuristics** — pattern-based analysis highlighting anomalies and suspicious behavior
4. **Reporting** — broad summary dashboards, trends over time, exportable reports

### Entitlements & Privileges

- **No entitlements required.** Everything runs in user-space.
- No Endpoint Security framework (requires system extension + entitlement)
- No App Sandbox (to allow system-wide process/file monitoring)
- If we later need elevated access, follow Tapped's pattern: a helper tool installed separately

## Working Conventions

- Keep the monitoring layer flexible — prefer adding new protocol conformances over modifying existing ones
- Start minimal, iterate based on what the data reveals
- Each view mode can evolve independently
- Commit messages: concise, focus on "why" not "what"
- No licensing infrastructure needed at this time
