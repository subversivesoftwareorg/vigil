import SwiftUI

/// Simple mode: clean, glanceable overview for non-technical users.
struct SimpleModeView: View {
    @Environment(MonitoringStore.self) private var store

    var body: some View {
        VStack(spacing: 20) {
            if store.processes.isEmpty {
                ContentUnavailableView(
                    "Starting Up",
                    systemImage: "gauge.with.dots.needle.bottom.50percent",
                    description: Text("Gathering process information...")
                )
            } else {
                Text("\(store.processes.count) processes running")
                    .font(.largeTitle)
                    .fontWeight(.medium)

                Text("\(store.fileEvents.count) file events observed")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
