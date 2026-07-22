import Foundation

/// Aggregates every principal that can act on this machine into a single
/// ledger, from data the adapters and scanners already collect.
enum CapabilityLedgerBuilder {

    static func build(configs: [AIToolConfig], agents: [UnattendedAgent]) -> [LedgerEntry] {
        var entries: [LedgerEntry] = []

        for config in configs {
            entries.append(toolEntry(config))
            for server in config.mcpServerDetails {
                entries.append(mcpEntry(server, config: config))
            }
        }

        for agent in agents {
            entries.append(agentEntry(agent))
        }

        return entries
    }

    // MARK: - Tool Entries

    private static func toolEntry(_ config: AIToolConfig) -> LedgerEntry {
        let allowedCategories = Set(config.permissions.allowed.map(\.category))
        let askCategories = Set(config.permissions.requiresApproval.map(\.category))

        let shell: LedgerEntry.AccessLevel
        if allowedCategories.contains("Shell Commands") {
            shell = .granted
        } else if askCategories.contains("Shell Commands") {
            shell = .requiresApproval
        } else if allowedCategories.contains("Editor") {
            shell = .granted // IDE terminals are unrestricted
        } else {
            shell = .unknown
        }

        let network: LedgerEntry.AccessLevel
        if let explicit = config.networkAccess {
            network = explicit ? .granted : .denied
        } else if allowedCategories.contains("Web Access") {
            network = .granted
        } else if askCategories.contains("Web Access") {
            network = .requiresApproval
        } else {
            network = .unknown
        }

        let fileScope: [String]
        if let sandbox = config.sandboxMode {
            fileScope = [sandbox]
        } else {
            fileScope = ["Unsandboxed (full user access)"]
        }

        let approval: String
        if let mode = config.approvalMode {
            approval = mode
        } else if config.autoMode {
            approval = "Broad auto-approval"
        } else {
            let summary = config.permissions
            approval = "\(summary.totalAllowed) allowed · \(summary.totalAsk) ask · \(summary.totalDenied) denied"
        }

        return LedgerEntry(
            id: "tool-\(config.tool)",
            kind: .tool,
            name: config.tool,
            parent: nil,
            fileScope: fileScope,
            shellAccess: shell,
            networkAccess: network,
            browserDomains: [],
            schedule: nil,
            approvalMode: approval,
            grantedTools: [],
            source: config.layers.first?.path ?? ""
        )
    }

    // MARK: - MCP Server Entries

    private static func mcpEntry(_ server: MCPServerDetail, config: AIToolConfig) -> LedgerEntry {
        // Per-tool grants from the owning tool's settings allow-list:
        // permission groups categorized as "MCP (<server>)"
        let grantCategory = "MCP (\(server.name))"
        let grantedTools = config.permissions.allowed
            .first { $0.category == grantCategory }?.items ?? []

        let approval: String
        if !server.autoApprovedTools.isEmpty {
            approval = "Auto-approves \(server.autoApprovedTools.count) tool\(server.autoApprovedTools.count == 1 ? "" : "s")"
        } else if !grantedTools.isEmpty {
            approval = "\(grantedTools.count) tool\(grantedTools.count == 1 ? "" : "s") pre-approved"
        } else {
            approval = "Prompts per tool"
        }

        // stdio servers inherit the host environment; remote servers reach out
        let network: LedgerEntry.AccessLevel =
            (server.command?.hasPrefix("http") == true) ? .granted : .unknown

        return LedgerEntry(
            id: "mcp-\(config.tool)-\(server.name)",
            kind: .mcpServer,
            name: server.name,
            parent: config.tool,
            fileScope: [],
            shellAccess: server.command?.hasPrefix("http") == true ? .denied : .granted,
            networkAccess: network,
            browserDomains: [],
            schedule: nil,
            approvalMode: approval,
            grantedTools: grantedTools + server.autoApprovedTools,
            source: server.source
        )
    }

    // MARK: - Unattended Agent Entries

    private static func agentEntry(_ agent: UnattendedAgent) -> LedgerEntry {
        LedgerEntry(
            id: "ledger-\(agent.id)",
            kind: agent.kind == .cronJob ? .cronJob : .scheduledTask,
            name: agent.name,
            parent: agent.kind == .coworkScheduledTask ? "Claude Desktop" : nil,
            fileScope: agent.folderAccess,
            shellAccess: agent.capabilities.contains("Shell execution") ? .granted : .unknown,
            networkAccess: agent.capabilities.contains("Web search") || !agent.browserDomains.isEmpty
                ? .granted : .unknown,
            browserDomains: agent.browserDomains,
            schedule: agent.scheduleDescription,
            approvalMode: agent.permissionMode
                ?? (agent.capabilities.contains("Headless (no permission prompts)")
                    ? "Headless — pre-approved only" : "Unattended"),
            grantedTools: [],
            source: agent.sourcePath
        )
    }
}

// MARK: - Coverage Catalog

/// Hand-maintained declaration of what Vigil can check per tool, independent
/// of what's installed on this machine. Update when adapters gain capabilities;
/// a test asserts every registered adapter has an entry.
enum AdapterCoverageCatalog {

    static let all: [AdapterCoverage] = [
        AdapterCoverage(toolID: "claude-code", displayName: "Claude Code",
                        configReading: .full, sessionParsing: .full, riskDetection: .full,
                        mcpDiscovery: .full, permissionParsing: .full, scheduleDiscovery: .partial),
        AdapterCoverage(toolID: "claude-desktop", displayName: "Claude Desktop",
                        configReading: .partial, sessionParsing: .none, riskDetection: .partial,
                        mcpDiscovery: .full, permissionParsing: .none, scheduleDiscovery: .full),
        AdapterCoverage(toolID: "codex-cli", displayName: "Codex CLI",
                        configReading: .full, sessionParsing: .full, riskDetection: .full,
                        mcpDiscovery: .full, permissionParsing: .partial, scheduleDiscovery: .none),
        AdapterCoverage(toolID: "cursor", displayName: "Cursor",
                        configReading: .partial, sessionParsing: .none, riskDetection: .partial,
                        mcpDiscovery: .full, permissionParsing: .none, scheduleDiscovery: .none),
        AdapterCoverage(toolID: "github-copilot", displayName: "GitHub Copilot",
                        configReading: .partial, sessionParsing: .none, riskDetection: .none,
                        mcpDiscovery: .none, permissionParsing: .none, scheduleDiscovery: .none),
        AdapterCoverage(toolID: "windsurf", displayName: "Windsurf",
                        configReading: .partial, sessionParsing: .none, riskDetection: .none,
                        mcpDiscovery: .none, permissionParsing: .none, scheduleDiscovery: .none),
        AdapterCoverage(toolID: "aider", displayName: "Aider",
                        configReading: .partial, sessionParsing: .none, riskDetection: .none,
                        mcpDiscovery: .none, permissionParsing: .none, scheduleDiscovery: .none),
        AdapterCoverage(toolID: "cline-roo", displayName: "Cline / Roo Code",
                        configReading: .partial, sessionParsing: .none, riskDetection: .partial,
                        mcpDiscovery: .full, permissionParsing: .partial, scheduleDiscovery: .none),
        AdapterCoverage(toolID: "ollama", displayName: "Ollama",
                        configReading: .full, sessionParsing: .none, riskDetection: .partial,
                        mcpDiscovery: .none, permissionParsing: .none, scheduleDiscovery: .none),
        AdapterCoverage(toolID: "lm-studio", displayName: "LM Studio",
                        configReading: .none, sessionParsing: .none, riskDetection: .none,
                        mcpDiscovery: .none, permissionParsing: .none, scheduleDiscovery: .none),
        AdapterCoverage(toolID: "llama-cpp", displayName: "llama.cpp",
                        configReading: .none, sessionParsing: .none, riskDetection: .none,
                        mcpDiscovery: .none, permissionParsing: .none, scheduleDiscovery: .none),
        AdapterCoverage(toolID: "mlx", displayName: "MLX",
                        configReading: .none, sessionParsing: .none, riskDetection: .none,
                        mcpDiscovery: .none, permissionParsing: .none, scheduleDiscovery: .none),
        AdapterCoverage(toolID: "huggingface", displayName: "Hugging Face",
                        configReading: .none, sessionParsing: .none, riskDetection: .none,
                        mcpDiscovery: .none, permissionParsing: .none, scheduleDiscovery: .none),
        AdapterCoverage(toolID: "chatgpt", displayName: "ChatGPT",
                        configReading: .none, sessionParsing: .none, riskDetection: .none,
                        mcpDiscovery: .none, permissionParsing: .none, scheduleDiscovery: .none),
        AdapterCoverage(toolID: "gemini", displayName: "Gemini",
                        configReading: .none, sessionParsing: .none, riskDetection: .none,
                        mcpDiscovery: .none, permissionParsing: .none, scheduleDiscovery: .none),
        AdapterCoverage(toolID: "gemini-cli", displayName: "Gemini CLI",
                        configReading: .partial, sessionParsing: .none, riskDetection: .none,
                        mcpDiscovery: .none, permissionParsing: .none, scheduleDiscovery: .none),
        AdapterCoverage(toolID: "zed", displayName: "Zed",
                        configReading: .full, sessionParsing: .none, riskDetection: .partial,
                        mcpDiscovery: .full, permissionParsing: .none, scheduleDiscovery: .none),
        AdapterCoverage(toolID: "whisper", displayName: "Whisper",
                        configReading: .none, sessionParsing: .none, riskDetection: .none,
                        mcpDiscovery: .none, permissionParsing: .none, scheduleDiscovery: .none),
        AdapterCoverage(toolID: "stable-diffusion", displayName: "Stable Diffusion",
                        configReading: .none, sessionParsing: .none, riskDetection: .none,
                        mcpDiscovery: .none, permissionParsing: .none, scheduleDiscovery: .none),
    ]

    /// Coverage rows paired with whether the tool was actually found here.
    static func withPresence(configs: [AIToolConfig]) -> [(coverage: AdapterCoverage, present: Bool)] {
        let presentTools = Set(configs.map(\.tool))
        return all.map { coverage in
            (coverage, presentTools.contains(coverage.displayName))
        }
    }
}

// MARK: - Risk Surface Catalog

/// The honest visibility map: risk surfaces in the AI usage landscape,
/// including ones Vigil cannot see from host-side observation. Gaps name
/// the companion tool that covers (or would cover) them.
enum RiskSurfaceCatalog {

    static let all: [RiskSurface] = [
        RiskSurface(
            name: "Tool configs & permissions",
            detail: "Settings files, allow/deny lists, MCP configs, prompt surfaces",
            vigilCoverage: .full, companion: nil,
            notes: "19 adapters; depth varies by tool (see matrix above)"
        ),
        RiskSurface(
            name: "Agent session activity",
            detail: "What agents actually did: files touched, commands run, tools called",
            vigilCoverage: .partial, companion: nil,
            notes: "Full for Claude Code and Codex CLI; other tools lack parseable session logs"
        ),
        RiskSurface(
            name: "Unattended & scheduled agents",
            detail: "Cowork scheduled tasks, AI cron jobs, always-on agent daemons",
            vigilCoverage: .partial, companion: nil,
            notes: "Scheduled tasks and cron covered; agent daemons (OpenClaw etc.) on roadmap"
        ),
        RiskSurface(
            name: "macOS privacy grants",
            detail: "TCC permissions (screen recording, accessibility, full disk) held by AI apps",
            vigilCoverage: .full, companion: nil,
            notes: "Read from the TCC database plus LaunchAgent persistence scan"
        ),
        RiskSurface(
            name: "Process & file activity",
            detail: "Live process I/O, file events, model file detection",
            vigilCoverage: .full, companion: nil,
            notes: "libproc + FSEvents, user-space only"
        ),
        RiskSurface(
            name: "Browser AI usage",
            detail: "ChatGPT/Claude/Gemini used in a browser tab — including sensitive data pasted into them",
            vigilCoverage: .none, companion: "Prism",
            notes: "Invisible from the host: page content and form input never touch disk. Needs in-browser visibility."
        ),
        RiskSurface(
            name: "Network egress content",
            detail: "What actually leaves the machine when AI tools phone home",
            vigilCoverage: .none, companion: "Tapped",
            notes: "Vigil sees I/O volume per process, not destinations or payloads. Needs network-layer visibility."
        ),
        RiskSurface(
            name: "Clipboard flows",
            detail: "Secrets or sensitive text copied into AI apps or browser AI tools",
            vigilCoverage: .none, companion: "Prism",
            notes: "Clipboard monitoring requires its own consent-heavy observer; not host-file-observable"
        ),
        RiskSurface(
            name: "Cloud-side agent actions",
            detail: "What remote/cloud agents do off-machine (cloud Cowork runs, hosted agents)",
            vigilCoverage: .partial, companion: nil,
            notes: "Only what syncs back to disk (session files, audit logs); the cloud side is provider-territory"
        ),
        RiskSurface(
            name: "Config enforcement",
            detail: "Preventing risky configs rather than observing them",
            vigilCoverage: .none, companion: "Harden",
            notes: "Vigil observes and never blocks, by design. Enforcement is a separate tool's job."
        ),
    ]
}
