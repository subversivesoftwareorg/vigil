import Foundation

/// Minimal TOML parser for reading AI tool config files.
/// Handles flat key-value pairs, [section] headers, [section.subsection] nesting,
/// strings (quoted and bare), booleans, integers, and simple arrays.
/// NOT a full TOML spec implementation — sufficient for Codex config.toml and similar files.
enum SimpleTOMLParser {

    typealias TOMLTable = [String: Any]

    static func parse(_ content: String) -> TOMLTable {
        var result: TOMLTable = [:]
        var currentSection: [String] = []

        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty || line.hasPrefix("#") { continue }

            // Section header: [section] or [section.subsection]
            if line.hasPrefix("[") && line.hasSuffix("]") {
                let inner = line.dropFirst().dropLast()
                    .trimmingCharacters(in: .whitespaces)
                currentSection = inner.split(separator: ".").map {
                    $0.trimmingCharacters(in: .init(charactersIn: " \""))
                }
                ensurePath(&result, path: currentSection)
                continue
            }

            // Key = value
            guard let eqIndex = line.firstIndex(of: "=") else { continue }
            let key = line[line.startIndex..<eqIndex].trimmingCharacters(in: .whitespaces)
            let rawValue = line[line.index(after: eqIndex)...].trimmingCharacters(in: .whitespaces)

            let value = parseValue(rawValue)
            setNested(&result, path: currentSection + [key], value: value)
        }

        return result
    }

    // MARK: - Value Parsing

    private static func parseValue(_ raw: String) -> Any {
        if raw == "true" { return true }
        if raw == "false" { return false }

        // Quoted string
        if (raw.hasPrefix("\"") && raw.hasSuffix("\""))
            || (raw.hasPrefix("'") && raw.hasSuffix("'")) {
            return String(raw.dropFirst().dropLast())
        }

        // Array
        if raw.hasPrefix("[") && raw.hasSuffix("]") {
            let inner = raw.dropFirst().dropLast()
                .trimmingCharacters(in: .whitespaces)
            if inner.isEmpty { return [String]() }
            return inner.split(separator: ",").map { element in
                let trimmed = element.trimmingCharacters(in: .whitespaces)
                if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\""))
                    || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
                    return String(trimmed.dropFirst().dropLast())
                }
                return trimmed
            }
        }

        // Integer
        if let intVal = Int(raw) { return intVal }

        // Bare string / datetime / other
        return raw
    }

    // MARK: - Nested Dictionary Helpers

    private static func ensurePath(_ dict: inout TOMLTable, path: [String]) {
        var current = dict
        var buildPath: [String] = []
        for key in path {
            buildPath.append(key)
            if current[key] == nil {
                setNested(&dict, path: buildPath, value: TOMLTable())
            }
            current = (getNested(dict, path: buildPath) as? TOMLTable) ?? [:]
        }
    }

    private static func setNested(_ dict: inout TOMLTable, path: [String], value: Any) {
        guard !path.isEmpty else { return }
        if path.count == 1 {
            dict[path[0]] = value
            return
        }
        var sub = (dict[path[0]] as? TOMLTable) ?? [:]
        setNested(&sub, path: Array(path.dropFirst()), value: value)
        dict[path[0]] = sub
    }

    static func getNested(_ dict: TOMLTable, path: [String]) -> Any? {
        guard !path.isEmpty else { return dict }
        guard let next = dict[path[0]] else { return nil }
        if path.count == 1 { return next }
        guard let sub = next as? TOMLTable else { return nil }
        return getNested(sub, path: Array(path.dropFirst()))
    }

    /// Convenience: get a string value at a dotted path
    static func string(_ dict: TOMLTable, _ dottedPath: String) -> String? {
        getNested(dict, path: dottedPath.split(separator: ".").map(String.init)) as? String
    }

    /// Convenience: get a bool value at a dotted path
    static func bool(_ dict: TOMLTable, _ dottedPath: String) -> Bool? {
        getNested(dict, path: dottedPath.split(separator: ".").map(String.init)) as? Bool
    }

    /// Convenience: get a sub-table at a dotted path
    static func table(_ dict: TOMLTable, _ dottedPath: String) -> TOMLTable? {
        getNested(dict, path: dottedPath.split(separator: ".").map(String.init)) as? TOMLTable
    }
}
