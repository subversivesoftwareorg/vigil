import SwiftUI

/// Custom About panel describing what Vigil does.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            // App identity
            VStack(spacing: 8) {
                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                Text("Vigil")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("A visual layer for what's happening on your Mac")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(versionString)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Divider()
                .padding(.horizontal, 24)

            // Description
            VStack(alignment: .leading, spacing: 12) {
                Text("Vigil monitors processes and file activity in real time, helping you understand what's running, how it behaves, and whether anything looks unusual.")
                    .font(.callout)

                Text("Think of it as a behavioral antivirus — it watches and reports, but never blocks. Vigil runs entirely in user space with no special permissions. All data stays on your Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 340)

            Divider()
                .padding(.horizontal, 24)

            // Modes
            VStack(alignment: .leading, spacing: 8) {
                modeRow(icon: "square.grid.2x2", color: .blue, name: "Overview",
                        desc: "Health at a glance")
                modeRow(icon: "cpu", color: .green, name: "Processes",
                        desc: "What's running and why")
                modeRow(icon: "doc.text.magnifyingglass", color: .purple, name: "File Activity",
                        desc: "What's happening on disk")
                modeRow(icon: "clock.arrow.circlepath", color: .orange, name: "History",
                        desc: "Trends and anomalies over time")
            }
            .frame(maxWidth: 340)

            Spacer()

            // Footer
            Text("Part of the Subversive Software family")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 400, height: 520)
    }

    @ViewBuilder
    private func modeRow(icon: String, color: Color, name: String, desc: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(name)
                .fontWeight(.medium)
            Text("— \(desc)")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}
