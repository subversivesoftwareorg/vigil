import SwiftUI

/// MCP & Prompt Surface: inventory of all MCP servers and prompt rule files across AI tools.
struct AIMCPSurfaceModeView: View {
    @State private var configs: [AIToolConfig] = []
    @State private var isLoading = true

    private var allMCPServers: [(tool: String, server: MCPServerDetail)] {
        configs.flatMap { config in
            config.mcpServerDetails.map { (tool: config.tool, server: $0) }
        }
    }

    private var allPromptSurfaces: [(tool: String, surface: PromptSurface)] {
        configs.flatMap { config in
            config.promptSurfaces.map { (tool: config.tool, surface: $0) }
        }
    }

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Scanning configurations...")
                    .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 24) {
                    pageHeader
                    mcpServersSection
                    promptSurfacesSection
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            configs = AIAdapterRegistry.discoverAllConfigs()
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
                Text("MCP Servers & Prompt Surfaces")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("\(allMCPServers.count) server\(allMCPServers.count == 1 ? "" : "s"), \(allPromptSurfaces.count) prompt surface\(allPromptSurfaces.count == 1 ? "" : "s")")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - MCP Servers

    @ViewBuilder
    private var mcpServersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundStyle(.blue)
                Text("MCP Servers")
                    .font(.headline)
            }

            if allMCPServers.isEmpty {
                Text("No MCP servers configured across any AI tool.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(allMCPServers.enumerated()), id: \.offset) { _, entry in
                    MCPServerCard(toolName: entry.tool, server: entry.server)
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
            }

            Text("Files that provide instructions to AI agents")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if allPromptSurfaces.isEmpty {
                Text("No prompt surface files found.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
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

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }
}

// MARK: - MCP Server Card

private struct MCPServerCard: View {
    let toolName: String
    let server: MCPServerDetail

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text(server.name)
                    .font(.callout)
                    .fontWeight(.medium)
                Spacer()
                Text(toolName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.1), in: .capsule)
                if !server.autoApprovedTools.isEmpty {
                    Label("Auto-approved", systemImage: "bolt")
                        .font(.caption2)
                        .foregroundStyle(.orange)
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

            if isExpanded {
                Divider()
                if let command = server.command {
                    HStack(spacing: 4) {
                        Text("Command:")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(command)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                if !server.args.isEmpty {
                    HStack(spacing: 4) {
                        Text("Args:")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(server.args.joined(separator: " "))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                if !server.envVars.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Environment (\(server.envVars.count)):")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        ForEach(server.envVars.keys.sorted().prefix(8), id: \.self) { key in
                            Text("\(key)=\(server.envVars[key] ?? "")")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                if !server.autoApprovedTools.isEmpty {
                    HStack(spacing: 4) {
                        Text("Auto-approved:")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(server.autoApprovedTools.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(12)
        .background(.background, in: .rect(cornerRadius: 10))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }
}
