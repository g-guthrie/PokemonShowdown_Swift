import Foundation

public struct StatSpread: Codable, Hashable, Sendable {
    public var hp: Int
    public var atk: Int
    public var def: Int
    public var spa: Int
    public var spd: Int
    public var spe: Int

    public init(hp: Int, atk: Int, def: Int, spa: Int, spd: Int, spe: Int) {
        self.hp = hp
        self.atk = atk
        self.def = def
        self.spa = spa
        self.spd = spd
        self.spe = spe
    }

    public init(all value: Int) {
        self.init(hp: value, atk: value, def: value, spa: value, spd: value, spe: value)
    }

    public static let keys = ["hp", "atk", "def", "spa", "spd", "spe"]
    public static let labels = ["hp": "HP", "atk": "Atk", "def": "Def", "spa": "SpA", "spd": "SpD", "spe": "Spe"]

    public subscript(key: String) -> Int {
        get {
            switch key {
            case "hp": return hp
            case "atk": return atk
            case "def": return def
            case "spa": return spa
            case "spd": return spd
            default: return spe
            }
        }
        set {
            switch key {
            case "hp": hp = newValue
            case "atk": atk = newValue
            case "def": def = newValue
            case "spa": spa = newValue
            case "spd": spd = newValue
            default: spe = newValue
            }
        }
    }

    public var total: Int { hp + atk + def + spa + spd + spe }

    static func key(forLabel label: String) -> String? {
        switch label.lowercased() {
        case "hp": return "hp"
        case "atk": return "atk"
        case "def": return "def"
        case "spa", "satk", "sp. atk", "spatk": return "spa"
        case "spd", "sdef", "sp. def", "spdef": return "spd"
        case "spe", "spd.", "speed", "spe.": return "spe"
        default: return nil
        }
    }
}

public struct PokemonSet: Codable, Hashable, Sendable, Identifiable {
    public var id = UUID()
    public var nickname: String = ""
    public var species: String = ""
    public var item: String = ""
    public var ability: String = ""
    public var moves: [String] = []
    public var nature: String = ""
    public var evs = StatSpread(all: 0)
    public var ivs = StatSpread(all: 31)
    public var gender: String = ""
    public var level: Int = 100
    public var shiny: Bool = false
    public var happiness: Int = 255
    public var teraType: String = ""
    public var hiddenPowerType: String = ""
    public var gigantamax: Bool = false

    public init(species: String = "") {
        self.species = species
    }

    public var displayName: String { nickname.isEmpty ? species : nickname }

    enum CodingKeys: String, CodingKey {
        case id, nickname, species, item, ability, moves, nature, evs, ivs, gender, level, shiny, happiness, teraType, hiddenPowerType, gigantamax
    }
}

public struct Team: Codable, Hashable, Sendable, Identifiable {
    public var id = UUID()
    public var name: String
    public var format: String
    public var pokemon: [PokemonSet]
    public var updated: Date = Date()

    public init(name: String, format: String, pokemon: [PokemonSet]) {
        self.name = name
        self.format = format
        self.pokemon = pokemon
    }
}

public enum Natures {
    /// nature -> (raised, lowered); neutral natures are absent.
    public static let effects: [String: (plus: String, minus: String)] = [
        "Lonely": ("atk", "def"), "Brave": ("atk", "spe"), "Adamant": ("atk", "spa"), "Naughty": ("atk", "spd"),
        "Bold": ("def", "atk"), "Relaxed": ("def", "spe"), "Impish": ("def", "spa"), "Lax": ("def", "spd"),
        "Timid": ("spe", "atk"), "Hasty": ("spe", "def"), "Jolly": ("spe", "spa"), "Naive": ("spe", "spd"),
        "Modest": ("spa", "atk"), "Mild": ("spa", "def"), "Quiet": ("spa", "spe"), "Rash": ("spa", "spd"),
        "Calm": ("spd", "atk"), "Gentle": ("spd", "def"), "Sassy": ("spd", "spe"), "Careful": ("spd", "spa"),
    ]

    public static let all: [String] = [
        "Adamant", "Bashful", "Bold", "Brave", "Calm", "Careful", "Docile", "Gentle", "Hardy", "Hasty", "Impish",
        "Jolly", "Lax", "Lonely", "Mild", "Modest", "Naive", "Naughty", "Quiet", "Quirky", "Rash", "Relaxed",
        "Sassy", "Serious", "Timid",
    ]

    public static func multiplier(_ nature: String, stat: String) -> Double {
        guard let effect = effects[nature] else { return 1 }
        if effect.plus == stat { return 1.1 }
        if effect.minus == stat { return 0.9 }
        return 1
    }
}

public enum StatCalculator {
    public static func stat(_ key: String, base: Int, iv: Int, ev: Int, level: Int, nature: String) -> Int {
        if key == "hp" {
            if base == 1 { return 1 }
            return (2 * base + iv + ev / 4) * level / 100 + level + 10
        }
        let raw = (2 * base + iv + ev / 4) * level / 100 + 5
        return Int(Double(raw) * Natures.multiplier(nature, stat: key))
    }

    public static func stats(for set: PokemonSet, base: StatSpread) -> StatSpread {
        var out = StatSpread(all: 0)
        for key in StatSpread.keys {
            out[key] = stat(key, base: base[key], iv: set.ivs[key], ev: set.evs[key], level: set.level, nature: set.nature)
        }
        return out
    }
}

// MARK: - Import / export

public enum TeamText {
    /// Parses a Showdown export. Accepts a bare set list or a backup with `=== [format] Name ===` headers.
    public static func importTeams(_ text: String, defaultFormat: String = "gen9ou") -> [Team] {
        var teams: [Team] = []
        var currentName: String?
        var currentFormat = defaultFormat
        var chunk: [String] = []

        func flush() {
            let sets = importSets(chunk.joined(separator: "\n"))
            if !sets.isEmpty || currentName != nil {
                teams.append(Team(name: currentName ?? "Imported Team", format: currentFormat, pokemon: sets))
            }
            chunk = []
        }

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("===") && trimmed.hasSuffix("===") {
                flush()
                var header = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "= "))
                currentFormat = defaultFormat
                if header.hasPrefix("["), let close = header.firstIndex(of: "]") {
                    currentFormat = toID(String(header[header.index(after: header.startIndex)..<close]))
                    header = header[header.index(after: close)...].trimmingCharacters(in: .whitespaces)
                }
                if let slash = header.lastIndex(of: "/") {
                    header = String(header[header.index(after: slash)...])
                }
                currentName = header.isEmpty ? "Untitled" : header
            } else {
                chunk.append(line)
            }
        }
        flush()
        return teams
    }

    public static func importSets(_ text: String) -> [PokemonSet] {
        var sets: [PokemonSet] = []
        var current: PokemonSet?
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                if let set = current { sets.append(set) }
                current = nil
                continue
            }
            if current == nil {
                current = parseHeader(line)
                continue
            }
            parseAttribute(line, into: &current!)
        }
        if let set = current { sets.append(set) }
        return sets.filter { !$0.species.isEmpty }
    }

    static func parseHeader(_ line: String) -> PokemonSet {
        var set = PokemonSet()
        var head = line
        if let at = head.range(of: " @ ", options: .backwards) {
            set.item = head[at.upperBound...].trimmingCharacters(in: .whitespaces)
            head = String(head[..<at.lowerBound])
        }
        head = head.trimmingCharacters(in: .whitespaces)
        if head.hasSuffix(" (M)") || head.hasSuffix(" (F)") {
            set.gender = String(head.dropLast(1).suffix(1))
            head = String(head.dropLast(4))
        }
        if head.hasSuffix(")"), let open = head.range(of: " (", options: .backwards) {
            set.nickname = String(head[..<open.lowerBound])
            set.species = String(head[open.upperBound..<head.index(before: head.endIndex)])
        } else {
            set.species = head
        }
        return set
    }

    static func parseAttribute(_ line: String, into set: inout PokemonSet) {
        func value(after prefix: String) -> String? {
            guard line.lowercased().hasPrefix(prefix.lowercased()) else { return nil }
            return line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        }
        if line.hasPrefix("-") || line.hasPrefix("~") {
            var move = line.dropFirst().trimmingCharacters(in: .whitespaces)
            if move.hasPrefix("Hidden Power [") && move.hasSuffix("]") {
                let type = move.dropFirst("Hidden Power [".count).dropLast()
                set.hiddenPowerType = String(type)
                move = "Hidden Power \(type)"
            }
            if !move.isEmpty { set.moves.append(move) }
        } else if let v = value(after: "Ability:") {
            set.ability = v
        } else if let v = value(after: "Level:") {
            set.level = Int(v) ?? 100
        } else if let v = value(after: "Shiny:") {
            set.shiny = v.lowercased() == "yes"
        } else if let v = value(after: "Happiness:") {
            set.happiness = Int(v) ?? 255
        } else if let v = value(after: "Tera Type:") {
            set.teraType = v
        } else if let v = value(after: "Hidden Power:") {
            set.hiddenPowerType = v
        } else if let v = value(after: "Gigantamax:") {
            set.gigantamax = v.lowercased() == "yes"
        } else if let v = value(after: "EVs:") {
            set.evs = parseSpread(v, base: StatSpread(all: 0))
        } else if let v = value(after: "IVs:") {
            set.ivs = parseSpread(v, base: StatSpread(all: 31))
        } else if line.hasSuffix(" Nature") {
            set.nature = String(line.dropLast(" Nature".count)).trimmingCharacters(in: .whitespaces)
        }
    }

    static func parseSpread(_ text: String, base: StatSpread) -> StatSpread {
        var spread = base
        for part in text.components(separatedBy: "/") {
            let pieces = part.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
            guard pieces.count == 2, let amount = Int(pieces[0]), let key = StatSpread.key(forLabel: String(pieces[1])) else { continue }
            spread[key] = amount
        }
        return spread
    }

    public static func export(_ sets: [PokemonSet]) -> String {
        sets.map(export).joined(separator: "\n")
    }

    public static func export(_ set: PokemonSet) -> String {
        var lines: [String] = []
        var head = set.nickname.isEmpty || set.nickname == set.species ? set.species : "\(set.nickname) (\(set.species))"
        if !set.gender.isEmpty { head += " (\(set.gender))" }
        if !set.item.isEmpty { head += " @ \(set.item)" }
        lines.append(head)
        if !set.ability.isEmpty { lines.append("Ability: \(set.ability)") }
        if set.level != 100 { lines.append("Level: \(set.level)") }
        if set.shiny { lines.append("Shiny: Yes") }
        if set.happiness != 255 { lines.append("Happiness: \(set.happiness)") }
        if set.gigantamax { lines.append("Gigantamax: Yes") }
        if !set.teraType.isEmpty { lines.append("Tera Type: \(set.teraType)") }
        let evs = StatSpread.keys.filter { set.evs[$0] != 0 }.map { "\(set.evs[$0]) \(StatSpread.labels[$0]!)" }
        if !evs.isEmpty { lines.append("EVs: " + evs.joined(separator: " / ")) }
        if !set.nature.isEmpty { lines.append("\(set.nature) Nature") }
        let ivs = StatSpread.keys.filter { set.ivs[$0] != 31 }.map { "\(set.ivs[$0]) \(StatSpread.labels[$0]!)" }
        if !ivs.isEmpty { lines.append("IVs: " + ivs.joined(separator: " / ")) }
        for move in set.moves where !move.isEmpty {
            if move.hasPrefix("Hidden Power "), !set.hiddenPowerType.isEmpty {
                lines.append("- Hidden Power [\(set.hiddenPowerType)]")
            } else {
                lines.append("- \(move)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func exportBackup(_ teams: [Team]) -> String {
        teams.map { "=== [\($0.format)] \($0.name) ===\n\n" + export($0.pokemon) }.joined(separator: "\n")
    }

    // MARK: Packed format (what `/utm` expects)

    static func packName(_ name: String) -> String {
        String(name.unicodeScalars.filter { ("A"..."Z").contains($0) || ("a"..."z").contains($0) || ("0"..."9").contains($0) }.map(Character.init))
    }

    public static func pack(_ sets: [PokemonSet]) -> String {
        sets.map(pack).joined(separator: "]")
    }

    public static func pack(_ set: PokemonSet) -> String {
        func clean(_ text: String) -> String {
            text.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: "]", with: "")
        }
        var buf = clean(set.nickname.isEmpty ? set.species : set.nickname)
        let id = packName(set.species)
        buf += "|" + (packName(set.nickname.isEmpty ? set.species : set.nickname) == id ? "" : id)
        buf += "|" + packName(set.item)
        buf += "|" + packName(set.ability)
        buf += "|" + set.moves.filter { !$0.isEmpty }.map(packName).joined(separator: ",")
        buf += "|" + set.nature
        let evs = StatSpread.keys.map { set.evs[$0] == 0 ? "" : String(set.evs[$0]) }.joined(separator: ",")
        buf += "|" + (evs == ",,,,," ? "" : evs)
        buf += "|" + set.gender
        let ivs = StatSpread.keys.map { set.ivs[$0] == 31 ? "" : String(set.ivs[$0]) }.joined(separator: ",")
        buf += "|" + (ivs == ",,,,," ? "" : ivs)
        buf += "|" + (set.shiny ? "S" : "")
        buf += "|" + (set.level == 100 ? "" : String(set.level))
        buf += "|" + (set.happiness == 255 ? "" : String(set.happiness))
        if !set.hiddenPowerType.isEmpty || set.gigantamax || !set.teraType.isEmpty {
            buf += "," + set.hiddenPowerType
            buf += ","
            buf += "," + (set.gigantamax ? "G" : "")
            buf += ","
            buf += "," + set.teraType
        }
        return buf
    }
}
