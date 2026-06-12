# Vigil

**See what your Mac is doing — especially your AI tools.** Vigil monitors processes, file activity, and AI agent behavior on your Mac, surfacing it through an intuitive visualization interface. Think behavioral antivirus, minus the blocking: observe, analyze, understand.

Part of the [Subversive Software](https://github.com/subversivesoftware) family alongside Elucidate (Bluetooth discovery) and Tapped (network visualization).

## What It Does

Vigil sits as a visual layer over your system, surfacing what processes are running, what files are being touched, and what your AI coding tools are doing. It runs entirely in user space with no special permissions — it sees the same processes you'd see in Activity Monitor.

### System Monitoring

- **Overview** — Glanceable system health dashboard with health score, process breakdown, and file activity summary.
- **Processes** — Every running process with memory, disk I/O rates, category icons, and descriptions from a built-in knowledge database of hundreds of known macOS processes.
- **File Activity** — Real-time file system events via FSEvents.
- **File Sharing** — Detects cloud sync (Dropbox, OneDrive, iCloud, Google Drive), backup, and transfer activity.
- **History** — Long-term behavioral trends comparing process I/O across time windows.

### AI Activity Ledger

- **AI Overview** — Aggregate risk dashboard across all AI tools. Risk posture score, top risk signals, configured tools, macOS privacy grants, MCP server and prompt surface counts.
- **Agent Timeline** — Chronological view of AI sessions across all tools, with expandable details (commands, files, models, tokens).
- **AI Logs** — Raw session log browser for Claude Code sessions with full tool use, file, and command details.

### AI Security

- **Permissions Matrix** — Grid view showing each AI tool's capabilities: shell access, file write, network, MCP, hooks, auto-approval, and macOS privacy grants.
- **Risk Signals** — Security analysis dashboard with detections for sensitive file access, suspicious commands, exfiltration patterns, MCP risk, file sharing exposure, and excessive agency.
- **MCP & Rules** — Inventory of all MCP servers (command, args, env vars, auto-approved tools) and prompt surface files (CLAUDE.md, AGENTS.md, .cursorrules, etc.) across all tools.
- **AI Inventory** — Persistent catalog of all AI tools observed on this system, with first/last seen timestamps and evidence basis.

### Menu Bar

A persistent menu bar icon provides quick access to monitoring status without opening the full app.

## AI Tool Support

Vigil uses a **protocol-based adapter architecture** where each AI tool encapsulates its own detection, config reading, session parsing, and risk rules. Currently supported:

| Tool | Detection | Config | Sessions | Risk Rules |
|------|-----------|--------|----------|------------|
| Claude Code | Process + path | Settings layers, managed policy, MCP, hooks, CLAUDE.md | Full JSONL parsing (12 tool types) | All detections |
| Codex CLI | Process + path | TOML config, MCP, plugins, AGENTS.md | JSONL session parsing | Via shared engine |
| Cursor | Process + path | Settings, MCP, .cursorrules | — | Via shared engine |
| Windsurf | Process + path | Settings, .windsurfrules | — | Via shared engine |
| Cline / Roo | Process + path | VS Code settings, MCP, .clinerules | — | Via shared engine |
| GitHub Copilot | Process + path | — | — | Via shared engine |
| Aider | Process + path | YAML config | — | Via shared engine |
| Ollama | Process + path | — | — | — |
| LM Studio | Process + path | — | — | — |

To add a new AI tool: create one file conforming to `AIToolAdapter`, add it to `AIAdapterRegistry.adapters`.

## Build & Run

Requires macOS 14+ and Swift 6.

```bash
swift build                  # Debug build
swift build -c release       # Release build
swift run Vigil              # Run
swift test                   # Run all tests
```

## Architecture

```
Vigil/
  App/              — App entry point, MenuBarExtra
  Models/           — ProcessSnapshot, FileEvent, AISessionLog, AIToolConfig,
                      AISecuritySignal, AIPrivacyPosture
  Services/
    Monitoring/     — Protocol-based monitors (ProcessMonitor, FileMonitor)
    Adapters/       — AIToolAdapter protocol + per-tool adapters (18 tools)
    Analysis/       — HeuristicsEngine, AIRiskEngine, MacOSPrivacyReader
  Store/            — @Observable MonitoringStore (central state)
  Persistence/      — SQLite (daily I/O, AI sessions, risk signals, MCP servers)
  Views/
    Overview/       — System health dashboard
    Processes/      — Process list with inspector
    FileActivity/   — Real-time file events
    FileSharing/    — Cloud sync and transfer detection
    AIOverview/     — AI risk posture dashboard
    AITimeline/     — Chronological session browser
    AILogs/         — Raw session log viewer
    AIPermissions/  — Permissions matrix
    AISecurity/     — Risk signal dashboard
    AIMCPSurface/   — MCP server and prompt surface inventory
    AIInventory/    — AI tool catalog
    AIActivity/     — Real-time AI process/file activity
    History/        — Long-term I/O trends
    Components/     — Shared view components
```

### Key Design Decisions

- **Adapter-based AI detection** — Each AI tool gets a single adapter conforming to `AIToolAdapter`. The `AIAdapterRegistry` aggregates process matching, config discovery, session parsing, and risk detection across all adapters.
- **Protocol-based monitoring** — `ProcessDataSource` and `FileEventSource` protocols let implementations be swapped or layered. Currently uses `libproc` for processes and `FSEvents` for file monitoring.
- **Welford's algorithm** — I/O baselines use online mean/variance computation with O(1) memory per process. Stats are mergeable across time windows using the parallel Welford formula.
- **SQLite persistence** — Daily I/O aggregates, AI sessions, risk signals, and MCP server inventory stored in `~/Library/Application Support/Vigil/`. Schema versioning with migration support.
- **Zero dependencies** — Pure Apple frameworks only. No third-party packages.
- **User space only** — No entitlements, no Endpoint Security framework, no system extensions. Everything runs with standard user privileges.

### Risk Detection

| Category | What it catches |
|----------|----------------|
| Sensitive File Access | AI reading/writing .env, SSH keys, credentials, kubeconfig, .tfstate, etc. |
| Suspicious Commands | curl\|bash, sudo, osascript, launchctl, keychain access, unpinned npx, chmod 777 |
| Exfiltration Risk | HTTP uploads, tunnel tools (ngrok), paste services, socat, remote file transfers |
| MCP Risk | Unpinned packages, sensitive env vars, auto-approved tools |
| File Sharing Exposure | AI writes to Dropbox/iCloud/OneDrive-synced directories |
| Excessive Agency | Broad auto-approval, high tool-to-human ratios, elevated macOS privacy grants |
| Token Usage | High tokens-per-file or tokens-per-turn ratios |
| Long Session | Sessions running beyond threshold duration |

### macOS Privacy Posture

Vigil reads the user-level TCC database to surface which AI tools have been granted elevated macOS permissions (Accessibility, Screen Recording, Full Disk Access, Input Monitoring, etc.). Combined with AI agent capabilities, these permissions significantly increase blast radius.

## Privacy

All data stays on your Mac. Vigil stores process statistics, AI session data, and risk signals locally in SQLite and never transmits anything. It monitors the same process information available to any user-level application.

## License

Copyright Subversive Software. All rights reserved.
