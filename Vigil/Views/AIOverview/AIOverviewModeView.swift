import SwiftUI

/// AI Overview: aggregate risk dashboard across all AI tools.
/// Answers "how is my AI security posture right now?"
struct AIOverviewModeView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var configs: [AIToolConfig] = []
    @State private var privacyPostures: [AIPrivacyPosture] = []
    @State private var riskSignals: [AISecuritySignal] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Scanning AI tools...")
                    .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 24) {
                    riskScoreHeader
                    if !riskSignals.isEmpty {
                        topRisksSection
                    }
                    HStack(alignment: .top, spacing: 16) {
                        toolsSummarySection
                        privacyPostureSection
                    }
                    configPostureSection
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        let (loadedConfigs, loadedPostures, loadedRisks) = await Task.detached {
            let c = AIAdapterRegistry.discoverAllConfigs()
            let p = MacOSPrivacyReader.readAll()
            var r = AIAdapterRegistry.detectAllRisks()
            r.append(contentsOf: AIRiskEngine.detectPrivacyRisks(postures: p))
            return (c, p, r)
        }.value
        configs = loadedConfigs
        privacyPostures = loadedPostures
        riskSignals = loadedRisks
        isLoading = false
    }

    // MARK: - Risk Score Header

    @ViewBuilder
    private var riskScoreHeader: some View {
        let warnings = riskSignals.filter { $0.severity == .warning }.count
        let concerns = riskSignals.filter { $0.severity == .concern }.count
        let level = warnings > 0 ? "Needs Attention" : concerns > 0 ? "Review Recommended" : "Healthy"
        let color: Color = warnings > 0 ? .red : concerns > 0 ? .orange : .green
        let icon = warnings > 0 ? "exclamationmark.shield" : concerns > 0 ? "shield.lefthalf.filled" : "checkmark.shield"

        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 4) {
                Text("AI Security Posture: \(level)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("\(configs.count) tool\(configs.count == 1 ? "" : "s") configured, \(riskSignals.count) signal\(riskSignals.count == 1 ? "" : "s") detected")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .background(color.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    // MARK: - Top Risks

    @ViewBuilder
    private var topRisksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Top Risk Signals")
                    .font(.headline)
                Spacer()
                Text("\(riskSignals.count) total")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            ForEach(riskSignals.filter { $0.severity >= .concern }.prefix(5)) { signal in
                HStack(spacing: 10) {
                    Image(systemName: signal.category.systemImage)
                        .foregroundStyle(signal.severity == .warning ? .red : .orange)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(signal.title)
                            .font(.callout)
                            .fontWeight(.medium)
                        Text(signal.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(10)
                .background(.background, in: .rect(cornerRadius: 8))
            }
        }
    }

    // MARK: - Tools Summary

    @ViewBuilder
    private var toolsSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain")
                    .foregroundStyle(.purple)
                Text("Configured Tools")
                    .font(.headline)
            }

            if configs.isEmpty {
                Text("No AI tool configurations found.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(configs, id: \.tool) { config in
                    HStack(spacing: 8) {
                        Text(config.tool)
                            .font(.callout)
                            .fontWeight(.medium)
                        Spacer()
                        if !config.mcpServers.isEmpty {
                            Label("\(config.mcpServers.count) MCP", systemImage: "server.rack")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if config.hasHooks {
                            Label("Hooks", systemImage: "link")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(config.layers.count) layers")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - Privacy Posture

    @ViewBuilder
    private var privacyPostureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.blue)
                Text("macOS Privacy")
                    .font(.headline)
            }

            if privacyPostures.isEmpty {
                Text("No AI tools found in TCC database.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(privacyPostures, id: \.toolID) { posture in
                    HStack(spacing: 8) {
                        Text(posture.displayName)
                            .font(.callout)
                            .fontWeight(.medium)
                        Spacer()
                        let granted = posture.grants.filter(\.granted)
                        ForEach(granted, id: \.service) { grant in
                            Image(systemName: grant.service.systemImage)
                                .font(.caption)
                                .foregroundStyle(grant.service.isElevated ? .red : .secondary)
                                .help(grant.service.displayName)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - Config Posture

    @ViewBuilder
    private var configPostureSection: some View {
        let totalMCP = configs.reduce(0) { $0 + $1.mcpServers.count }
        let totalHooks = configs.filter(\.hasHooks).count
        let totalPromptSurfaces = configs.reduce(0) { $0 + $1.promptSurfaces.count }

        if totalMCP > 0 || totalHooks > 0 || totalPromptSurfaces > 0 {
            HStack(spacing: 16) {
                StatCard(label: "MCP Servers", value: "\(totalMCP)", icon: "server.rack", color: .purple)
                StatCard(label: "Hooks", value: "\(totalHooks)", icon: "link", color: .orange)
                StatCard(label: "Prompt Surfaces", value: "\(totalPromptSurfaces)", icon: "doc.text", color: .blue)
                StatCard(label: "Config Layers", value: "\(configs.reduce(0) { $0 + $1.layers.count })", icon: "square.3.layers.3d", color: .green)
            }
        }
    }
}

// MARK: - Supporting Views

private struct StatCard: View {
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
