import Foundation
import Testing
@testable import Vigil

@Suite("AIConfigReaders")
struct AIConfigReaderTests {

    // MARK: - Claude Code Permission Categorization

    @Test("categorizePermissions groups shell commands")
    func shellCommandGrouping() {
        let perms = ClaudeCodeAdapter.categorizePermissions(
            allow: ["Bash(git:*)", "Bash(swift:*)"],
            deny: ["Bash(rm:*)"],
            ask: []
        )
        let shellAllowed = perms.allowed.first { $0.category == "Shell Commands" }
        #expect(shellAllowed != nil)
        #expect(shellAllowed?.items.count == 2)

        let shellDenied = perms.denied.first { $0.category == "Shell Commands" }
        #expect(shellDenied != nil)
    }

    @Test("categorizePermissions groups file access")
    func fileAccessGrouping() {
        let perms = ClaudeCodeAdapter.categorizePermissions(
            allow: ["Read(/src)", "Read(/tests)"],
            deny: [],
            ask: []
        )
        let fileAccess = perms.allowed.first { $0.category == "File Access" }
        #expect(fileAccess != nil)
        #expect(fileAccess?.items.count == 2)
    }

    @Test("categorizePermissions groups MCP tools")
    func mcpGrouping() {
        let perms = ClaudeCodeAdapter.categorizePermissions(
            allow: ["mcp__github__create_pr", "mcp__github__list_repos"],
            deny: [],
            ask: []
        )
        let mcpGroup = perms.allowed.first { $0.category.hasPrefix("MCP") }
        #expect(mcpGroup != nil)
    }

    @Test("categorizePermissions groups web access")
    func webAccessGrouping() {
        let perms = ClaudeCodeAdapter.categorizePermissions(
            allow: ["WebFetch(domain:api.example.com)", "WebSearch"],
            deny: [],
            ask: []
        )
        let webGroup = perms.allowed.first { $0.category == "Web Access" }
        #expect(webGroup != nil)
        #expect(webGroup?.items.count == 2)
    }

    @Test("categorizePermissions groups file writing")
    func fileWriteGrouping() {
        let perms = ClaudeCodeAdapter.categorizePermissions(
            allow: ["Edit", "Write"],
            deny: [],
            ask: []
        )
        let writeGroup = perms.allowed.first { $0.category == "File Writing" }
        #expect(writeGroup != nil)
        #expect(writeGroup?.items.count == 2)
    }

    @Test("PermissionSummary computes totals correctly")
    func summaryTotals() {
        let perms = ClaudeCodeAdapter.categorizePermissions(
            allow: ["Bash(git:*)", "Bash(swift:*)", "Read(/src)"],
            deny: ["Bash(rm:*)"],
            ask: ["Write"]
        )
        #expect(perms.totalAllowed == 3)
        #expect(perms.totalDenied == 1)
        #expect(perms.totalAsk == 1)
    }

    // MARK: - Claude Summary Generation

    @Test("generateSummary includes shell command count")
    func summaryShellCommands() {
        let perms = ClaudeCodeAdapter.categorizePermissions(
            allow: ["Bash(git:*)", "Bash(swift:*)", "Bash(npm:*)"],
            deny: [], ask: []
        )
        let summary = ClaudeCodeAdapter.generateSummary(
            permissions: perms, mcpServers: [], envVarCount: 0, hasHooks: false
        )
        #expect(summary.contains { $0.contains("3 shell commands") })
    }

    @Test("generateSummary includes MCP server count")
    func summaryMCPServers() {
        let perms = ClaudeCodeAdapter.categorizePermissions(allow: [], deny: [], ask: [])
        let summary = ClaudeCodeAdapter.generateSummary(
            permissions: perms, mcpServers: ["github", "filesystem"], envVarCount: 0, hasHooks: false
        )
        #expect(summary.contains { $0.contains("2 MCP servers") })
    }

    @Test("generateSummary includes hooks flag")
    func summaryHooks() {
        let perms = ClaudeCodeAdapter.categorizePermissions(allow: [], deny: [], ask: [])
        let summary = ClaudeCodeAdapter.generateSummary(
            permissions: perms, mcpServers: [], envVarCount: 0, hasHooks: true
        )
        #expect(summary.contains { $0.contains("hooks") })
    }

    @Test("generateSummary includes env var count")
    func summaryEnvVars() {
        let perms = ClaudeCodeAdapter.categorizePermissions(allow: [], deny: [], ask: [])
        let summary = ClaudeCodeAdapter.generateSummary(
            permissions: perms, mcpServers: [], envVarCount: 5, hasHooks: false
        )
        #expect(summary.contains { $0.contains("5 environment") })
    }

    // MARK: - Claude Session Parsing

    @Test("decodeDirName converts encoded path")
    func decodeDirName() {
        let decoded = ClaudeCodeAdapter.decodeDirName("-Users-mkonda-code-project")
        #expect(decoded == "/Users/mkonda/code/project")
    }

    // MARK: - TOML-Based Codex Config

    @Test("CodexAdapter parses MCP servers from TOML")
    func codexMCPFromTOML() {
        let toml = """
        model = "gpt-5.5"

        [mcp_servers.test_server]
        command = "/usr/bin/node"
        args = []

        [mcp_servers.test_server.env]
        API_KEY = "test123"
        """
        let parsed = SimpleTOMLParser.parse(toml)
        let mcpTable = SimpleTOMLParser.table(parsed, "mcp_servers")
        #expect(mcpTable != nil)
        #expect(mcpTable?.keys.contains("test_server") == true)

        if let serverTable = mcpTable?["test_server"] as? [String: Any] {
            #expect(serverTable["command"] as? String == "/usr/bin/node")
            let env = (serverTable["env"] as? [String: Any]) ?? [:]
            #expect(env["API_KEY"] as? String == "test123")
        }
    }

    // MARK: - Adapter Config Basics

    @Test("adapter readConfig returns nil when files don't exist")
    func adapterConfigNil() {
        let copilot = CopilotAdapter()
        #expect(copilot.readConfig() == nil)

        let whisper = WhisperAdapter()
        #expect(whisper.readConfig() == nil)
    }

    @Test("each adapter has correct category")
    func adapterCategories() {
        #expect(ClaudeCodeAdapter().category == .codingAssistant)
        #expect(ClaudeDesktopAdapter().category == .chatApp)
        #expect(OllamaAdapter().category == .localModel)
        #expect(ChatGPTAdapter().category == .chatApp)
    }
}
