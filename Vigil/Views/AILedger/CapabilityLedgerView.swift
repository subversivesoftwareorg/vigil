import SwiftUI

/// Capability Ledger: every principal that can act on this machine — tools,
/// MCP servers, scheduled tasks, cron jobs — and what each is allowed to do.
/// Includes the coverage matrix: what Vigil can check per tool, regardless of
/// what's installed here.
struct CapabilityLedgerView: View {
    @State private var entries: [LedgerEntry] = []
    @State private var coverage: [(coverage: AdapterCoverage, present: Bool)] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Building ledger...")
                    .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 24) {
                    pageHeader
                    ForEach(LedgerEntry.PrincipalKind.allCases, id: \.self) { kind in
                        let kindEntries = entries.filter { $0.kind == kind }
                        if !kindEntries.isEmpty {
                            ledgerSection(kind: kind, entries: kindEntries)
                        }
                    }
                    coverageMatrixSection
                    visibilityMapSection
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            let (loadedEntries, loadedCoverage) = await Task.detached {
                let configs = AIAdapterRegistry.discoverAllConfigs()
                let agents = UnattendedAgentScanner.scanAll()
                let ledger = CapabilityLedgerBuilder.build(configs: configs, agents: agents)
                let cov = AdapterCoverageCatalog.withPresence(configs: configs)
                return (ledger, cov)
            }.value
            entries = loadedEntries
            coverage = loadedCoverage
            isLoading = false
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var pageHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "tablecells")
                .font(.title2)
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text("Capability Ledger")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("What is allowed to act on this Mac, when, and with what scope")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(entries.count) principal\(entries.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Ledger Sections

    @ViewBuilder
    private func ledgerSection(kind: LedgerEntry.PrincipalKind, entries: [LedgerEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: kind.systemImage)
                    .foregroundStyle(.indigo)
                Text(kind.displayName)
                    .font(.headline)
                Spacer()
                Text("\(entries.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            ForEach(entries) { entry in
                LedgerEntryRow(entry: entry)
            }
        }
    }

    // MARK: - Coverage Matrix

    @ViewBuilder
    private var coverageMatrixSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.teal)
                Text("Check Coverage")
                    .font(.headline)
                Spacer()
                legend
            }
            Text("What Vigil can check for each tool — including tools not installed on this Mac")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Tool")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .gridColumnAlignment(.leading)
                    ForEach(AdapterCoverage.dimensionLabels, id: \.self) { label in
                        Text(label)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .gridColumnAlignment(.center)
                    }
                    Text("Here")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .gridColumnAlignment(.center)
                }

                Divider()

                ForEach(coverage, id: \.coverage.id) { row in
                    GridRow {
                        Text(row.coverage.displayName)
                            .font(.callout)
                            .foregroundStyle(row.present ? .primary : .secondary)
                        ForEach(Array(row.coverage.levels.enumerated()), id: \.offset) { _, level in
                            coverageDot(level)
                        }
                        if row.present {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text("—")
                                .font(.caption)
                                .foregroundStyle(.quaternary)
                        }
                    }
                }
            }
            .padding(16)
            .background(.background, in: .rect(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
        }
    }

    // MARK: - Visibility Map

    @ViewBuilder
    private var visibilityMapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye.trianglebadge.exclamationmark")
                    .foregroundStyle(.purple)
                Text("Visibility Map")
                    .font(.headline)
            }
            Text("Risk surfaces across the AI landscape — including what Vigil cannot see. Full visibility takes a combination of tools.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            ForEach(RiskSurfaceCatalog.all) { surface in
                HStack(alignment: .top, spacing: 12) {
                    coverageDot(surface.vigilCoverage)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(surface.name)
                                .font(.callout)
                                .fontWeight(.medium)
                            if let companion = surface.companion {
                                Text("→ \(companion)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.purple.opacity(0.1), in: .capsule)
                                    .foregroundStyle(.purple)
                                    .help("Gap covered by a companion tool")
                            }
                        }
                        Text(surface.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(surface.notes)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text(surface.vigilCoverage == .none ? "Blind spot" : surface.vigilCoverage.label)
                        .font(.caption2)
                        .foregroundStyle(surface.vigilCoverage == .none ? .orange : .secondary)
                }
                .padding(10)
                .background(.background, in: .rect(cornerRadius: 8))
            }
        }
    }

    @ViewBuilder
    private func coverageDot(_ level: CoverageLevel) -> some View {
        Circle()
            .fill(color(for: level))
            .frame(width: 10, height: 10)
            .help(level.label)
    }

    private func color(for level: CoverageLevel) -> Color {
        switch level {
        case .full: .green
        case .partial: .yellow
        case .none: Color.secondary.opacity(0.2)
        }
    }

    @ViewBuilder
    private var legend: some View {
        HStack(spacing: 10) {
            ForEach([CoverageLevel.full, .partial, .none], id: \.self) { level in
                HStack(spacing: 4) {
                    Circle().fill(color(for: level)).frame(width: 8, height: 8)
                    Text(level.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Ledger Entry Row

private struct LedgerEntryRow: View {
    let entry: LedgerEntry
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(entry.name)
                    .font(.callout)
                    .fontWeight(.medium)
                if let parent = entry.parent {
                    Text(parent)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.1), in: .capsule)
                }
                if let schedule = entry.schedule {
                    Label(schedule, systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.indigo)
                }
                Spacer()

                accessBadge("Shell", entry.shellAccess)
                accessBadge("Network", entry.networkAccess)

                Text(entry.approvalMode)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

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
                VStack(alignment: .leading, spacing: 4) {
                    if !entry.fileScope.isEmpty {
                        detailLine("File scope", entry.fileScope.joined(separator: ", "))
                    }
                    if !entry.browserDomains.isEmpty {
                        detailLine("Browser", entry.browserDomains.joined(separator: ", "))
                    }
                    if !entry.grantedTools.isEmpty {
                        detailLine("Granted tools (\(entry.grantedTools.count))",
                                   entry.grantedTools.prefix(12).joined(separator: ", ")
                                   + (entry.grantedTools.count > 12 ? ", ..." : ""))
                    }
                    detailLine("Source", shortenPath(entry.source))
                }
            }
        }
        .padding(12)
        .background(.background, in: .rect(cornerRadius: 10))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    @ViewBuilder
    private func accessBadge(_ label: String, _ level: LedgerEntry.AccessLevel) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(badgeColor(level))
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .help("\(label): \(level.label)")
    }

    private func badgeColor(_ level: LedgerEntry.AccessLevel) -> Color {
        switch level {
        case .granted: .green
        case .requiresApproval: .yellow
        case .denied: .red
        case .unknown: Color.secondary.opacity(0.3)
        }
    }

    @ViewBuilder
    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text("\(label):")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }
}
