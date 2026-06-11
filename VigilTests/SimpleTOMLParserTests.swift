import Foundation
import Testing
@testable import Vigil

@Suite("SimpleTOMLParser")
struct SimpleTOMLParserTests {

    @Test("parses simple key-value pairs")
    func simpleKeyValue() {
        let toml = """
        model = "gpt-4"
        count = 42
        enabled = true
        disabled = false
        """
        let result = SimpleTOMLParser.parse(toml)
        #expect(result["model"] as? String == "gpt-4")
        #expect(result["count"] as? Int == 42)
        #expect(result["enabled"] as? Bool == true)
        #expect(result["disabled"] as? Bool == false)
    }

    @Test("parses section headers")
    func sectionHeaders() {
        let toml = """
        [desktop]
        theme = "dark"

        [features]
        js_repl = false
        """
        let result = SimpleTOMLParser.parse(toml)
        #expect(SimpleTOMLParser.string(result, "desktop.theme") == "dark")
        #expect(SimpleTOMLParser.bool(result, "features.js_repl") == false)
    }

    @Test("parses dotted section paths")
    func dottedSections() {
        let toml = """
        [mcp_servers.node_repl]
        command = "/usr/bin/node"
        args = []

        [mcp_servers.node_repl.env]
        NODE_PATH = "/usr/local"
        DEBUG = "true"
        """
        let result = SimpleTOMLParser.parse(toml)
        let command = SimpleTOMLParser.string(result, "mcp_servers.node_repl.command")
        #expect(command == "/usr/bin/node")

        let nodePath = SimpleTOMLParser.string(result, "mcp_servers.node_repl.env.NODE_PATH")
        #expect(nodePath == "/usr/local")
    }

    @Test("parses arrays")
    func arrays() {
        let toml = """
        tags = ["alpha", "beta", "gamma"]
        empty = []
        """
        let result = SimpleTOMLParser.parse(toml)
        let tags = result["tags"] as? [String]
        #expect(tags == ["alpha", "beta", "gamma"])
        let empty = result["empty"] as? [String]
        #expect(empty?.isEmpty == true)
    }

    @Test("ignores comments and blank lines")
    func commentsAndBlanks() {
        let toml = """
        # This is a comment
        key = "value"

        # Another comment
        other = 123
        """
        let result = SimpleTOMLParser.parse(toml)
        #expect(result.count == 2)
        #expect(result["key"] as? String == "value")
    }

    @Test("parses quoted section keys")
    func quotedSectionKeys() {
        let toml = """
        [plugins."browser@openai-bundled"]
        enabled = true
        """
        let result = SimpleTOMLParser.parse(toml)
        let enabled = SimpleTOMLParser.bool(result, "plugins.browser@openai-bundled.enabled")
        #expect(enabled == true)
    }

    @Test("handles real Codex config structure")
    func codexConfigStructure() {
        let toml = """
        model = "gpt-5.5"

        [mcp_servers.node_repl]
        args = []
        command = "/Applications/Codex.app/Contents/Resources/node_repl"
        startup_timeout_sec = 120

        [mcp_servers.node_repl.env]
        CODEX_HOME = "/Users/dev/.codex"

        [projects."/Users/dev/myproject"]
        trust_level = "trusted"
        """
        let result = SimpleTOMLParser.parse(toml)
        #expect(result["model"] as? String == "gpt-5.5")

        let mcpTable = SimpleTOMLParser.table(result, "mcp_servers")
        #expect(mcpTable != nil)
        #expect(mcpTable?.keys.contains("node_repl") == true)

        let command = SimpleTOMLParser.string(result, "mcp_servers.node_repl.command")
        #expect(command == "/Applications/Codex.app/Contents/Resources/node_repl")

        let codexHome = SimpleTOMLParser.string(result, "mcp_servers.node_repl.env.CODEX_HOME")
        #expect(codexHome == "/Users/dev/.codex")
    }
}
