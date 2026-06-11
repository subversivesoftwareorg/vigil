import SwiftUI

/// Permissions Matrix: table showing AI tool capabilities at a glance.
/// Rows = tools, columns = permission categories.
struct AIPermissionsMatrixView: View {
    @State private var configs: [AIToolConfig] = []
    @State private var privacyPostures: [AIPrivacyPosture] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading permissions...")
                    .frame(maxHeight: .infinity)
            } else if configs.isEmpty {
                ContentUnavailableView(
                    "No AI Tools Configured",
                    systemImage: "lock.shield",
                    description: Text("Install and configure AI tools to see their permission matrix.")
                )
            } else {
                VStack(spacing: 20) {
                    matrixHeader
                    ForEach(configs, id: \.tool) { config in
                        toolPermissionRow(config)
                    }
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            configs = AIAdapterRegistry.discoverAllConfigs()
            privacyPostures = MacOSPrivacyReader.readAll()
            isLoading = false
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var matrixHeader: some View {
        HStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Permissions Matrix")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Capabilities granted to each AI tool on this system")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.bottom, 8)
    }

    // MARK: - Tool Row

    @ViewBuilder
    private func toolPermissionRow(_ config: AIToolConfig) -> some View {
        let posture = privacyPostures.first { $0.displayName == config.tool }

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(config.tool)
                    .font(.headline)
                Text(config.provider)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(config.layers.count) config layers")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()),
                GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()),
            ], spacing: 8) {
                permissionCell(
                    "Shell",
                    icon: "terminal",
                    status: shellStatus(config)
                )
                permissionCell(
                    "Write",
                    icon: "square.and.pencil",
                    status: writeStatus(config)
                )
                permissionCell(
                    "Network",
                    icon: "network",
                    status: networkStatus(config)
                )
                permissionCell(
                    "MCP",
                    icon: "server.rack",
                    status: mcpStatus(config)
                )
                permissionCell(
                    "Hooks",
                    icon: "link",
                    status: config.hasHooks ? .active : .inactive
                )
                permissionCell(
                    "Auto",
                    icon: "bolt",
                    status: config.autoMode ? .warning : .inactive
                )
            }

            // macOS privacy grants
            if let posture, !posture.grants.isEmpty {
                HStack(spacing: 12) {
                    Text("macOS:")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    ForEach(posture.grants.filter(\.granted), id: \.service) { grant in
                        HStack(spacing: 3) {
                            Image(systemName: grant.service.systemImage)
                                .font(.caption2)
                            Text(grant.service.displayName)
                                .font(.caption2)
                        }
                        .foregroundStyle(grant.service.isElevated ? .red : .secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - Permission Cell

    private enum PermStatus {
        case active, partial, warning, inactive, unknown
    }

    @ViewBuilder
    private func permissionCell(_ label: String, icon: String, status: PermStatus) -> some View {
        let (color, bgColor): (Color, Color) = switch status {
        case .active: (.green, .green.opacity(0.1))
        case .partial: (.yellow, .yellow.opacity(0.1))
        case .warning: (.red, .red.opacity(0.1))
        case .inactive: (.secondary.opacity(0.4), .secondary.opacity(0.05))
        case .unknown: (.secondary.opacity(0.3), .clear)
        }

        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(bgColor, in: .rect(cornerRadius: 6))
    }

    // MARK: - Status Helpers

    private func shellStatus(_ config: AIToolConfig) -> PermStatus {
        let hasShell = config.permissions.allowed.contains { $0.category == "Shell Commands" }
        let deniedShell = config.permissions.denied.contains { $0.category == "Shell Commands" }
        if hasShell { return .active }
        if deniedShell { return .inactive }
        let askShell = config.permissions.requiresApproval.contains { $0.category == "Shell Commands" }
        return askShell ? .partial : .unknown
    }

    private func writeStatus(_ config: AIToolConfig) -> PermStatus {
        let hasWrite = config.permissions.allowed.contains { $0.category == "File Writing" }
        return hasWrite ? .active : .unknown
    }

    private func networkStatus(_ config: AIToolConfig) -> PermStatus {
        let hasWeb = config.permissions.allowed.contains { $0.category == "Web Access" }
        if hasWeb { return .active }
        if let net = config.networkAccess { return net ? .active : .inactive }
        return .unknown
    }

    private func mcpStatus(_ config: AIToolConfig) -> PermStatus {
        if config.mcpServers.isEmpty { return .inactive }
        let hasAutoApproved = config.mcpServerDetails.contains { !$0.autoApprovedTools.isEmpty }
        return hasAutoApproved ? .warning : .active
    }
}
