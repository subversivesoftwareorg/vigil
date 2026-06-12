import Foundation
import Testing
@testable import Vigil

@Suite("AIAdapterRegistry")
struct AIAdapterRegistryTests {

    // MARK: - Registry Structure

    @Test("registry contains expected number of adapters")
    func adapterCount() {
        #expect(AIAdapterRegistry.adapters.count >= 18)
    }

    @Test("all adapters have unique toolIDs")
    func uniqueToolIDs() {
        let ids = AIAdapterRegistry.adapters.map(\.toolID)
        #expect(ids.count == Set(ids).count)
    }

    // MARK: - Process Matching

    @Test("claude matches ClaudeCodeAdapter")
    func claudeProcessMatch() {
        let result = AIAdapterRegistry.matchProcess("claude")
        #expect(result != nil)
        #expect(result?.adapter.toolID == "claude-code")
        #expect(result?.evidence.confidence == .high)
    }

    @Test("Claude matches ClaudeDesktopAdapter")
    func claudeDesktopProcessMatch() {
        let result = AIAdapterRegistry.matchProcess("Claude")
        #expect(result != nil)
        #expect(result?.adapter.toolID == "claude-desktop")
    }

    @Test("ollama matches OllamaAdapter")
    func ollamaProcessMatch() {
        let result = AIAdapterRegistry.matchProcess("ollama")
        #expect(result != nil)
        #expect(result?.adapter.toolID == "ollama")
    }

    @Test("codex matches CodexAdapter")
    func codexProcessMatch() {
        let result = AIAdapterRegistry.matchProcess("codex")
        #expect(result != nil)
        #expect(result?.adapter.toolID == "codex-cli")
    }

    @Test("unknown process returns nil")
    func unknownProcess() {
        #expect(AIAdapterRegistry.matchProcess("Safari") == nil)
        #expect(AIAdapterRegistry.matchProcess("Finder") == nil)
        #expect(AIAdapterRegistry.matchProcess("launchd") == nil)
    }

    @Test("CursorUIViewService does not match any adapter")
    func cursorFalsePositive() {
        #expect(AIAdapterRegistry.matchProcess("CursorUIViewService") == nil)
    }

    @Test("exact match takes priority over substring across adapters")
    func exactMatchPriority() {
        let result = AIAdapterRegistry.matchProcess("Cursor")
        #expect(result?.evidence.basis == .observed)
        #expect(result?.evidence.confidence == .high)
    }

    // MARK: - Path Matching

    @Test("Claude path matches ClaudeCodeAdapter")
    func claudePathMatch() {
        let result = AIAdapterRegistry.matchPath("/Users/dev/.claude/settings.json")
        #expect(result != nil)
        #expect(result?.adapter.toolID == "claude-code")
    }

    @Test("Codex path matches CodexAdapter")
    func codexPathMatch() {
        let result = AIAdapterRegistry.matchPath("/Users/dev/.codex/config.toml")
        #expect(result != nil)
        #expect(result?.adapter.toolID == "codex-cli")
    }

    @Test("Ollama model path matches OllamaAdapter")
    func ollamaPathMatch() {
        let result = AIAdapterRegistry.matchPath("/Users/dev/.ollama/models/llama3")
        #expect(result != nil)
        #expect(result?.adapter.toolID == "ollama")
    }

    @Test("ordinary path does not match")
    func ordinaryPathNoMatch() {
        #expect(AIAdapterRegistry.matchPath("/Users/dev/Documents/report.pdf") == nil)
    }

    // MARK: - Model File Detection

    @Test("gguf detected as model file")
    func ggufModelFile() {
        #expect(AIAdapterRegistry.isModelFile("/models/llama.gguf") == true)
    }

    @Test("safetensors detected as model file")
    func safetensorsModelFile() {
        #expect(AIAdapterRegistry.isModelFile("/models/model.safetensors") == true)
    }

    @Test("swift file is not a model file")
    func swiftNotModelFile() {
        #expect(AIAdapterRegistry.isModelFile("/src/main.swift") == false)
    }

    // MARK: - Config Discovery

    @Test("discoverAllConfigs returns array without crashing")
    func configDiscovery() {
        let configs = AIAdapterRegistry.discoverAllConfigs()
        #expect(configs is [AIToolConfig])
    }

    // MARK: - Session Parsing

    @Test("parseAllSessions returns array without crashing")
    func sessionParsing() {
        let sessions = AIAdapterRegistry.parseAllSessions()
        #expect(sessions is [AISessionLog])
    }

    // MARK: - Project Root Discovery

    @Test("discoverProjectRoots does not crash with nonexistent marker")
    func projectRootsNonexistent() {
        let roots = AIAdapterRegistry.discoverProjectRoots(marker: ".nonexistent-marker-file-xyz")
        #expect(roots.isEmpty)
    }
}
