import Foundation
import Testing
@testable import Vigil

@Suite("FileEvent")
struct FileEventTests {

    @Test("displayName extracts filename from path")
    func displayName() {
        let event = FileEvent(
            id: .init(),
            path: "/Users/test/Documents/readme.txt",
            kind: .modified,
            timestamp: .now
        )
        #expect(event.displayName == "readme.txt")
    }

    @Test("directory extracts parent path")
    func directory() {
        let event = FileEvent(
            id: .init(),
            path: "/Users/test/Documents/readme.txt",
            kind: .created,
            timestamp: .now
        )
        #expect(event.directory == "/Users/test/Documents")
    }

    @Test("all event kinds round-trip through Codable", arguments: FileEvent.Kind.allCases)
    func codableRoundTrip(kind: FileEvent.Kind) throws {
        let event = FileEvent(id: .init(), path: "/tmp/test", kind: kind, timestamp: .now)
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(FileEvent.self, from: data)
        #expect(decoded.kind == kind)
        #expect(decoded.path == event.path)
    }
}

extension FileEvent.Kind: CaseIterable {
    public static var allCases: [FileEvent.Kind] {
        [.created, .modified, .deleted, .renamed, .metadataChanged]
    }
}
