import SwiftUI

/// AI Inventory: a persistent catalog of all AI tools observed on this system.
/// Unlike AI Activity (which shows real-time state), the inventory persists across
/// sessions — recording first/last seen dates, observation counts, and evidence.
struct AIInventoryModeView: View {
    @Environment(MonitoringStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryHeader
                if sortedEntries.isEmpty {
                    emptyState
                } else {
                    inventoryList
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            // Record configured tools so they appear in the inventory
            // even when the AI process isn't running
            for config in AISettingsReader.discoverAll() {
                store.recordConfiguredTool(config)
            }
        }
    }

    // MARK: - Data

    private var sortedEntries: [AIInventoryEntry] {
        store.aiInventory.values.sorted { $0.lastSeen > $1.lastSeen }
    }

    // MARK: - Summary Header

    @ViewBuilder
    private var summaryHeader: some View {
        HStack(spacing: 24) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 36))
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 4) {
                Text("AI Inventory")
                    .font(.title2)
                    .fontWeight(.bold)
                if sortedEntries.isEmpty {
                    Text("No AI tools observed yet. Vigil will catalog tools as it detects processes, file activity, and configuration files.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(sortedEntries.count) AI tool\(sortedEntries.count == 1 ? "" : "s") observed on this system")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Watching for AI tools...")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Run an AI coding assistant, chat app, or local model and it will appear here automatically.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .padding(40)
    }

    // MARK: - Inventory List

    @ViewBuilder
    private var inventoryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(sortedEntries) { entry in
                AIInventoryCard(entry: entry, isActive: isCurrentlyActive(entry))
            }
        }
    }

    private func isCurrentlyActive(_ entry: AIInventoryEntry) -> Bool {
        store.processes.contains { process in
            AIProcessCatalog.match(process.displayName)?.entry.displayName == entry.displayName
        }
    }
}

// MARK: - Inventory Card

private struct AIInventoryCard: View {
    let entry: AIInventoryEntry
    let isActive: Bool
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: categoryIcon)
                        .foregroundStyle(.cyan)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(entry.displayName)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            if !entry.provider.isEmpty {
                                Text("· \(entry.provider)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            evidenceBadge
                            if isActive {
                                activeBadge
                            }
                        }
                        Text(entry.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)

            // Summary line
            HStack(spacing: 16) {
                dateLabel("First seen", date: entry.firstSeen)
                dateLabel("Last seen", date: entry.lastSeen)
                countLabel
            }

            // Expanded detail
            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    if !entry.processNames.isEmpty {
                        detailRow("Process names", value: entry.processNames.sorted().joined(separator: ", "))
                    }

                    detailRow("Evidence", value: entry.lastReason)

                    detailRow("Observations", value: "\(entry.observationCount) monitoring cycles")
                }
            }
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? .cyan.opacity(0.4) : .clear, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var evidenceBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: basisIcon)
                .font(.caption2)
            Text(basisLabel)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(confidenceColor.opacity(0.15), in: .capsule)
        .foregroundStyle(confidenceColor)
        .help(entry.lastReason)
    }

    @ViewBuilder
    private var activeBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(.green)
                .frame(width: 6, height: 6)
            Text("Active")
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.green.opacity(0.15), in: .capsule)
        .foregroundStyle(.green)
    }

    @ViewBuilder
    private func dateLabel(_ label: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(date, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var countLabel: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Observations")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text("\(entry.observationCount)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)
                .frame(width: 110, alignment: .trailing)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Display Helpers

    private var categoryIcon: String {
        switch entry.category {
        case "Coding Assistant": "chevron.left.forwardslash.chevron.right"
        case "Chat / Desktop App": "bubble.left.and.bubble.right"
        case "Local Model Runner": "cpu"
        case "Configured": "gearshape"
        default: "brain"
        }
    }

    private var basisIcon: String {
        switch entry.bestBasis {
        case .observed: "eye.fill"
        case .inferred: "questionmark.diamond"
        case .configured: "gearshape.fill"
        }
    }

    private var basisLabel: String {
        switch (entry.bestBasis, entry.highestConfidence) {
        case (.observed, .high): "Observed"
        case (.observed, _): "Possible"
        case (.configured, _): "Configured"
        case (.inferred, .high): "Likely"
        case (.inferred, _): "Possible"
        }
    }

    private var confidenceColor: Color {
        switch entry.highestConfidence {
        case .high: .green
        case .medium: .yellow
        case .low: .orange
        }
    }
}
