import SwiftUI

struct AIMCPSurfaceModeView: View {
    @State private var configs: [AIToolConfig] = []
    @State private var sessions: [AISessionLog] = []
    @State private var isLoading = true

    // MARK: - Computed Data

    private var serversByTool: [(tool: String, servers: [MCPServerDetail])] {
        var grouped: [(tool: String, servers: [MCPServerDetail])] = []
        for config in configs where !config.mcpServerDetails.isEmpty {
            grouped.append((tool: config.tool, servers: config.mcpServerDetails))
        }
        return grouped.sorted { $0.tool < $1.tool }
    }

    private var allMCPServers: [(tool: String, server: MCPServerDetail)] {
        configs.flatMap { config in
            config.mcpServerDetails.map { (tool: config.tool, server: $0) }
        }
    }

    private var mcpUsage: [String: MCPServerUsage] {
        var usage: [String: MCPServerUsage] = [:]
        for session in sessions {
            for call in session.mcpCalls {
                var entry = usage[call.serverName, default: MCPServerUsage()]
                entry.totalCalls += 1
                entry.toolCalls[call.toolName, default: 0] += 1
                entry.sessionIDs.insert(session.id)
                usage[call.serverName] = entry
            }
        }
        return usage
    }

    private var activeServerCount: Int {
        let activeNames = Set(sessions.flatMap { $0.mcpCalls.map(\.serverName) })
        return allMCPServers.filter { activeNames.contains($0.server.name) }.count
    }

    private var totalMCPCalls: Int {
        sessions.reduce(0) { $0 + $1.mcpCalls.count }
    }

    private var allPromptSurfaces: [(tool: String, surface: PromptSurface)] {
        configs.flatMap { config in
            config.promptSurfaces.map { (tool: config.tool, surface: $0) }
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Scanning configurations...")
                    .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 24) {
                    pageHeader
                    statsRow
                    mcpServersSection
                    promptSurfacesSection
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            let (c, s) = await Task.detached {
                (AIAdapterRegistry.discoverAllConfigs(), AIAdapterRegistry.parseAllSessions())
            }.value
            configs = c
            sessions = s
            isLoading = false
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var pageHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.title2)
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text("MCP Servers & Configuration")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Model Context Protocol servers configured across your AI tools")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Stats Row

    @ViewBuilder
    private var statsRow: some View {
        HStack(spacing: 16) {
            MCPStatCard(
                label: "MCP Servers",
                value: "\(allMCPServers.count)",
                icon: "server.rack",
                color: .purple
            )
            MCPStatCard(
                label: "Tools with MCP",
                value: "\(serversByTool.count)",
                icon: "brain",
                color: .blue
            )
            MCPStatCard(
                label: "Active Servers",
                value: "\(activeServerCount)",
                icon: "bolt.circle",
                color: activeServerCount > 0 ? .green : .secondary
            )
            MCPStatCard(
                label: "Total Calls",
                value: formatCount(totalMCPCalls),
                icon: "arrow.left.arrow.right",
                color: totalMCPCalls > 0 ? .orange : .secondary
            )
        }
    }

    // MARK: - MCP Servers (Grouped by Tool)

    @ViewBuilder
    private var mcpServersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundStyle(.blue)
                Text("MCP Servers")
                    .font(.headline)
            }

            if serversByTool.isEmpty {
                emptyState(
                    icon: "server.rack",
                    message: "No MCP servers configured across any AI tool."
                )
            } else {
                ForEach(serversByTool, id: \.tool) { group in
                    MCPToolGroup(
                        toolName: group.tool,
                        servers: group.servers,
                        usage: mcpUsage
                    )
                }
            }
        }
    }

    // MARK: - Prompt Surfaces

    @ViewBuilder
    private var promptSurfacesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.green)
                Text("Prompt Surfaces")
                    .font(.headline)
                Spacer()
                if !allPromptSurfaces.isEmpty {
                    Text("\(allPromptSurfaces.count)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.12), in: .capsule)
                        .foregroundStyle(.green)
                }
            }

            Text("Files that provide instructions to AI agents")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if allPromptSurfaces.isEmpty {
                emptyState(
                    icon: "doc.text",
                    message: "No prompt surface files found."
                )
            } else {
                ForEach(Array(allPromptSurfaces.enumerated()), id: \.offset) { _, entry in
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.caption)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.surface.type.rawValue)
                                .font(.callout)
                                .fontWeight(.medium)
                            Text(shortenPath(entry.surface.path))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Text(entry.tool)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.1), in: .capsule)
                        Text(entry.surface.scope)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .background(.background, in: .rect(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func emptyState(icon: String, message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}

// MARK: - MCP Server Usage

struct MCPServerUsage {
    var totalCalls: Int = 0
    var toolCalls: [String: Int] = [:]
    var sessionIDs: Set<String> = []
}

// MARK: - Tool Group (Collapsible)

private struct MCPToolGroup: View {
    let toolName: String
    let servers: [MCPServerDetail]
    let usage: [String: MCPServerUsage]

    @State private var isExpanded = true

    private var groupUsage: Int {
        servers.reduce(0) { $0 + (usage[$1.name]?.totalCalls ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    Text(toolName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(servers.count) server\(servers.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1), in: .capsule)
                        .foregroundStyle(.blue)
                    if groupUsage > 0 {
                        Text("\(groupUsage) call\(groupUsage == 1 ? "" : "s")")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.1), in: .capsule)
                            .foregroundStyle(.green)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(servers, id: \.name) { server in
                    MCPServerCard(
                        toolName: toolName,
                        server: server,
                        usage: usage[server.name]
                    )
                }
            }
        }
        .padding(12)
        .background(.secondary.opacity(0.04), in: .rect(cornerRadius: 12))
    }
}

// MARK: - MCP Server Card

private struct MCPServerCard: View {
    let toolName: String
    let server: MCPServerDetail
    let usage: MCPServerUsage?

    @State private var isExpanded = false

    private var riskBadges: [RiskBadge] {
        var badges: [RiskBadge] = []
        if !server.autoApprovedTools.isEmpty {
            badges.append(RiskBadge(label: "Auto-approved", icon: "bolt", color: .orange))
        }
        let riskyKeys = server.envVars.keys.filter { key in
            let k = key.uppercased()
            return k == "PATH" || k == "HOME" || k.hasPrefix("AWS_")
                || k.hasPrefix("GOOGLE_") || k.hasPrefix("AZURE_")
                || k == "GITHUB_TOKEN" || k == "NPM_TOKEN"
                || k == "OPENAI_API_KEY" || k == "ANTHROPIC_API_KEY"
        }
        if !riskyKeys.isEmpty {
            badges.append(RiskBadge(label: "Sensitive Env", icon: "key", color: .red))
        }
        if let cmd = server.command {
            if cmd.contains("npx ") && !cmd.contains("@") {
                badges.append(RiskBadge(label: "Unpinned", icon: "exclamationmark.triangle", color: .yellow))
            }
            if (cmd.contains("uvx ") || cmd.contains("pipx run ")) && !cmd.contains("==") {
                badges.append(RiskBadge(label: "Unpinned", icon: "exclamationmark.triangle", color: .yellow))
            }
        }
        return badges
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: name, badges, usage, expand button
            HStack(spacing: 8) {
                Image(systemName: usage != nil ? "server.rack" : "server.rack")
                    .font(.caption)
                    .foregroundStyle(usage != nil ? .green : .blue)
                Text(server.name)
                    .font(.callout)
                    .fontWeight(.medium)

                ForEach(riskBadges, id: \.label) { badge in
                    Label(badge.label, systemImage: badge.icon)
                        .font(.caption2)
                        .foregroundStyle(badge.color)
                }

                Spacer()

                if let usage {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.caption2)
                        Text("\(usage.totalCalls)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.green)
                    .help("\(usage.totalCalls) call(s) across \(usage.sessionIDs.count) session(s)")
                }

                Text(server.source)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Expanded detail
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    // Command
                    if let command = server.command {
                        detailRow(label: "Command", value: command, mono: true)
                    }

                    // Args
                    if !server.args.isEmpty {
                        detailRow(label: "Args", value: server.args.joined(separator: " "), mono: true)
                    }

                    // Environment variables
                    if !server.envVars.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Environment (\(server.envVars.count))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            ForEach(server.envVars.keys.sorted().prefix(8), id: \.self) { key in
                                HStack(spacing: 4) {
                                    let isRisky = isRiskyEnvVar(key)
                                    if isRisky {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                    Text("\(key)=\(maskValue(server.envVars[key] ?? ""))")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(isRisky ? .orange : .secondary)
                                        .lineLimit(1)
                                }
                            }
                            if server.envVars.count > 8 {
                                Text("... and \(server.envVars.count - 8) more")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    // Auto-approved tools
                    if !server.autoApprovedTools.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-approved Tools (\(server.autoApprovedTools.count))")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            FlowLayout(spacing: 4) {
                                ForEach(server.autoApprovedTools, id: \.self) { tool in
                                    Text(tool)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.orange.opacity(0.1), in: .capsule)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }

                    // Usage breakdown (tools called)
                    if let usage, !usage.toolCalls.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tool Usage")
                                .font(.caption)
                                .foregroundStyle(.green)
                            ForEach(usage.toolCalls.sorted(by: { $0.value > $1.value }), id: \.key) { tool, count in
                                HStack(spacing: 4) {
                                    Text(tool)
                                        .font(.system(.caption2, design: .monospaced))
                                    Spacer()
                                    Text("\(count)")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .monospacedDigit()
                                }
                                .foregroundStyle(.secondary)
                            }
                            Text("\(usage.sessionIDs.count) session\(usage.sessionIDs.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(.background, in: .rect(cornerRadius: 10))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    @ViewBuilder
    private func detailRow(label: String, value: String, mono: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text("\(label):")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 65, alignment: .trailing)
            if mono {
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .textSelection(.enabled)
            } else {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    private func isRiskyEnvVar(_ key: String) -> Bool {
        let k = key.uppercased()
        return k == "PATH" || k == "HOME" || k.hasPrefix("AWS_")
            || k.hasPrefix("GOOGLE_") || k.hasPrefix("AZURE_")
            || k == "GITHUB_TOKEN" || k == "NPM_TOKEN"
            || k == "OPENAI_API_KEY" || k == "ANTHROPIC_API_KEY"
    }

    private func maskValue(_ value: String) -> String {
        guard value.count > 8 else { return value }
        return String(value.prefix(4)) + "****"
    }
}

// MARK: - Risk Badge

private struct RiskBadge {
    let label: String
    let icon: String
    let color: Color
}

// MARK: - Stat Card

private struct MCPStatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
