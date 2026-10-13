import Foundation

public struct DexSpecies: Decodable, Sendable, Hashable {
    public var num: Int
    public var name: String
    public var types: [String]
    public var baseStats: StatSpread
    public var abilities: [String: String]
    public var baseSpecies: String?
    public var forme: String?
    public var tier: String?
    public var weightkg: Double?
    public var gender: String?

    enum CodingKeys: String, CodingKey {
        case num, name, types, baseStats, abilities, baseSpecies, forme, tier, weightkg, gender
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        num = (try? c.decode(Int.self, forKey: .num)) ?? 0
        name = try c.decode(String.self, forKey: .name)
        types = (try? c.decode([String].self, forKey: .types)) ?? []
        baseStats = (try? c.decode(StatSpread.self, forKey: .baseStats)) ?? StatSpread(all: 0)
        abilities = (try? c.decode([String: String].self, forKey: .abilities)) ?? [:]
        baseSpecies = try? c.decodeIfPresent(String.self, forKey: .baseSpecies)
        forme = try? c.decodeIfPresent(String.self, forKey: .forme)
        tier = try? c.decodeIfPresent(String.self, forKey: .tier)
        weightkg = try? c.decodeIfPresent(Double.self, forKey: .weightkg)
        gender = try? c.decodeIfPresent(String.self, forKey: .gender)
    }

    /// Abilities in slot order: 0, 1, H, S.
    public var abilityList: [String] {
        ["0", "1", "H", "S"].compactMap { abilities[$0] }
    }
}

public struct DexMove: Decodable, Sendable, Hashable {
    public var num: Int
    public var name: String
    public var type: String
    public var category: String
    public var basePower: Int
    public var accuracy: Int?
    public var pp: Int
    public var priority: Int
    public var target: String
    public var shortDesc: String?
    public var isNonstandard: String?

    enum CodingKeys: String, CodingKey {
        case num, name, type, category, basePower, accuracy, pp, priority, target, shortDesc, isNonstandard
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        num = (try? c.decode(Int.self, forKey: .num)) ?? 0
        name = try c.decode(String.self, forKey: .name)
        type = (try? c.decode(String.self, forKey: .type)) ?? "Normal"
        category = (try? c.decode(String.self, forKey: .category)) ?? "Status"
        basePower = (try? c.decode(Int.self, forKey: .basePower)) ?? 0
        accuracy = try? c.decode(Int.self, forKey: .accuracy)  // `true` means never misses
        pp = (try? c.decode(Int.self, forKey: .pp)) ?? 0
        priority = (try? c.decode(Int.self, forKey: .priority)) ?? 0
        target = (try? c.decode(String.self, forKey: .target)) ?? "normal"
        shortDesc = try? c.decodeIfPresent(String.self, forKey: .shortDesc)
        isNonstandard = try? c.decodeIfPresent(String.self, forKey: .isNonstandard)
    }
}

/// Showdown's data tables (`/data/pokedex.json`, `/data/moves.json`, etc.).
public struct DexData: Sendable {
    public var species: [String: DexSpecies]
    public var moves: [String: DexMove]
    /// id -> display name
    public var items: [String: String]
    public var abilities: [String: String]
    /// item id -> index into Showdown's item icon sheet
    public var itemSprites: [String: Int]

    public init(species: [String: DexSpecies] = [:], moves: [String: DexMove] = [:], items: [String: String] = [:], abilities: [String: String] = [:], itemSprites: [String: Int] = [:]) {
        self.species = species
        self.moves = moves
        self.items = items
        self.abilities = abilities
        self.itemSprites = itemSprites
    }

    public static func decodeSpecies(_ data: Data) throws -> [String: DexSpecies] {
        try JSONDecoder().decode([String: LossyEntry<DexSpecies>].self, from: data).compactMapValues(\.value)
    }

    public static func decodeMoves(_ data: Data) throws -> [String: DexMove] {
        try JSONDecoder().decode([String: LossyEntry<DexMove>].self, from: data).compactMapValues(\.value)
    }

    /// Pulls `id:{name:"Display Name"` pairs out of Showdown's `items.js` / `abilities.js`.
    public static func parseNameTable(_ js: String) -> [String: String] {
        var out: [String: String] = [:]
        let pattern = #"([a-z0-9]+):\{name:"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return out }
        let range = NSRange(js.startIndex..., in: js)
        for match in regex.matches(in: js, range: range) {
            guard let idRange = Range(match.range(at: 1), in: js), let nameRange = Range(match.range(at: 2), in: js) else { continue }
            out[String(js[idRange])] = String(js[nameRange])
        }
        return out
    }

    /// Pulls `id:{name:"...",spritenum:N` pairs out of `items.js`.
    public static func parseItemSprites(_ js: String) -> [String: Int] {
        var out: [String: Int] = [:]
        let pattern = #"([a-z0-9]+):\{name:"[^"]+",spritenum:(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return out }
        let range = NSRange(js.startIndex..., in: js)
        for match in regex.matches(in: js, range: range) {
            guard let idRange = Range(match.range(at: 1), in: js), let numRange = Range(match.range(at: 2), in: js),
                  let num = Int(js[numRange]) else { continue }
            out[String(js[idRange])] = num
        }
        return out
    }

    public func species(named name: String) -> DexSpecies? {
        species[toID(name)]
    }

    public func move(named name: String) -> DexMove? {
        moves[toID(name)]
    }

    /// Species usable in current play (skips CAP / custom entries with no number).
    public var playableSpecies: [DexSpecies] {
        species.values.filter { $0.num > 0 && $0.tier != "Illegal" && $0.tier != "CAP" }.sorted { ($0.num, $0.name) < ($1.num, $1.name) }
    }
}

struct LossyEntry<T: Decodable>: Decodable {
    var value: T?
    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

public enum Sprites {
    public static let base = "https://play.pokemonshowdown.com/sprites"

    /// Showdown's sprite file name: base species ID plus `-forme`.
    public static func spriteID(_ species: String, dex: DexData? = nil) -> String {
        var name = species
        if name.hasSuffix("-*") { name = String(name.dropLast(2)) }
        if let entry = dex?.species(named: name) {
            if let base = entry.baseSpecies, let forme = entry.forme {
                return toID(base) + "-" + toID(forme)
            }
            return toID(entry.name)
        }
        if let dex, let hyphen = name.lastIndex(of: "-") {
            // Cosmetic formes (Gastrodon-East) aren't in the dex; find the longest known base.
            var prefixEnd: String.Index? = hyphen
            while let end = prefixEnd {
                let base = String(name[..<end])
                if dex.species(named: base) != nil {
                    return toID(base) + "-" + toID(String(name[name.index(after: end)...]))
                }
                prefixEnd = name[..<end].lastIndex(of: "-")
            }
        }
        let parts = name.split(separator: "-", maxSplits: 1).map(String.init)
        if parts.count == 2, !hyphenatedBases.contains(toID(name)) {
            return toID(parts[0]) + "-" + toID(parts[1])
        }
        return toID(name)
    }

    static let hyphenatedBases: Set<String> = [
        "hooh", "porygonz", "jangmoo", "hakamoo", "kommoo", "tinglu", "chienpao", "wochien", "chiyu", "nidoranf", "nidoranm",
    ]

    public static func battleURLs(species: String, back: Bool, shiny: Bool, dex: DexData?) -> [URL] {
        let id = spriteID(species, dex: dex)
        let suffix = (back ? "-back" : "") + (shiny ? "-shiny" : "")
        return [
            URL(string: "\(base)/ani\(suffix)/\(id).gif"),
            URL(string: "\(base)/gen5\(suffix)/\(id).png"),
            URL(string: "\(base)/gen5\(back ? "-back" : "")/\(id).png"),
        ].compactMap { $0 }
    }

    public static func artworkURLs(species: String, shiny: Bool = false, dex: DexData?) -> [URL] {
        let id = spriteID(species, dex: dex)
        return [
            URL(string: "\(base)/home\(shiny ? "-shiny" : "")/\(id).png"),
            URL(string: "\(base)/dex\(shiny ? "-shiny" : "")/\(id).png"),
            URL(string: "\(base)/gen5/\(id).png"),
        ].compactMap { $0 }
    }

    public static func trainerURL(_ avatar: String) -> URL? {
        let name = avatar.hasPrefix("#") ? String(avatar.dropFirst()) : avatar
        guard !name.isEmpty, Int(name) == nil else { return nil }
        return URL(string: "\(base)/trainers/\(name).png")
    }
}

public enum TypeChart {
    public static let types = [
        "Normal", "Fire", "Water", "Electric", "Grass", "Ice", "Fighting", "Poison", "Ground",
        "Flying", "Psychic", "Bug", "Rock", "Ghost", "Dragon", "Dark", "Steel", "Fairy",
    ]

    /// attacking type -> defending type -> multiplier (only non-1 entries).
    static let chart: [String: [String: Double]] = [
        "Normal": ["Rock": 0.5, "Ghost": 0, "Steel": 0.5],
        "Fire": ["Fire": 0.5, "Water": 0.5, "Grass": 2, "Ice": 2, "Bug": 2, "Rock": 0.5, "Dragon": 0.5, "Steel": 2],
        "Water": ["Fire": 2, "Water": 0.5, "Grass": 0.5, "Ground": 2, "Rock": 2, "Dragon": 0.5],
        "Electric": ["Water": 2, "Electric": 0.5, "Grass": 0.5, "Ground": 0, "Flying": 2, "Dragon": 0.5],
        "Grass": ["Fire": 0.5, "Water": 2, "Grass": 0.5, "Poison": 0.5, "Ground": 2, "Flying": 0.5, "Bug": 0.5, "Rock": 2, "Dragon": 0.5, "Steel": 0.5],
        "Ice": ["Fire": 0.5, "Water": 0.5, "Grass": 2, "Ice": 0.5, "Ground": 2, "Flying": 2, "Dragon": 2, "Steel": 0.5],
        "Fighting": ["Normal": 2, "Ice": 2, "Poison": 0.5, "Flying": 0.5, "Psychic": 0.5, "Bug": 0.5, "Rock": 2, "Ghost": 0, "Dark": 2, "Steel": 2, "Fairy": 0.5],
        "Poison": ["Grass": 2, "Poison": 0.5, "Ground": 0.5, "Rock": 0.5, "Ghost": 0.5, "Steel": 0, "Fairy": 2],
        "Ground": ["Fire": 2, "Electric": 2, "Grass": 0.5, "Poison": 2, "Flying": 0, "Bug": 0.5, "Rock": 2, "Steel": 2],
        "Flying": ["Electric": 0.5, "Grass": 2, "Fighting": 2, "Bug": 2, "Rock": 0.5, "Steel": 0.5],
        "Psychic": ["Fighting": 2, "Poison": 2, "Psychic": 0.5, "Dark": 0, "Steel": 0.5],
        "Bug": ["Fire": 0.5, "Grass": 2, "Fighting": 0.5, "Poison": 0.5, "Flying": 0.5, "Psychic": 2, "Ghost": 0.5, "Dark": 2, "Steel": 0.5, "Fairy": 0.5],
        "Rock": ["Fire": 2, "Ice": 2, "Fighting": 0.5, "Ground": 0.5, "Flying": 2, "Bug": 2, "Steel": 0.5],
        "Ghost": ["Normal": 0, "Psychic": 2, "Ghost": 2, "Dark": 0.5],
        "Dragon": ["Dragon": 2, "Steel": 0.5, "Fairy": 0],
        "Dark": ["Fighting": 0.5, "Psychic": 2, "Ghost": 2, "Dark": 0.5, "Fairy": 0.5],
        "Steel": ["Fire": 0.5, "Water": 0.5, "Electric": 0.5, "Ice": 2, "Rock": 2, "Steel": 0.5, "Fairy": 2],
        "Fairy": ["Fire": 0.5, "Fighting": 2, "Poison": 0.5, "Dragon": 2, "Dark": 2, "Steel": 0.5],
    ]

    public static func multiplier(attack: String, defenders: [String]) -> Double {
        defenders.reduce(1) { $0 * (chart[attack]?[$1] ?? 1) }
    }
}
