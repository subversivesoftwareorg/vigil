# Vigil

**A visual layer for what's happening on your Mac.** Vigil monitors processes, file activity, and system behavior — surfacing it all through an intuitive visualization interface. Think behavioral antivirus, minus the blocking: observe, analyze, understand.

Part of the Subversive Software family alongside [Elucidate](../survey) (Bluetooth discovery) and [Tapped](../tapped) (network visualization).

## Quick Reference

```
Bundle ID:    com.subversivesoftware.vigil
Platform:     macOS 14+
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
    Adapters/                   # AIToolAdapter protocol + per-tool adapters
      AIToolAdapter.swift       # Protocol, ProcessSignature, PathSignature
      AIAdapterRegistry.swift   # Unified registry for all AI tool adapters
      ClaudeCodeAdapter.swift   # Claude Code: config, sessions, risk rules
      CodexAdapter.swift        # Codex CLI: TOML config, session parsing
      CursorAdapter.swift       # Cursor: settings, MCP, .cursorrules
      # ... plus adapters for Windsurf, Copilot, Aider, Cline/Roo, Ollama, etc.
    Analysis/                   # Heuristics, scoring, risk detection
      AIRiskEngine.swift        # Cross-tool risk: file sharing, MCP, agency
      MacOSPrivacyReader.swift  # TCC database + LaunchAgent scanning
  Store/                        # @Observable @MainActor state stores
    MonitoringStore.swift       # Central state for all monitoring data
  Persistence/                  # SQLite layer (schema v3)
  Views/
    MainWindowView.swift        # Root view with sidebar navigation
    Overview/                   # System health dashboard
    Processes/                  # Process list with inspector
    FileActivity/               # Real-time file events
    FileSharing/                # Cloud sync and transfer detection
    AIOverview/                 # AI risk posture dashboard
    AITimeline/                 # Chronological session browser
    AIPermissions/              # Permissions matrix
    AISecurity/                 # Risk signal dashboard
    AIMCPSurface/               # MCP server + prompt surface inventory
    AIInventory/                # AI tool catalog
    AIActivity/                 # Real-time AI process/file activity
    AILogs/                     # Raw session log viewer
    History/                    # Long-term I/O trends
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

### AI Tool Adapter Architecture

Each AI tool is represented by a struct conforming to `AIToolAdapter` (defined in `Vigil/Services/Adapters/AIToolAdapter.swift`). Adapters encapsulate:
- **Process/path signatures** — how to detect the tool is running or has local data
- **Config reading** — parsing tool-specific settings files (JSON, TOML, etc.)
- **Session parsing** — reading structured session logs (JSONL)
- **Risk detection** — tool-specific security rules

`AIAdapterRegistry` holds all adapters and provides aggregate queries: `matchProcess()`, `matchPath()`, `discoverAllConfigs()`, `parseAllSessions()`, `detectAllRisks()`. To add a new AI tool, create one adapter file and add it to the registry.

Cross-tool risk detections (file sharing exposure, MCP risk, excessive agency, macOS privacy posture) live in `AIRiskEngine`.

### Sidebar Structure

The sidebar is organized into three groups:
- **System**: Overview, Processes, File Activity, File Sharing
- **AI Activity**: AI Overview, Agent Timeline, AI Logs
- **AI Security**: Permissions, Risk Signals, MCP & Rules, AI Inventory

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
