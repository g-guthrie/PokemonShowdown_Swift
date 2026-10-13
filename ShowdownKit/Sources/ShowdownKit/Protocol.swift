import Foundation

/// Showdown's canonical ID: lowercase ASCII letters and digits only.
public func toID(_ text: String) -> String {
    var out = String.UnicodeScalarView()
    for scalar in text.lowercased().unicodeScalars {
        if ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) {
            out.append(scalar)
        }
    }
    return String(out)
}

/// One websocket message from the server: an optional `>roomid` header followed by lines.
public struct ServerFrame: Sendable, Equatable {
    /// Empty for global messages.
    public var roomID: String
    public var lines: [String]

    public init(roomID: String, lines: [String]) {
        self.roomID = roomID
        self.lines = lines
    }

    public init(raw: String) {
        var body = Substring(raw)
        if body.hasPrefix(">") {
            if let newline = body.firstIndex(of: "\n") {
                roomID = String(body[body.index(after: body.startIndex)..<newline])
                body = body[body.index(after: newline)...]
            } else {
                roomID = String(body.dropFirst())
                body = ""
            }
        } else {
            roomID = ""
        }
        lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
}

/// A single protocol line such as `|move|p1a: Goodra|Thunderbolt|p2a: Raikou|[miss]`.
public struct ProtocolLine: Sendable, Equatable {
    public var kind: String
    public var args: [String]
    /// Trailing `[key] value` arguments of battle messages.
    public var kwArgs: [String: String]
    public var raw: String

    /// For these kinds the final argument may itself contain `|`, so we cap the split.
    private static let maxArgs: [String: Int] = [
        "request": 1, "raw": 1, "html": 1, "popup": 1, "error": 1, "challstr": 1,
        "updatesearch": 1, "updatechallenges": 1, "title": 1, "inactive": 1, "inactiveoff": 1,
        "message": 1, "-message": 1, "bigerror": 1, "debug": 1, "-hint": 1,
        "c": 2, "chat": 2, "c:": 3, "pm": 3, "uhtml": 2, "uhtmlchange": 2,
        "queryresponse": 2, "nametaken": 2, "updateuser": 4,
    ]

    public init(_ line: String) {
        raw = line
        kwArgs = [:]
        guard line.hasPrefix("|") else {
            kind = ""
            args = [line]
            return
        }
        var parts = line.dropFirst().split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        kind = parts.isEmpty ? "" : parts.removeFirst()
        if let max = Self.maxArgs[kind], parts.count > max {
            let head = Array(parts[0..<(max - 1)])
            let tail = parts[(max - 1)...].joined(separator: "|")
            parts = head + [tail]
        }
        if Self.isBattleKind(kind) {
            while let last = parts.last, last.hasPrefix("["), let close = last.firstIndex(of: "]") {
                let key = String(last[last.index(after: last.startIndex)..<close])
                let value = last[last.index(after: close)...].trimmingCharacters(in: .whitespaces)
                kwArgs[key] = value
                parts.removeLast()
            }
        }
        args = parts
    }

    public subscript(_ index: Int) -> String {
        index < args.count ? args[index] : ""
    }

    private static func isBattleKind(_ kind: String) -> Bool {
        kind.hasPrefix("-") || ["move", "switch", "drag", "replace", "cant", "faint", "detailschange", "swap"].contains(kind)
    }
}

/// `p1a: Goodra` or `p1: Goodra`.
public struct PokemonIdent: Sendable, Equatable, Hashable {
    public var side: String
    /// 0-based active slot, if the ident names one.
    public var slot: Int?
    public var name: String

    public init?(_ text: String) {
        guard text.count >= 2, text.hasPrefix("p") else { return nil }
        let chars = Array(text)
        guard chars[1].isNumber else { return nil }
        side = String(chars[0...1])
        var rest = text.dropFirst(2)
        if let first = rest.first, first.isLetter, first != ":" {
            slot = Int(first.asciiValue ?? 97) - 97
            rest = rest.dropFirst()
        } else {
            slot = nil
        }
        if rest.hasPrefix(": ") {
            name = String(rest.dropFirst(2))
        } else if rest.hasPrefix(":") {
            name = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else {
            name = String(rest).trimmingCharacters(in: .whitespaces)
        }
    }
}

/// `Goodra, L86, M, shiny, tera:Water`.
public struct PokemonDetails: Sendable, Equatable, Hashable {
    public var species: String
    public var level: Int
    public var gender: String?
    public var shiny: Bool
    public var teraType: String?

    public init(species: String, level: Int = 100, gender: String? = nil, shiny: Bool = false, teraType: String? = nil) {
        self.species = species
        self.level = level
        self.gender = gender
        self.shiny = shiny
        self.teraType = teraType
    }

    public init(_ text: String) {
        let parts = text.components(separatedBy: ", ")
        var species = parts.first ?? ""
        if species.hasSuffix("-*") { species = String(species.dropLast(2)) }
        self.species = species
        level = 100
        gender = nil
        shiny = false
        teraType = nil
        for part in parts.dropFirst() {
            if part == "M" || part == "F" {
                gender = part
            } else if part == "shiny" {
                shiny = true
            } else if part.hasPrefix("tera:") {
                teraType = String(part.dropFirst(5))
            } else if part.hasPrefix("L"), let lvl = Int(part.dropFirst()) {
                level = lvl
            }
        }
    }
}

/// `231/295 par`, `0 fnt`, `80/100`.
public struct HealthStatus: Sendable, Equatable {
    public var hp: Int
    public var maxHP: Int
    public var status: String?
    public var fainted: Bool

    public init(_ text: String) {
        let pieces = text.split(separator: " ")
        let hpPart = pieces.first.map(String.init) ?? ""
        let statusPart = pieces.count > 1 ? String(pieces[1]) : nil
        let numbers = hpPart.split(separator: "/").map { Int($0.filter(\.isNumber)) ?? 0 }
        hp = numbers.first ?? 0
        maxHP = numbers.count > 1 ? numbers[1] : 0
        fainted = statusPart == "fnt" || (hp == 0 && hpPart.hasPrefix("0"))
        status = (statusPart == "fnt") ? nil : statusPart
        if fainted { hp = 0 }
    }

    public var fraction: Double {
        if fainted { return 0 }
        guard maxHP > 0 else { return 1 }
        return Double(hp) / Double(maxHP)
    }
}
