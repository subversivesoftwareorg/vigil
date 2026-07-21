import Foundation
import Testing
@testable import Vigil

@Suite("AIFacades")
struct AIFacadeTests {

    // MARK: - AISettingsReader Facade

    @Test("AISettingsReader.discoverAll delegates to registry")
    func settingsReaderFacade() {
        let fromFacade = AISettingsReader.discoverAll()
        let fromRegistry = AIAdapterRegistry.discoverAllConfigs()
        #expect(fromFacade.count == fromRegistry.count)
    }

    // MARK: - AISessionLogParser Facade

    @Test("AISessionLogParser.parseAll delegates to registry")
    func sessionParserFacade() {
        let fromFacade = AISessionLogParser.parseAll()
        let fromRegistry = AIAdapterRegistry.parseAllSessions()
        #expect(fromFacade.count == fromRegistry.count)
    }

    @Test("AISessionLogParser.decodeDirName delegates to ClaudeCodeAdapter")
    func decodeDirNameFacade() {
        let result = AISessionLogParser.decodeDirName("-Users-dev-code-project")
        #expect(result == "/Users/dev/code/project")
    }

    // MARK: - AISecurityEngine Facade

    @Test("AISecurityEngine.scan returns result with signals")
    func securityEngineFacade() {
        var session = AISessionLog(id: "facade-test", projectPath: "/test")
        session.humanTurns = 1
        session.bashCommands = ["sudo rm -rf /tmp/evil"]
        session.filesTouched = [AIFileTouched(path: "/home/.env", action: .write)]

        let result = AISecurityEngine.scan(sessions: [session])
        #expect(result.sessions.count == 1)
        #expect(!result.signals.isEmpty)
    }

    @Test("AISecurityEngine.scan returns no session signals for benign session")
    func securityEngineBenign() {
        var session = AISessionLog(id: "benign-test", projectPath: "/test")
        session.humanTurns = 1
        session.bashCommands = ["git status"]

        let result = AISecurityEngine.scan(sessions: [session])
        #expect(result.sessions.count == 1)
        // Filter to signals from this specific session — config-based signals
        // from real adapters on this machine are expected and valid
        let sessionSignals = result.signals.filter { $0.sessionID == "benign-test" }
        let nonInfoSessionSignals = sessionSignals.filter { $0.severity > .info }
        #expect(nonInfoSessionSignals.isEmpty)
    }

    // MARK: - AIProcessCatalog Facade

    @Test("AIProcessCatalog.match delegates to registry")
    func processCatalogFacade() {
        let match = AIProcessCatalog.match("claude")
        #expect(match != nil)
        #expect(match?.entry.displayName == "Claude Code")
    }

    @Test("AIProcessCatalog.matchPath delegates to registry")
    func pathCatalogFacade() {
        let match = AIProcessCatalog.matchPath("/Users/dev/.claude/settings.json")
        #expect(match != nil)
        #expect(match?.pattern.tool == "Claude Code")
    }

    @Test("AIProcessCatalog.isModelFile delegates to registry")
    func modelFileFacade() {
        #expect(AIProcessCatalog.isModelFile("/models/test.gguf") == true)
        #expect(AIProcessCatalog.isModelFile("/src/main.swift") == false)
    }
}
