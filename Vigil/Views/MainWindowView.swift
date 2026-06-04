import SwiftUI

extension Notification.Name {
    static let showWalkthrough = Notification.Name("showWalkthrough")
}

/// The root view for the Vigil window.
/// Provides mode switching between the visualization modes, grouped by category.
struct MainWindowView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var selectedMode: ViewMode = .overview
    @AppStorage("hasSeenWalkthrough") private var hasSeenWalkthrough = false
    @State private var showingWalkthrough = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedMode) {
                Section {
                    sidebarItem(.overview)
                }

                Section("System") {
                    sidebarItem(.processes)
                    sidebarItem(.fileActivity)
                    sidebarItem(.fileSharing)
                }

                Section("AI") {
                    sidebarItem(.aiActivity)
                    sidebarItem(.aiInventory)
                    sidebarItem(.aiSecurity)
                    sidebarItem(.aiLogs)
                }

                Section {
                    sidebarItem(.history)
                }
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
        .sheet(isPresented: $showingWalkthrough) {
            WalkthroughView()
        }
        .task {
            let processMonitor = ProcessMonitor()
            let fileMonitor = FileMonitor()
            let database = try? Database()
            store.configure(processSource: processMonitor, fileSource: fileMonitor,
                            database: database)
            await store.startMonitoring()
        }
        .onAppear {
            if !hasSeenWalkthrough {
                showingWalkthrough = true
                hasSeenWalkthrough = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showWalkthrough)) { _ in
            showingWalkthrough = true
        }
    }

    private func sidebarItem(_ mode: ViewMode) -> some View {
        Label(mode.displayName, systemImage: mode.systemImage)
            .tag(mode)
    }

    func showWalkthrough() {
        showingWalkthrough = true
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
        case .aiLogs: "note.text"
        case .fileSharing: "icloud.and.arrow.up.and.arrow.down"
        case .history: "clock.arrow.circlepath"
        }
    }
}
