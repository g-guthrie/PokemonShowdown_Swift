import Foundation

/// The JSON payload of `|request|`: what the server is asking this player to decide.
public struct BattleRequest: Decodable, Sendable, Equatable {
    public var rqid: Int?
    public var wait: Bool
    public var teamPreview: Bool
    public var maxChosenTeamSize: Int?
    public var forceSwitch: [Bool]?
    public var active: [ActiveRequest]
    public var side: RequestSide
    public var noCancel: Bool

    public enum Kind: Sendable, Equatable {
        case wait, teamPreview, forceSwitch, move
    }

    public var kind: Kind {
        if wait { return .wait }
        if teamPreview { return .teamPreview }
        if let forceSwitch, forceSwitch.contains(true) { return .forceSwitch }
        return .move
    }

    enum CodingKeys: String, CodingKey {
        case rqid, wait, teamPreview, maxChosenTeamSize, forceSwitch, active, side, noCancel
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rqid = try? c.decodeIfPresent(Int.self, forKey: .rqid)
        wait = (try? c.decodeIfPresent(Bool.self, forKey: .wait)) ?? false
        teamPreview = (try? c.decodeIfPresent(Bool.self, forKey: .teamPreview)) ?? false
        maxChosenTeamSize = try? c.decodeIfPresent(Int.self, forKey: .maxChosenTeamSize)
        forceSwitch = try? c.decodeIfPresent([Bool].self, forKey: .forceSwitch)
        active = (try? c.decodeIfPresent([ActiveRequest].self, forKey: .active)) ?? []
        side = try c.decode(RequestSide.self, forKey: .side)
        noCancel = (try? c.decodeIfPresent(Bool.self, forKey: .noCancel)) ?? false
    }

    public static func parse(_ json: String) -> BattleRequest? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(BattleRequest.self, from: data)
    }
}

public struct ActiveRequest: Decodable, Sendable, Equatable {
    public var moves: [RequestMove]
    public var trapped: Bool
    public var maybeTrapped: Bool
    public var canTerastallize: String?
    public var canMegaEvo: Bool
    public var canDynamax: Bool

    enum CodingKeys: String, CodingKey {
        case moves, trapped, maybeTrapped, canTerastallize, canMegaEvo, canDynamax
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        moves = (try? c.decodeIfPresent([RequestMove].self, forKey: .moves)) ?? []
        trapped = (try? c.decodeIfPresent(Bool.self, forKey: .trapped)) ?? false
        maybeTrapped = (try? c.decodeIfPresent(Bool.self, forKey: .maybeTrapped)) ?? false
        canTerastallize = try? c.decodeIfPresent(String.self, forKey: .canTerastallize)
        canMegaEvo = (try? c.decodeIfPresent(Bool.self, forKey: .canMegaEvo)) ?? false
        canDynamax = (try? c.decodeIfPresent(Bool.self, forKey: .canDynamax)) ?? false
    }
}

public struct RequestMove: Decodable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var pp: Int?
    public var maxPP: Int?
    public var target: String?
    public var disabled: Bool

    enum CodingKeys: String, CodingKey {
        case id, move, pp, maxpp, target, disabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .move)) ?? ""
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? toID(name)
        pp = try? c.decodeIfPresent(Int.self, forKey: .pp)
        maxPP = try? c.decodeIfPresent(Int.self, forKey: .maxpp)
        target = try? c.decodeIfPresent(String.self, forKey: .target)
        if let flag = try? c.decodeIfPresent(Bool.self, forKey: .disabled) {
            disabled = flag
        } else if let source = try? c.decodeIfPresent(String.self, forKey: .disabled) {
            disabled = !source.isEmpty
        } else {
            disabled = false
        }
    }

    /// Whether a doubles move needs the player to pick a target.
    public var needsTarget: Bool {
        ["normal", "any", "adjacentAlly", "adjacentFoe", "adjacentAllyOrSelf"].contains(target ?? "")
    }
}

public struct RequestSide: Decodable, Sendable, Equatable {
    public var name: String
    public var id: String
    public var pokemon: [RequestPokemon]
}

public struct RequestPokemon: Decodable, Sendable, Equatable, Identifiable {
    public var ident: String
    public var details: String
    public var condition: String
    public var active: Bool
    public var stats: [String: Int]
    public var moves: [String]
    public var baseAbility: String?
    public var ability: String?
    public var item: String
    public var teraType: String?
    public var terastallized: String?
    public var commanding: Bool
    public var reviving: Bool

    public var id: String { ident }
    public var name: String { PokemonIdent(ident)?.name ?? ident }
    public var parsedDetails: PokemonDetails { PokemonDetails(details) }
    public var health: HealthStatus { HealthStatus(condition) }

    enum CodingKeys: String, CodingKey {
        case ident, details, condition, active, stats, moves, baseAbility, ability, item, teraType, terastallized, commanding, reviving
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ident = try c.decode(String.self, forKey: .ident)
        details = (try? c.decode(String.self, forKey: .details)) ?? ""
        condition = (try? c.decode(String.self, forKey: .condition)) ?? ""
        active = (try? c.decodeIfPresent(Bool.self, forKey: .active)) ?? false
        stats = (try? c.decodeIfPresent([String: Int].self, forKey: .stats)) ?? [:]
        moves = (try? c.decodeIfPresent([String].self, forKey: .moves)) ?? []
        baseAbility = try? c.decodeIfPresent(String.self, forKey: .baseAbility)
        ability = try? c.decodeIfPresent(String.self, forKey: .ability)
        item = (try? c.decodeIfPresent(String.self, forKey: .item)) ?? ""
        teraType = try? c.decodeIfPresent(String.self, forKey: .teraType)
        let tera = try? c.decodeIfPresent(String.self, forKey: .terastallized)
        terastallized = (tera?.isEmpty ?? true) ? nil : tera
        commanding = (try? c.decodeIfPresent(Bool.self, forKey: .commanding)) ?? false
        reviving = (try? c.decodeIfPresent(Bool.self, forKey: .reviving)) ?? false
    }
}

/// Builds the text after `/choose`.
public enum BattleChoice: Sendable, Equatable {
    case move(index: Int, target: Int? = nil, terastallize: Bool = false, mega: Bool = false)
    case switchTo(index: Int)
    case pass
    case shift

    public var command: String {
        switch self {
        case let .move(index, target, tera, mega):
            var out = "move \(index)"
            if let target { out += " \(target)" }
            if tera { out += " terastallize" }
            if mega { out += " mega" }
            return out
        case let .switchTo(index):
            return "switch \(index)"
        case .pass:
            return "pass"
        case .shift:
            return "shift"
        }
    }

    public static func join(_ choices: [BattleChoice]) -> String {
        choices.map(\.command).joined(separator: ", ")
    }
}
