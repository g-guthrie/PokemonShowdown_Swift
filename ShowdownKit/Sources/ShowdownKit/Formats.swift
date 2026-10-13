import Foundation

public struct BattleFormat: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var section: String
    public var column: Int
    /// False for formats that hand out teams (random battles).
    public var requiresTeam: Bool
    public var searchShow: Bool
    public var challengeShow: Bool
    public var tournamentShow: Bool
    public var levelCap50: Bool

    public init(id: String, name: String, section: String, column: Int = 1, requiresTeam: Bool, searchShow: Bool = true, challengeShow: Bool = true, tournamentShow: Bool = true, levelCap50: Bool = false) {
        self.id = id
        self.name = name
        self.section = section
        self.column = column
        self.requiresTeam = requiresTeam
        self.searchShow = searchShow
        self.challengeShow = challengeShow
        self.tournamentShow = tournamentShow
        self.levelCap50 = levelCap50
    }

    /// `[Gen 9] OU` -> `OU`
    public var shortName: String {
        if name.hasPrefix("["), let close = name.firstIndex(of: "]") {
            return name[name.index(after: close)...].trimmingCharacters(in: .whitespaces)
        }
        return name
    }

    /// `[Gen 9] OU` -> `Gen 9`
    public var genLabel: String? {
        if name.hasPrefix("["), let close = name.firstIndex(of: "]") {
            return String(name[name.index(after: name.startIndex)..<close])
        }
        return nil
    }

    public var isDoubles: Bool {
        let lower = name.lowercased()
        return lower.contains("doubles") || lower.contains("vgc") || lower.contains("2v2")
    }

    public var isRandom: Bool { id.contains("random") }
}

public struct FormatSection: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public var name: String
    public var column: Int
    public var formats: [BattleFormat]
}

public enum FormatParser {
    /// Parses the arguments of a `|formats|` line (everything after `formats`).
    public static func parse(_ args: [String]) -> [FormatSection] {
        var sections: [FormatSection] = []
        var expectingSection = false
        var column = 0
        for entry in args {
            if expectingSection {
                sections.append(FormatSection(name: entry, column: column, formats: []))
                expectingSection = false
                continue
            }
            if entry == ",LL" { continue }
            if entry.isEmpty || (entry.hasPrefix(",") && Int(entry.dropFirst()) != nil) {
                expectingSection = true
                if !entry.isEmpty { column = Int(entry.dropFirst()) ?? 0 }
                continue
            }
            var name = entry
            var code = 0b1110
            if let comma = name.lastIndex(of: ","), let parsed = Int(name[name.index(after: comma)...], radix: 16) {
                code = parsed
                name = String(name[..<comma])
            }
            let format = BattleFormat(
                id: toID(name),
                name: name,
                section: sections.last?.name ?? "",
                column: column,
                requiresTeam: code & 1 == 0,
                searchShow: code & 2 != 0,
                challengeShow: code & 4 != 0,
                tournamentShow: code & 8 != 0,
                levelCap50: code & 16 != 0
            )
            if sections.isEmpty {
                sections.append(FormatSection(name: "", column: column, formats: []))
            }
            sections[sections.count - 1].formats.append(format)
        }
        return sections.filter { !$0.formats.isEmpty }
    }
}
