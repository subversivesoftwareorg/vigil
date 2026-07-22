# Vigil Roadmap

> Last updated: 2026-07-21

Vigil monitors AI coding tools running on your Mac — surfacing what they're doing, what they can access, and where the risks are. This roadmap captures where we're headed, informed by real-world MCP threat modeling and user feedback.

---

## Milestone 1: Polish & Wire Up (v1.1)

Complete and connect features that are already partially built but not yet exposed to users.

### Unreachable / Disconnected Views
- [x] Wire AI Activity view into sidebar navigation (`.aiActivity` exists in ViewMode but is not in any sidebar Section)
- [x] Wire Agent Timeline tool filter picker (state and computed property exist but no UI control)

### Persistence Gaps
- [x] Write config snapshots on each scan cycle (table `ai_config_snapshots` exists, no writers)
- [x] Write MCP server first/last seen on each scan cycle (table `ai_mcp_servers` exists, no writers)
- [ ] Persist sessions continuously, not just on manual security scan trigger

### Risk Signal Resolution
- [x] Add "Resolve" / "Dismiss" action on risk signal cards (`resolveRiskSignal()` exists in Database, no UI)
- [ ] Track resolution reason (false positive, mitigated, accepted) in UI
- [ ] Show resolved vs. open signal counts

### Security Engine Scope
- [x] Extend `AISecurityEngine.scan()` to run risk detection across all adapters, not just Claude Code
- [x] Include Codex CLI sessions in security scans (session parsing already works)

---

## Milestone 2: MCP Deep Visibility (v1.2)

The MCP view now shows config and usage. Next step: detect the threats described in the [MCP threat model](https://kondasecurity.com/blog/mcp-threat-model-trust-boundaries/) and [attack surface](https://kondasecurity.com/blog/mcp-attack-surface-what-security-teams-miss/) posts.

### Tool Description Scanning (AISVS C10.4.2)
- [x] Read tool descriptions from Claude Desktop session files (`remoteMcpServersConfig` with full schemas)
- [x] Scan tool descriptions for injection patterns (instruction-like content, references to sensitive paths, embedded commands, cross-tool references)
- [x] Surface findings as risk signals with category `.toolDescriptionInjection`

### Tool Definition Snapshots & Drift Detection (AISVS C10.4.8)
- [x] Diff current config against previous snapshot; alert on MCP servers added/removed and permission changes
- [ ] Snapshot MCP tool definitions (name, description, input schema) on each scan — currently snapshots config, not individual tool schemas
- [ ] Show diff view in MCP server card when drift is detected

### Tool Shadowing Detection
- [x] Detect duplicate MCP server names registered across different tools
- [x] Surface as a risk signal with the conflicting tool names and sources

### Dangerous Tool Combinations (AISVS C9.3.3, C9.3.4)
- [x] Define risky tool combination patterns (read + send, query + create_gist, get + email, etc.)
- [x] Detect when a session uses a dangerous combination from MCP calls across different servers
- [x] Show combination risk in Risk Signals views

### Cross-Server Data Flow Monitoring (AISVS C9.3.5)
- [x] Detect sessions using both sensitive servers (database, vault, credential) and external servers (email, slack, paste)
- [x] Flag cross-server flows as warning-level signals
- [ ] Visualize data flow paths in MCP view

### Supply Chain Indicators
- [ ] Alert when an MCP server's resolved package version changes between scans
- [ ] Flag servers installed via `npx`/`uvx`/`pipx` without lockfile or checksum verification
- [ ] Show version history in MCP server card

---

## Milestone 3: Broader Tool Coverage (v1.3)

Extend adapter depth beyond Claude Code so Vigil provides real visibility across all AI tools in use.

### Priority Adapters (Config + Session Parsing)
- [x] **Claude Desktop** — reads session JSON files for MCP servers and tool schemas, config from `claude_desktop_config.json` (done in M2)
- [ ] **Cursor** — parse session/workspace state for tool usage, file access patterns
- [ ] **Windsurf** — parse cascade session logs if available
- [ ] **Gemini CLI** — parse session JSONL files (session directory already discovered)
- [ ] **Zed** — parse AI thread database (path already discovered in adapter)

### Secondary Adapters (Config Reading)
- [x] **Ollama** — reads model manifests, reports model count/sizes, detects network-exposed API via OLLAMA_HOST
- [ ] **LM Studio** — read model catalog, detect API server configuration
- [ ] **ChatGPT Desktop** — read config if accessible, detect process
- [ ] **Copilot** — parse VS Code extension telemetry/state for session-like data

### Adapter Risk Detection
- [x] Add risk detection to Cursor adapter (MCP risks via AIRiskEngine)
- [x] Add risk detection to Codex adapter (suspicious bash, sensitive files, desktop mode, trusted projects, MCP risks)
- [x] Add risk detection to Zed adapter (external agents, extension count, MCP risks)
- [x] Add risk detection to Cline/Roo adapter (auto-approve, alwaysAllow on MCP servers, MCP risks)
- [x] Add risk detection to Ollama adapter (network-exposed API)

### Autonomous Agent Frameworks (always-on agents)

Unlike coding assistants, these run persistently with standing permissions and often a messaging-platform control channel — a different (and higher-agency) threat class. Research exact signatures per tool; they evolve quickly.

- [ ] **OpenClaw** (formerly Clawdbot/Moltbot) adapter — detect the gateway process and local port, read config/workspace (`~/.openclaw` and legacy `~/.clawdbot` paths), inventory installed skills, messaging-channel bridges (WhatsApp/Telegram/Discord/iMessage), and exec-approval settings
- [ ] **NanoClaw** adapter — container-based agent; detect config, mounted host volumes, and which directories the container can touch
- [ ] **Hermes** adapter — detect install, config, and granted capabilities
- [ ] Generic agent-daemon heuristics — flag persistent AI processes that combine a network listener + LaunchAgent/daemon persistence + shell exec capability, even for frameworks Vigil has no adapter for yet
- [ ] Agent-specific risk rules: always-on agency (no human turn in the loop), remote control via messaging platforms, broad filesystem mounts into agent workspaces, credentials stored in agent config/workspace, skills installed from untrusted sources (ClawHub etc.)
- [ ] Surface always-on agents distinctly in Glance mode (e.g., a persistent-orbit ring or badge — an agent that never sleeps deserves different visual weight than an editor)

---

## Milestone 4: UX — Make It Actionable (v1.4)

Shift from "here's what's happening" to "here's what you should do about it."

### Loading & Progress Experience
- [ ] Per-adapter scan progress reporting from the registry (AsyncStream of "scanning Claude Code… done, 214 sessions" events)
- [ ] Glance mode: orbs materialize one-by-one as each tool's scan completes; expanding radar ring sweep while scanning
- [ ] Advanced mode: skeleton placeholder rows instead of bare spinners
- [ ] Status banner narrates the scan in plain English ("Checking 12 of 19 tools…")
- [ ] First-run experience: scanning visual doubles as the "what Vigil does" introduction

### Search & Filter
- [ ] Global search across all views (processes, sessions, files, risk signals)
- [ ] Process list filtering/search
- [ ] AI Inventory filtering by category, provider, evidence level
- [ ] Date range picker on Agent Timeline and AI Logs

### Remediation Guidance
- [ ] Attach remediation steps to each risk signal category (e.g., "Pin this npx package by adding @version")
- [ ] Link risk signals to OWASP AISVS control references
- [ ] "How to fix" expandable section on risk signal cards

### Export & Reporting
- [ ] Export risk signals as JSON or CSV
- [ ] Export MCP server inventory
- [ ] Generate a PDF/HTML security posture report
- [ ] Periodic summary (weekly email or notification with signal trends)

### Notifications
- [ ] macOS notifications for new warning-level risk signals
- [ ] Menu bar badge count for unresolved warnings
- [ ] Optional notification for new MCP server detected

### Historical Trending
- [ ] AI risk signal trend chart (signals over time by severity)
- [ ] MCP server usage trends (calls per day/week)
- [ ] Session activity trends (sessions, tokens, commands over time)

---

## Milestone 5: Identity, Attribution & Policy (v2.0)

Address the [agent identity problem](https://kondasecurity.com/blog/agent-identity-problem-oauth-not-enough/) — the gap between "who has the credential" and "who intended the action."

### Session-Level Agent Identity (AISVS C9.4.1, C9.4.2)
- [ ] Assign a unique session identity to each observed AI agent session
- [ ] Tie all tool calls, file accesses, and commands to that session identity
- [ ] Build audit trail: user → agent session → tool calls → outcomes

### Intent Classification (Heuristic)
- [ ] Classify actions as user-prompted vs. agent-autonomous based on timing relative to human turns
- [ ] Flag autonomous action bursts (many tool calls with no intervening human input)
- [ ] Show intent classification in Agent Timeline session cards

### Three-Principal Attribution
- [ ] For each significant action, record: User (who started the session), Agent (which tool/model), Tool (which MCP server / built-in tool)
- [ ] Surface attribution in risk signals and session detail views

### Policy Engine (Declarative)
- [ ] Define per-tool policies (YAML): allowed MCP servers, denied tool combinations, required approval for categories
- [ ] Evaluate configs against policy on each scan; report violations as risk signals
- [ ] Server allow-list: warn when an MCP server is configured but not in the allow-list
- [ ] Ship a starter policy template for common setups

### OAuth & Credential Review
- [ ] Inventory OAuth tokens granted to MCP servers (where discoverable)
- [ ] Flag overly broad scopes
- [ ] Alert on tokens that haven't been rotated

---

## Milestone 6: Advanced Detection & Architecture (v2.x)

Long-term capabilities for deeper runtime visibility.

### Behavioral Anomaly Detection
- [ ] Build MCP usage baselines per server (typical tools called, call frequency, parameter sizes)
- [ ] Detect anomalies: unusual tool calls, parameter size spikes, new tools appearing mid-session
- [ ] Welford-style statistical baselines (reuse the pattern from I/O anomaly detection)

### Tool Annotation Verification
- [ ] Compare self-reported tool annotations (`readOnlyHint`, `destructiveHint`) against observed behavior
- [ ] Flag mismatches (tool claims read-only but triggers file writes)

### Response Content Scanning
- [ ] Scan MCP tool responses for prompt injection patterns
- [ ] Detect instruction-like content in data returned by tools
- [ ] Alert when tool responses contain references to other connected servers' tools

### Interception Architecture
- [ ] Investigate MCP proxy pattern (transparent proxy between client and server)
- [ ] Prototype sidecar approach for local stdio servers
- [ ] Evaluate gateway pattern feasibility for centralized enforcement
- [ ] Consider this as a separate companion tool or Vigil extension

### Network-Level Monitoring
- [ ] Detect unexpected outbound connections from MCP server processes
- [ ] Monitor for data exfiltration via MCP server-initiated network traffic
- [ ] Cross-reference with file access patterns (read sensitive file → network connection)

---

## Revisit (deferred items from earlier milestones)

### From M1
- [ ] Persist sessions continuously, not just on manual security scan trigger
- [ ] Track resolution reason (false positive, mitigated, accepted) in dismiss UI
- [ ] Show resolved vs. open signal counts in severity overview

### From M2
- [ ] Snapshot individual MCP tool definitions (name, description, inputSchema) — currently only snapshots config-level data
- [ ] Show config diff view in MCP server card when drift is detected
- [ ] Visualize cross-server data flow paths in MCP view
- [ ] Supply chain: alert on resolved package version changes between scans
- [ ] Supply chain: show version history in MCP server card

### Performance (from 2026-07 profiling)
- [ ] Incremental JSONL session parsing — session files are append-only; remember byte offset per file and parse only new lines instead of re-reading months of history on every scan
- [ ] Throttle/debounce HeuristicsEngine — currently recomputes on every 2-second process snapshot on the main actor; run at most every N snapshots or move analysis off the main actor
- [ ] Shared observable AI data store — one load pipeline that views subscribe to, replacing per-view `.task{}` loads (also the natural home for scan progress reporting)
- [ ] Batch SQLite writes in a transaction during scan persistence (persistSession currently issues dozens of individual statements per session)
- [ ] Replace SELECT-then-INSERT/UPDATE upserts with single `INSERT ... ON CONFLICT` statements

---

## Not Planned

These items have been considered and intentionally deferred:

- **Blocking / enforcement** — Vigil observes and alerts but never blocks. Enforcement lives in the tools themselves or in a separate gateway. This is a deliberate design choice.
- **Remote model security** — Training data poisoning, model theft, and model-level prompt injection are API provider concerns, not local monitoring concerns.
- **Windows / Linux** — macOS only for now. The monitoring layer (libproc, FSEvents, TCC) is deeply platform-specific.
- **AI-powered analysis** — Using an LLM to analyze findings would create a dependency on the thing we're monitoring. Keep analysis deterministic and auditable.

---

## Mapping to Threat Model

| Threat (from blog posts) | Current Coverage | Milestone |
|---|---|---|
| Auto-approved MCP tools | **Detected** | — |
| Sensitive env var passthrough | **Detected** | — |
| Unpinned package managers (npx/uvx) | **Detected** | — |
| Sensitive file access by AI | **Detected** | — |
| Suspicious bash commands | **Detected** | — |
| Exfiltration patterns | **Detected** | — |
| Excessive agency (broad permissions) | **Detected** | — |
| macOS privacy grants + AI | **Detected** | — |
| LaunchAgent persistence | **Detected** | — |
| File sharing exposure | **Detected** | — |
| Long/runaway sessions | **Detected** | — |
| Tokenmaxxing | **Detected** | — |
| Tool description injection | **Detected** (Claude Desktop schemas) | M2 |
| Tool definition drift | **Detected** (config snapshot diffing) | M1 + M2 |
| Tool shadowing | **Detected** | M2 |
| Dangerous tool combinations | **Detected** | M2 |
| Cross-server confused deputy | **Detected** (via cross-server flow) | M2 |
| Supply chain version changes | Partial (unpinned detected, version tracking pending) | M2 |
| Tool response injection | Not detected | M6 |
| Tool annotation deception | Not detected | M6 |
| Agent identity gap | Not tracked | M5 |
| Intent classification | Not tracked | M5 |
| OAuth scope abuse | Not tracked | M5 |
| Cross-server data flow | **Detected** | M2 |
| Behavioral anomalies | Not tracked | M6 |
