import Foundation
import Testing
@testable import Vigil

@Suite("CapabilityLedger")
struct CapabilityLedgerTests {

    // MARK: - Coverage Catalog Completeness

    @Test("every registered adapter has a coverage entry")
    func coverageCatalogComplete() {
        let adapterIDs = Set(AIAdapterRegistry.adapters.map(\.toolID))
        let catalogIDs = Set(AdapterCoverageCatalog.all.map(\.toolID))
        #expect(adapterIDs == catalogIDs)
    }

    @Test("coverage display names match adapter display names")
    func coverageNamesMatch() {
        for coverage in AdapterCoverageCatalog.all {
            let adapter = AIAdapterRegistry.adapters.first { $0.toolID == coverage.toolID }
            #expect(adapter?.displayName == coverage.displayName)
        }
    }

    @Test("risk surface catalog includes blind spots with companions")
    func riskSurfacesIncludeBlindSpots() {
        let blindSpots = RiskSurfaceCatalog.all.filter { $0.vigilCoverage == .none }
        #expect(!blindSpots.isEmpty)
        // Every named blind spot should point at a companion tool
        for spot in blindSpots {
            #expect(spot.companion != nil)
        }
    }

    // MARK: - Ledger Builder

    @Test("builder creates tool and MCP entries from configs")
    func builderCreatesEntries() {
        var config = AIToolConfig(
            tool: "Test Tool", provider: "Test",
            layers: [SettingsLayer(path: "/tmp/settings.json", label: "test")],
            permissions: PermissionSummary(
                allowed: [
                    PermissionGroup(category: "Shell Commands", items: ["git", "ls"]),
                    PermissionGroup(category: "MCP (github)", items: ["get_me", "search_code"]),
                ],
                denied: [], requiresApproval: []
            ),
            envVarCount: 0, mcpServers: ["github"], hasHooks: false, summary: []
        )
        config.mcpServerDetails = [
            MCPServerDetail(name: "github", command: "npx @github/mcp@1.0", args: [],
                            envVars: [:], autoApprovedTools: [], source: "test")
        ]

        let entries = CapabilityLedgerBuilder.build(configs: [config], agents: [])
        #expect(entries.count == 2)

        let tool = entries.first { $0.kind == .tool }
        #expect(tool?.shellAccess == .granted)

        let mcp = entries.first { $0.kind == .mcpServer }
        #expect(mcp?.parent == "Test Tool")
        #expect(mcp?.grantedTools.contains("get_me") == true)
    }

    @Test("builder maps unattended agents to schedule entries")
    func builderMapsAgents() {
        let agent = UnattendedAgent(
            id: "a1", kind: .coworkScheduledTask, name: "digest",
            schedule: "0 0 * * *", enabled: true, sourcePath: "/tmp/SKILL.md",
            folderAccess: ["/tmp/project"], browserDomains: ["x.com"],
            permissionMode: "follow_a_plan", lastRunAt: nil,
            capabilities: ["Shell execution"]
        )
        let entries = CapabilityLedgerBuilder.build(configs: [], agents: [agent])
        #expect(entries.count == 1)
        let entry = entries[0]
        #expect(entry.kind == .scheduledTask)
        #expect(entry.schedule == "Daily at 0:00")
        #expect(entry.shellAccess == .granted)
        #expect(entry.browserDomains == ["x.com"])
        #expect(entry.approvalMode == "follow_a_plan")
    }

    @Test("codex-style sandbox shows in tool file scope")
    func sandboxedToolFileScope() {
        var config = AIToolConfig(
            tool: "Sandboxed", provider: "Test", layers: [],
            permissions: PermissionSummary(allowed: [], denied: [], requiresApproval: []),
            envVarCount: 0, mcpServers: [], hasHooks: false, summary: []
        )
        config.sandboxMode = "workspaceWrite: /Users/x/project"
        config.networkAccess = false
        config.approvalMode = "on-request"

        let entries = CapabilityLedgerBuilder.build(configs: [config], agents: [])
        let tool = entries[0]
        #expect(tool.fileScope == ["workspaceWrite: /Users/x/project"])
        #expect(tool.networkAccess == .denied)
        #expect(tool.approvalMode == "on-request")
    }
}
