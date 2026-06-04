import SwiftUI

/// The root view for the Vigil window.
/// Provides mode switching between the four visualization modes.
struct MainWindowView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var selectedMode: ViewMode = .overview

    var body: some View {
        NavigationSplitView {
            List(ViewMode.allCases, selection: $selectedMode) { mode in
                Label(mode.displayName, systemImage: mode.systemImage)
                    .tag(mode)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch selectedMode {
            case .overview:
                OverviewModeView()
            case .processes:
                ProcessesModeView()
            case .fileActivity:
                FileActivityModeView()
            case .history:
                HistoryModeView()
            case .aiActivity:
                AIActivityModeView()
            case .aiInventory:
                AIInventoryModeView()
            case .aiSecurity:
                AISecurityModeView()
            case .aiLogs:
                AILogsModeView()
            case .fileSharing:
                FileSharingModeView()
            }
        }
        .navigationTitle("Vigil")
        .task {
            let processMonitor = ProcessMonitor()
            let fileMonitor = FileMonitor()
            let database = try? Database()
            store.configure(processSource: processMonitor, fileSource: fileMonitor,
                            database: database)
            await store.startMonitoring()
        }
    }
}

// MARK: - View Mode

enum ViewMode: String, CaseIterable, Identifiable {
    case overview
    case processes
    case fileActivity
    case aiActivity
    case aiInventory
    case aiSecurity
    case aiLogs
    case fileSharing
    case history

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .overview: "Overview"
        case .processes: "Processes"
        case .fileActivity: "File Activity"
        case .aiActivity: "AI Activity"
        case .aiInventory: "AI Inventory"
        case .aiSecurity: "AI Security"
        case .aiLogs: "AI Logs"
        case .fileSharing: "File Sharing"
        case .history: "History"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .processes: "cpu"
        case .fileActivity: "doc.text.magnifyingglass"
        case .aiActivity: "brain"
        case .aiInventory: "list.bullet.clipboard"
        case .aiSecurity: "shield.lefthalf.filled.badge.checkmark"
        case .aiLogs: "doc.text.magnifyingglass"
        case .fileSharing: "icloud.and.arrow.up.and.arrow.down"
        case .history: "clock.arrow.circlepath"
        }
    }
}
