import SwiftUI

/// An expandable card showing a single heuristic finding with severity, description,
/// and recommendation.
struct FindingCard: View {
    let finding: Finding
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: severityIcon)
                        .foregroundStyle(severityColor)
                        .font(.title3)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(finding.title)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Text(finding.description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(.yellow)
                        Text("Recommendation")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    Text(finding.recommendation)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if let pid = finding.affectedPid {
                        HStack {
                            Text("Process: \(finding.affectedProcess)")
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("PID \(pid)")
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }
                }
                .padding(.leading, 34)
            }
        }
        .padding(16)
        .background(severityColor.opacity(0.04), in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(severityColor.opacity(0.15), lineWidth: 1)
        )
    }

    private var severityIcon: String {
        switch finding.severity {
        case .critical: "exclamationmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    var severityColor: Color {
        switch finding.severity {
        case .critical: .red
        case .warning: .orange
        case .info: .blue
        }
    }
}
