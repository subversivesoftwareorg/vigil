# Vigil

**See what your Mac is doing.** Vigil monitors processes and file activity on your Mac, helping you understand what's running, how it's behaving, and whether anything looks unusual.

Think of it as a behavioral antivirus — it watches and reports, but never blocks. Part of the [Subversive Software](https://github.com/subversivesoftware) family alongside Elucidate (Bluetooth discovery) and Tapped (network visualization).

## What It Does

Vigil sits as a visual layer over your system, surfacing what processes are running, what files are being touched, and whether anything deviates from normal behavior. It runs entirely in user space with no special permissions — it sees the same processes you'd see in Activity Monitor.

### Four Modes

- **Simple** — A clean, glanceable overview. Process count, file event count, everything-is-fine-at-a-glance.
- **Expert** — The full picture. Every running process with memory, disk I/O rates, category icons, and descriptions from a built-in knowledge database of hundreds of known macOS processes. Click any process to open the inspector panel. Real-time file system events in the right pane.
- **Heuristics** — Automated analysis in plain English. Six checks run against your system and surface findings like "unrecognized process with high disk activity" or "Spotlight is working harder than usual — this is likely normal after installing new apps." Health score gives you a gut-feel number (0–100).
- **Reporting** — Long-term behavioral trends. Compares process I/O across time windows (7 days vs 30, 30 vs 90, 90 vs 365) to surface processes that have changed behavior over time.

### Menu Bar

A persistent menu bar icon shows the current health score and any findings at a glance, without opening the full app.

## Build & Run

Requires macOS 15+ and Swift 6.

```bash
swift build                  # Debug build
swift build -c release       # Release build
swift run Vigil              # Run
swift test                   # Run all tests
```

## Architecture

```
Vigil/
  App/           — App entry point, MenuBarExtra
  Models/        — ProcessSnapshot, FileEvent, IOBaseline, ProcessKnowledge
  Services/
    Monitoring/  — Protocol-based monitors (ProcessMonitor, FileMonitor)
    Analysis/    — HeuristicsEngine, ReportingEngine
  Store/         — @Observable MonitoringStore (central state)
  Persistence/   — SQLite daily I/O aggregates
  Views/         — SwiftUI views organized by mode
```

### Key Design Decisions

- **Protocol-based monitoring** — `ProcessDataSource` and `FileEventSource` protocols let implementations be swapped or layered. Currently uses `libproc` for processes and `FSEvents` for file monitoring.
- **Welford's algorithm** — I/O baselines use online mean/variance computation with O(1) memory per process. Stats are mergeable across time windows using the parallel Welford formula.
- **SQLite persistence** — Daily I/O aggregates stored in `~/Library/Application Support/Vigil/`. One compact row per process per day enables efficient cross-window comparison.
- **Zero dependencies** — Pure Apple frameworks only. No third-party packages.
- **User space only** — No entitlements, no Endpoint Security framework, no system extensions. Everything runs with standard user privileges.

### Process Knowledge Database

Vigil includes a built-in database of known macOS processes with:
- **Description** — What the process does, in plain English
- **Category** — Kernel, Security, Networking, Storage, iCloud, Developer Tool, etc.
- **Expectation** — Always running, usually running, transient, periodic, or user-launched

This powers the heuristics engine: "this always-running process disappeared" or "this transient process has been running for hours" are the kind of signals a behavioral tool surfaces.

### Heuristics Checks

| Check | What it catches |
|-------|----------------|
| Unknown + High I/O | Unrecognized process doing lots of disk work |
| Missing Essentials | A core system process has disappeared |
| Lifetime Violations | Transient process running too long |
| I/O Anomaly | Known process significantly above its baseline |
| High Energy | One process dominating energy consumption |
| Phantom Process | Process with no verifiable executable path |

## Privacy

All data stays on your Mac. Vigil stores daily I/O statistics locally in SQLite and never transmits anything. It monitors the same process information available to any user-level application.

## License

Copyright Subversive Software. All rights reserved.
