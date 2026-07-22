import SwiftUI
import SpriteKit

struct GlanceView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var configs: [AIToolConfig] = []
    @State private var riskSignals: [AISecuritySignal] = []
    @State private var scanPhase: ScanPhase = .idle
    @State private var lastFound: String = ""
    @State private var selectedOrbID: String = ""
    @State private var scene: VigilOrbScene = {
        let s = VigilOrbScene(size: CGSize(width: 800, height: 500))
        s.backgroundColor = .clear
        s.scaleMode = .resizeFill
        return s
    }()

    enum ScanPhase: Equatable {
        case idle
        case scanning(current: String, done: Int, total: Int)
        case complete
    }

    // MARK: - Computed

    private var overallRisk: OrbData.RiskLevel {
        let warnings = riskSignals.filter { $0.severity == .warning }.count
        let concerns = riskSignals.filter { $0.severity == .concern }.count
        if warnings > 0 { return .warning }
        if concerns > 0 { return .concern }
        if !riskSignals.isEmpty { return .info }
        return .healthy
    }

    private var statusMessage: String {
        switch scanPhase {
        case .idle:
            return "Preparing scan..."
        case .scanning(let current, let done, let total):
            if current.isEmpty { return "Scanning your system..." }
            return "Checking \(current)... (\(done) of \(total))"
        case .complete:
            let warnings = riskSignals.filter { $0.severity == .warning }.count
            let concerns = riskSignals.filter { $0.severity == .concern }.count
            if warnings > 0 {
                return "\(warnings) issue\(warnings == 1 ? "" : "s") need\(warnings == 1 ? "s" : "") your attention."
            }
            if concerns > 0 {
                return "\(concerns) thing\(concerns == 1 ? "" : "s") worth reviewing."
            }
            if configs.isEmpty {
                return "No AI tools detected — Vigil watches for \(AIAdapterRegistry.adapters.count) of them."
            }
            return "Your AI tools look healthy."
        }
    }

    private var statusColor: Color {
        if case .scanning = scanPhase { return .teal }
        if case .idle = scanPhase { return .teal }
        switch overallRisk {
        case .healthy: return .green
        case .info: return .blue
        case .concern: return .orange
        case .warning: return .red
        }
    }

    private var isScanning: Bool {
        if case .scanning = scanPhase { return true }
        if case .idle = scanPhase { return true }
        return false
    }

    private var actionCards: [ActionCard] {
        riskSignals
            .filter { $0.severity >= .concern }
            .prefix(3)
            .map { signal in
                ActionCard(
                    id: signal.id.uuidString,
                    what: signal.title,
                    why: signal.detail,
                    action: remediation(for: signal),
                    severity: signal.severity,
                    category: signal.category
                )
            }
    }

    private var selectedOrbDetail: (name: String, detail: String)? {
        guard !selectedOrbID.isEmpty else { return nil }

        if let config = configs.first(where: { orbID(for: $0) == selectedOrbID }) {
            let mcpCount = config.mcpServerDetails.count
            let signals = riskSignals.filter { relatedToTool($0, config) }.count
            var detail = config.summary.prefix(2).joined(separator: ". ")
            if mcpCount > 0 { detail += ". \(mcpCount) MCP server\(mcpCount == 1 ? "" : "s")" }
            if signals > 0 { detail += ". \(signals) risk signal\(signals == 1 ? "" : "s")" }
            return (name: config.tool, detail: detail.isEmpty ? "No additional details." : detail)
        }

        for config in configs {
            if let server = config.mcpServerDetails.first(where: { satelliteID(for: $0, tool: config.tool) == selectedOrbID }) {
                var parts: [String] = []
                if let cmd = server.command { parts.append("Command: \(cmd)") }
                if !server.autoApprovedTools.isEmpty { parts.append("\(server.autoApprovedTools.count) auto-approved tools") }
                if !server.envVars.isEmpty { parts.append("\(server.envVars.count) env vars") }
                parts.append("Source: \(server.source)")
                return (name: "\(server.name) (\(config.tool))", detail: parts.joined(separator: " \u{2022} "))
            }
        }

        return nil
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.06), Color(white: 0.1)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                statusBanner
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                ZStack {
                    SpriteView(scene: scene, options: [.allowsTransparency])
                        .ignoresSafeArea()

                    if let detail = selectedOrbDetail {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(detail.name)
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            Text(detail.detail)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(3)
                        }
                        .padding(12)
                        .frame(maxWidth: 320, alignment: .leading)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(16)
                        .transition(.opacity)
                    }
                }

                if scanPhase == .complete && !actionCards.isEmpty {
                    actionCardsSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Status Banner

    @ViewBuilder
    private var statusBanner: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .shadow(color: statusColor.opacity(0.6), radius: 6)
                .modifier(PulseWhileScanning(active: isScanning))

            Text(statusMessage)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: statusMessage)

            Spacer()

            if isScanning {
                if !lastFound.isEmpty {
                    Text("Found \(lastFound)")
                        .font(.caption)
                        .foregroundStyle(.teal)
                        .transition(.opacity)
                }
            } else {
                Text("\(configs.count) tool\(configs.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(statusColor.opacity(0.12), in: .rect(cornerRadius: 12))
    }

    // MARK: - Action Cards

    @ViewBuilder
    private var actionCardsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(actionCards, id: \.id) { card in
                HStack(spacing: 12) {
                    Image(systemName: card.category.systemImage)
                        .font(.title3)
                        .foregroundStyle(card.severity == .warning ? .red : .orange)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.what)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                        Text(card.why)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(2)
                    }

                    Spacer()

                    Text(card.action)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.1), in: .capsule)
                }
                .padding(12)
                .background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard scanPhase == .idle else { return }

        scene.onOrbSelected = { id in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedOrbID = id
            }
        }

        // Warm cache: load instantly, orbs arrive with a light stagger
        if AIAdapterRegistry.hasFreshCache {
            let (loadedConfigs, loadedRisks) = await Task.detached {
                (AIAdapterRegistry.discoverAllConfigs(), AIAdapterRegistry.detectAllRisks())
            }.value
            configs = loadedConfigs
            riskSignals = loadedRisks
            scene.setOrbs(loadedConfigs.map { makeOrb($0, risks: loadedRisks) })
            scanPhase = .complete
            return
        }

        // Cold cache: the scan is the show
        scanPhase = .scanning(current: "", done: 0, total: AIAdapterRegistry.adapters.count)
        scene.beginScanEffect()

        for await event in AIAdapterRegistry.scanWithProgress() {
            switch event {
            case .checking(let toolName, let index, let total):
                scanPhase = .scanning(current: toolName, done: index, total: total)

            case .toolFound(let config, let sessionCount):
                configs.append(config)
                withAnimation {
                    lastFound = sessionCount > 0
                        ? "\(config.tool) · \(sessionCount) session\(sessionCount == 1 ? "" : "s")"
                        : config.tool
                }
                // Provisional neutral color; recolored when risks land
                scene.addOrb(makeOrb(config, risks: nil))

            case .toolAbsent:
                break

            case .finished(let allConfigs, let risks):
                configs = allConfigs
                riskSignals = risks
                scene.endScanEffect()
                for config in allConfigs {
                    scene.updateRisk(
                        id: orbID(for: config),
                        risk: riskLevel(for: config, risks: risks)
                    )
                }
                withAnimation { scanPhase = .complete }
            }
        }
    }

    // MARK: - Orb Building

    private func riskLevel(for config: AIToolConfig, risks: [AISecuritySignal]) -> OrbData.RiskLevel {
        let toolSignals = risks.filter { relatedToTool($0, config) }
        switch toolSignals.map(\.severity).max() {
        case .warning: return .warning
        case .concern: return .concern
        case .info: return .info
        default: return .healthy
        }
    }

    /// Build orb data for a config. Pass `risks: nil` while a scan is in
    /// flight — the orb spawns in a neutral color and is recolored when
    /// final risk levels arrive.
    private func makeOrb(_ config: AIToolConfig, risks: [AISecuritySignal]?) -> OrbData {
        let risk: OrbData.RiskLevel = risks.map { riskLevel(for: config, risks: $0) } ?? .info

        let mcpCount = config.mcpServerDetails.count
        let activity = min(1.0, Double(mcpCount + config.layers.count) / 8.0)

        let satellites = config.mcpServerDetails.map { server in
            let serverHasRisk = (risks ?? []).contains { signal in
                signal.category == .mcpRisk && signal.detail.contains(server.name)
            }
            return SatelliteData(
                id: satelliteID(for: server, tool: config.tool),
                label: abbreviate(server.name),
                hasRisk: serverHasRisk || !server.autoApprovedTools.isEmpty
            )
        }

        return OrbData(
            id: orbID(for: config),
            label: abbreviate(config.tool),
            risk: risk,
            activity: activity,
            satellites: satellites
        )
    }

    // MARK: - Helpers

    private func orbID(for config: AIToolConfig) -> String {
        "tool-\(config.tool.lowercased().replacingOccurrences(of: " ", with: "-"))"
    }

    private func satelliteID(for server: MCPServerDetail, tool: String) -> String {
        "mcp-\(tool.lowercased().replacingOccurrences(of: " ", with: "-"))-\(server.name)"
    }

    private func relatedToTool(_ signal: AISecuritySignal, _ config: AIToolConfig) -> Bool {
        signal.detail.contains(config.tool)
            || config.mcpServerDetails.contains { signal.detail.contains($0.name) }
    }

    private func abbreviate(_ name: String) -> String {
        if name.count <= 12 { return name }
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return words.map { String($0.prefix(1)) }.joined()
        }
        return String(name.prefix(10))
    }

    private func remediation(for signal: AISecuritySignal) -> String {
        switch signal.category {
        case .mcpRisk:
            if signal.title.contains("unpinned") { return "Pin version" }
            if signal.title.contains("env var") { return "Review env" }
            if signal.title.contains("auto-approved") { return "Review tools" }
            return "Review config"
        case .excessiveAgency: return "Reduce permissions"
        case .sensitiveFileAccess: return "Review access"
        case .suspiciousBash: return "Review command"
        case .exfiltration: return "Review network"
        case .toolShadowing: return "Rename server"
        case .toolCombination: return "Review session"
        case .configDrift: return "Review changes"
        case .toolDescriptionInjection: return "Inspect tool"
        case .crossServerFlow: return "Review flow"
        case .supplyChain: return "Pin versions"
        default: return "Review"
        }
    }
}

// MARK: - Pulse Modifier

/// Gentle opacity pulse on the status dot while scanning.
private struct PulseWhileScanning: ViewModifier {
    let active: Bool
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(active && dimmed ? 0.35 : 1.0)
            .animation(
                active ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default,
                value: dimmed
            )
            .onAppear { if active { dimmed = true } }
            .onChange(of: active) { _, isActive in
                dimmed = isActive
            }
    }
}

// MARK: - Action Card Model

private struct ActionCard {
    let id: String
    let what: String
    let why: String
    let action: String
    let severity: SignalSeverity
    let category: SignalCategory
}
