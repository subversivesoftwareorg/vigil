import Foundation
import Testing
@testable import Vigil

@Suite("AIProcessCatalog")
struct AIProcessCatalogTests {

    // MARK: - Process Matching & Evidence

    @Test("claude lowercase matches Claude Code with high confidence")
    func claudeCodeExactMatch() {
        let match = AIProcessCatalog.match("claude")
        #expect(match != nil)
        #expect(match?.entry.displayName == "Claude Code")
        #expect(match?.evidence.basis == .observed)
        #expect(match?.evidence.confidence == .high)
    }

    @Test("Claude capitalized matches Claude Desktop with high confidence")
    func claudeDesktopExactMatch() {
        let match = AIProcessCatalog.match("Claude")
        #expect(match != nil)
        #expect(match?.entry.displayName == "Claude Desktop")
        #expect(match?.evidence.basis == .observed)
        #expect(match?.evidence.confidence == .high)
    }

    @Test("Claude Helper matches Claude Desktop via substring with medium confidence")
    func claudeHelperSubstringMatch() {
        let match = AIProcessCatalog.match("Claude Helper")
        #expect(match != nil)
        #expect(match?.entry.displayName == "Claude Desktop")
        #expect(match?.evidence.basis == .inferred)
        #expect(match?.evidence.confidence == .medium)
    }

    @Test("claude-code matches Claude Code via substring with medium confidence")
    func claudeCodeDashMatch() {
        let match = AIProcessCatalog.match("claude-code")
        #expect(match != nil)
        #expect(match?.entry.displayName == "Claude Code")
        #expect(match?.evidence.basis == .inferred)
        #expect(match?.evidence.confidence == .medium)
    }

    @Test("ollama exact match yields observed/high")
    func ollamaExactMatch() {
        let match = AIProcessCatalog.match("ollama")
        #expect(match != nil)
        #expect(match?.entry.displayName == "Ollama")
        #expect(match?.evidence.basis == .observed)
        #expect(match?.evidence.confidence == .high)
    }

    @Test("ollama-helper substring match yields inferred/medium")
    func ollamaSubstringMatch() {
        let match = AIProcessCatalog.match("ollama-helper")
        #expect(match != nil)
        #expect(match?.entry.displayName == "Ollama")
        #expect(match?.evidence.basis == .inferred)
        #expect(match?.evidence.confidence == .medium)
    }

    @Test("unrelated process does not match")
    func noMatch() {
        #expect(AIProcessCatalog.match("Safari") == nil)
        #expect(AIProcessCatalog.match("Finder") == nil)
    }

    // MARK: - Path Matching & Evidence

    @Test("Claude workspace path matches with inferred basis and high confidence")
    func claudeWorkspacePath() {
        let match = AIProcessCatalog.matchPath("/Users/dev/myproject/.claude/settings.json")
        #expect(match != nil)
        #expect(match?.pattern.tool == "Claude Code")
        #expect(match?.evidence.basis == .inferred)
        #expect(match?.evidence.confidence == .high)
    }

    @Test("Application Support path matches with high confidence")
    func appSupportPath() {
        let match = AIProcessCatalog.matchPath("/Users/dev/Library/Application Support/Claude/data")
        #expect(match != nil)
        #expect(match?.pattern.tool == "Claude Desktop")
        #expect(match?.evidence.basis == .inferred)
        #expect(match?.evidence.confidence == .high)
    }

    @Test("Ollama model path matches with high confidence")
    func ollamaModelPath() {
        let match = AIProcessCatalog.matchPath("/Users/dev/.ollama/models/llama3")
        #expect(match != nil)
        #expect(match?.pattern.tool == "Ollama")
        #expect(match?.evidence.basis == .inferred)
        #expect(match?.evidence.confidence == .high)
    }

    @Test("Broader path pattern yields medium confidence")
    func broaderPathPattern() {
        let match = AIProcessCatalog.matchPath("/some/path/copilot/suggestions.json")
        #expect(match != nil)
        #expect(match?.pattern.tool == "GitHub Copilot")
        #expect(match?.evidence.confidence == .medium)
    }

    @Test("Chrome profile path no longer matches")
    func chromeProfileNoMatch() {
        let match = AIProcessCatalog.matchPath("/Users/dev/Library/Application Support/Google/Chrome/Default/History")
        #expect(match == nil)
    }

    @Test("ordinary path does not match")
    func ordinaryPathNoMatch() {
        #expect(AIProcessCatalog.matchPath("/Users/dev/Documents/report.pdf") == nil)
    }

    // MARK: - Model File Detection

    @Test("gguf file is detected as model file")
    func ggufModelFile() {
        #expect(AIProcessCatalog.isModelFile("/Downloads/llama-3.gguf") == true)
    }

    @Test("safetensors file is detected as model file")
    func safetensorsModelFile() {
        #expect(AIProcessCatalog.isModelFile("/models/model.safetensors") == true)
    }

    @Test("swift file is not a model file")
    func swiftNotModelFile() {
        #expect(AIProcessCatalog.isModelFile("/code/main.swift") == false)
    }

    // MARK: - Evidence Model

    @Test("ConfidenceLevel ordering is low < medium < high")
    func confidenceOrdering() {
        #expect(ConfidenceLevel.low < ConfidenceLevel.medium)
        #expect(ConfidenceLevel.medium < ConfidenceLevel.high)
        #expect(!(ConfidenceLevel.high < ConfidenceLevel.low))
    }

    @Test("exact match always preferred over substring match")
    func exactPreferredOverSubstring() {
        // "Cursor" appears as both a pattern ["cursor", "Cursor"] for the coding assistant
        // An exact match on "Cursor" should yield high confidence
        let match = AIProcessCatalog.match("Cursor")
        #expect(match?.evidence.confidence == .high)
        #expect(match?.evidence.basis == .observed)
    }
}
