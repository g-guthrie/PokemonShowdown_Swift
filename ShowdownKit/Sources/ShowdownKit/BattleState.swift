import Foundation

public struct SlotRef: Sendable, Hashable {
    public var side: String
    public var slot: Int

    public init(side: String, slot: Int) {
        self.side = side
        self.slot = slot
    }
}

public struct BattlePokemon: Identifiable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var species: String
    public var level: Int
    public var gender: String?
    public var shiny: Bool
    public var hp: Int
    public var maxHP: Int
    public var status: String?
    public var fainted: Bool
    public var boosts: [String: Int] = [:]
    public var volatiles: [String] = []
    public var teraType: String?
    public var terastallized: String?
    public var item: String?
    public var ability: String?
    public var revealedMoves: [String] = []
    /// Seen only at team preview, not yet in battle.
    public var previewOnly: Bool = false

    public var hpFraction: Double {
        if fainted { return 0 }
        guard maxHP > 0 else { return 1 }
        return min(1, max(0, Double(hp) / Double(maxHP)))
    }

    public var hpPercent: Int {
        let percent = hpFraction * 100
        if percent > 0 && percent < 1 { return 1 }
        return Int(percent.rounded())
    }

    mutating func apply(details: PokemonDetails) {
        species = details.species
        level = details.level
        gender = details.gender
        shiny = details.shiny
        if let tera = details.teraType { terastallized = tera }
    }

    mutating func apply(health: HealthStatus) {
        hp = health.hp
        if health.maxHP > 0 { maxHP = health.maxHP }
        status = health.status
        fainted = health.fainted
    }
}

public struct BattleSide: Identifiable, Sendable, Equatable {
    public var id: String
    public var name: String = ""
    public var avatar: String = ""
    public var rating: String = ""
    public var teamSize: Int = 0
    public var pokemon: [BattlePokemon] = []
    public var active: [Int?] = [nil]
    /// Hazards and screens, with layer count.
    public var conditions: [String: Int] = [:]
    public var conditionOrder: [String] = []

    public init(id: String) {
        self.id = id
    }

    public func activePokemon(_ slot: Int) -> BattlePokemon? {
        guard slot < active.count, let index = active[slot], index < pokemon.count else { return nil }
        return pokemon[index]
    }

    public var faintedCount: Int { pokemon.filter(\.fainted).count }
}

public enum Effectiveness: Sendable, Equatable {
    case superEffective, resisted, immune
}

/// Something visual the UI can animate. Emitted as lines are applied.
public enum BattleEvent: Sendable, Equatable {
    case switchIn(SlotRef)
    case move(SlotRef, move: String, target: SlotRef?)
    case damage(SlotRef, amount: Double)
    case heal(SlotRef, amount: Double)
    case faint(SlotRef)
    case status(SlotRef, String)
    case boost(SlotRef, stat: String, amount: Int)
    case crit(SlotRef)
    case effectiveness(SlotRef, Effectiveness)
    case miss(SlotRef)
    case ability(SlotRef, String)
    case terastallize(SlotRef, String)
    case turn(Int)
    case weather(String?)
    case end(winner: String?)
}

public struct BattleLogEntry: Identifiable, Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case turn, action, effect, minor, chat, system, error, result
    }

    public var id: Int
    public var kind: Kind
    public var text: String
    public var side: String?
    public var author: String?
}

public struct BattleState: Sendable, Equatable {
    public var roomID: String
    public var title: String = ""
    public var gameType: String = "singles"
    public var gen: Int = 9
    public var tier: String = ""
    public var rules: [String] = []
    public var turn: Int = 0
    public var started: Bool = false
    public var sides: [String: BattleSide] = [:]
    public var weather: String?
    public var fields: [String] = []
    public var log: [BattleLogEntry] = []
    public var ended: Bool = false
    public var winner: String?
    public var timerMessage: String?
    public var inTeamPreview: Bool = false
    /// Which side is drawn at the bottom; set to the player's own side.
    public var perspective: String = "p1"

    private var nextLogID = 0
    private var pendingSplit: (side: String, remaining: Int)?

    public init(roomID: String) {
        self.roomID = roomID
    }

    public static func == (lhs: BattleState, rhs: BattleState) -> Bool {
        lhs.roomID == rhs.roomID && lhs.turn == rhs.turn && lhs.sides == rhs.sides && lhs.log == rhs.log
            && lhs.weather == rhs.weather && lhs.fields == rhs.fields && lhs.ended == rhs.ended
            && lhs.timerMessage == rhs.timerMessage && lhs.inTeamPreview == rhs.inTeamPreview
            && lhs.perspective == rhs.perspective && lhs.title == rhs.title
    }

    public var activesPerSide: Int {
        switch gameType {
        case "doubles": return 2
        case "triples": return 3
        default: return 1
        }
    }

    public var opponentSideID: String {
        perspective == "p1" ? "p2" : "p1"
    }

    public var mySide: BattleSide? { sides[perspective] }
    public var opponentSide: BattleSide? { sides[opponentSideID] }

    public func pokemon(at ref: SlotRef) -> BattlePokemon? {
        sides[ref.side]?.activePokemon(ref.slot)
    }

    // MARK: - Applying protocol

    @discardableResult
    public mutating func apply(_ rawLine: String) -> [BattleEvent] {
        // `|split|p1` is followed by a private line (exact HP) and a public one.
        if let split = pendingSplit {
            let isSecret = split.remaining == 2
            pendingSplit = split.remaining > 1 ? (split.side, split.remaining - 1) : nil
            let mine = split.side == perspective
            if isSecret != mine { return [] }
        }
        let line = ProtocolLine(rawLine)
        if line.kind == "split" {
            pendingSplit = (line[0], 2)
            return []
        }
        return apply(line)
    }

    @discardableResult
    public mutating func apply(_ line: ProtocolLine) -> [BattleEvent] {
        switch line.kind {
        case "title":
            title = line[0]
        case "gametype":
            gameType = line[0]
            for key in sides.keys { resizeActive(key) }
        case "gen":
            gen = Int(line[0]) ?? gen
        case "tier":
            tier = line[0]
        case "rule":
            rules.append(line[0])
        case "player":
            var side = sides[line[0]] ?? BattleSide(id: line[0])
            if !line[1].isEmpty { side.name = line[1] }
            if !line[2].isEmpty { side.avatar = line[2] }
            if !line[3].isEmpty { side.rating = line[3] }
            sides[line[0]] = side
            resizeActive(line[0])
        case "teamsize":
            ensureSide(line[0])
            sides[line[0]]?.teamSize = Int(line[1]) ?? 0
        case "clearpoke":
            inTeamPreview = true
            for key in sides.keys { sides[key]?.pokemon.removeAll { $0.previewOnly } }
        case "poke":
            ensureSide(line[0])
            let details = PokemonDetails(line[1])
            var mon = makePokemon(side: line[0], name: details.species, details: details)
            mon.previewOnly = true
            sides[line[0]]?.pokemon.append(mon)
        case "teampreview":
            inTeamPreview = true
        case "start":
            started = true
            inTeamPreview = false
            for key in sides.keys { sides[key]?.pokemon.removeAll { $0.previewOnly } }
            addLog(.system, "Battle started between \(sides["p1"]?.name ?? "p1") and \(sides["p2"]?.name ?? "p2")!")
        case "turn":
            turn = Int(line[0]) ?? turn + 1
            for key in sides.keys {
                for index in sides[key]!.pokemon.indices {
                    sides[key]!.pokemon[index].volatiles.removeAll { Self.singleTurnVolatiles.contains($0) }
                }
            }
            addLog(.turn, "Turn \(turn)")
            return [.turn(turn)]
        case "switch", "drag", "replace":
            return applySwitch(line)
        case "detailschange", "-formechange":
            guard let ref = slotRef(line[0]) else { break }
            mutate(ref) { mon in
                let details = PokemonDetails(line[1])
                mon.species = details.species
                if !line[2].isEmpty { mon.apply(health: HealthStatus(line[2])) }
            }
        case "swap":
            guard let ref = slotRef(line[0]), let target = Int(line[1]), var side = sides[ref.side],
                  target < side.active.count, ref.slot < side.active.count else { break }
            side.active.swapAt(ref.slot, target)
            sides[ref.side] = side
        case "move":
            return applyMove(line)
        case "cant":
            guard let ref = slotRef(line[0]) else { break }
            addLog(.effect, BattleText.cant(name(ref), reason: line[1], move: line[2]), side: ref.side)
        case "faint":
            guard let ref = slotRef(line[0]) else { break }
            mutate(ref) { mon in
                mon.hp = 0
                mon.fainted = true
                mon.status = nil
                mon.boosts = [:]
                mon.volatiles = []
            }
            addLog(.action, "\(name(ref)) fainted!", side: ref.side)
            return [.faint(ref)]
        case "-damage", "-heal", "-sethp":
            return applyHealthChange(line)
        case "-status":
            guard let ref = slotRef(line[0]) else { break }
            mutate(ref) { $0.status = line[1] }
            addLog(.effect, BattleText.status(name(ref), status: line[1]), side: ref.side)
            return [.status(ref, line[1])]
        case "-curestatus":
            if let ref = slotRef(line[0]) {
                mutate(ref) { $0.status = nil }
                addLog(.effect, BattleText.cureStatus(name(ref), status: line[1]), side: ref.side)
            } else if let ident = PokemonIdent(line[0]), let index = indexOf(ident: ident) {
                sides[ident.side]?.pokemon[index].status = nil
            }
        case "-cureteam":
            if let ident = PokemonIdent(line[0]) {
                for index in sides[ident.side]?.pokemon.indices ?? 0..<0 {
                    sides[ident.side]?.pokemon[index].status = nil
                }
                addLog(.effect, "\(ident.name)'s team was cured of its status conditions!")
            }
        case "-boost", "-unboost":
            guard let ref = slotRef(line[0]) else { break }
            let amount = (Int(line[2]) ?? 0) * (line.kind == "-unboost" ? -1 : 1)
            mutate(ref) { mon in
                mon.boosts[line[1], default: 0] = max(-6, min(6, mon.boosts[line[1], default: 0] + amount))
                if mon.boosts[line[1]] == 0 { mon.boosts[line[1]] = nil }
            }
            addLog(.effect, BattleText.boost(name(ref), stat: line[1], amount: amount), side: ref.side)
            return [.boost(ref, stat: line[1], amount: amount)]
        case "-setboost":
            guard let ref = slotRef(line[0]) else { break }
            mutate(ref) { $0.boosts[line[1]] = Int(line[2]) }
        case "-clearboost", "-clearpositiveboost":
            guard let ref = slotRef(line[0]) else { break }
            mutate(ref) { mon in
                mon.boosts = line.kind == "-clearboost" ? [:] : mon.boosts.filter { $0.value < 0 }
            }
            addLog(.effect, "\(name(ref))'s stat changes were removed!", side: ref.side)
        case "-clearnegativeboost":
            guard let ref = slotRef(line[0]) else { break }
            mutate(ref) { mon in mon.boosts = mon.boosts.filter { $0.value > 0 } }
        case "-clearallboost":
            for key in sides.keys {
                for index in sides[key]!.pokemon.indices { sides[key]!.pokemon[index].boosts = [:] }
            }
            addLog(.effect, "All stat changes were eliminated!")
        case "-invertboost":
            guard let ref = slotRef(line[0]) else { break }
            mutate(ref) { mon in mon.boosts = mon.boosts.mapValues { -$0 } }
        case "-copyboost":
            guard let source = slotRef(line[0]), let target = slotRef(line[1]),
                  let boosts = pokemon(at: target)?.boosts else { break }
            mutate(source) { $0.boosts = boosts }
        case "-swapboost":
            guard let source = slotRef(line[0]), let target = slotRef(line[1]),
                  let a = pokemon(at: source), let b = pokemon(at: target) else { break }
            mutate(source) { $0.boosts = b.boosts }
            mutate(target) { $0.boosts = a.boosts }
        case "-weather":
            let effect = line[0]
            if effect == "none" || effect.isEmpty {
                if let old = weather { addLog(.effect, BattleText.weatherEnd(old)) }
                weather = nil
                return [.weather(nil)]
            }
            if line.kwArgs["upkeep"] != nil {
                addLog(.minor, BattleText.weatherUpkeep(effect))
                return []
            }
            weather = effect
            addLog(.effect, BattleText.weatherStart(effect))
            return [.weather(effect)]
        case "-fieldstart":
            let effect = BattleText.effectName(line[0])
            if !fields.contains(effect) { fields.append(effect) }
            addLog(.effect, "\(effect) took effect!")
        case "-fieldend":
            let effect = BattleText.effectName(line[0])
            fields.removeAll { $0 == effect }
            addLog(.effect, "\(effect) ended.")
        case "-sidestart":
            guard let sideID = PokemonIdent(line[0])?.side ?? sideID(from: line[0]) else { break }
            let effect = BattleText.effectName(line[1])
            ensureSide(sideID)
            if sides[sideID]?.conditions[effect] == nil { sides[sideID]?.conditionOrder.append(effect) }
            sides[sideID]?.conditions[effect, default: 0] += 1
            addLog(.effect, BattleText.sideStart(effect, foe: sideID != perspective))
        case "-sideend":
            guard let sideID = PokemonIdent(line[0])?.side ?? sideID(from: line[0]) else { break }
            let effect = BattleText.effectName(line[1])
            sides[sideID]?.conditions[effect] = nil
            sides[sideID]?.conditionOrder.removeAll { $0 == effect }
            addLog(.effect, "\(effect) wore off \(sideID == perspective ? "your" : "the opposing") side.")
        case "-swapsideconditions":
            if var p1 = sides["p1"], var p2 = sides["p2"] {
                swap(&p1.conditions, &p2.conditions)
                swap(&p1.conditionOrder, &p2.conditionOrder)
                sides["p1"] = p1
                sides["p2"] = p2
            }
        case "-start":
            guard let ref = slotRef(line[0]) else { break }
            let effect = BattleText.effectName(line[1])
            if effect == "typechange" || line[1] == "typechange" {
                addLog(.effect, "\(name(ref)) transformed into the \(line[2]) type!", side: ref.side)
                break
            }
            mutate(ref) { mon in if !mon.volatiles.contains(effect) { mon.volatiles.append(effect) } }
            if line.kwArgs["silent"] == nil {
                addLog(.effect, BattleText.volatileStart(name(ref), effect: effect), side: ref.side)
            }
        case "-end":
            guard let ref = slotRef(line[0]) else { break }
            let effect = BattleText.effectName(line[1])
            mutate(ref) { mon in mon.volatiles.removeAll { $0 == effect } }
            if line.kwArgs["silent"] == nil {
                addLog(.minor, BattleText.volatileEnd(name(ref), effect: effect), side: ref.side)
            }
        case "-singleturn":
            guard let ref = slotRef(line[0]) else { break }
            let effect = BattleText.effectName(line[1])
            mutate(ref) { mon in if !mon.volatiles.contains(effect) { mon.volatiles.append(effect) } }
            if let text = BattleText.singleTurn(name(ref), effect: effect) {
                addLog(.effect, text, side: ref.side)
            }
        case "-activate":
            guard let ref = slotRef(line[0]) else { break }
            if let text = BattleText.activate(name(ref), effect: BattleText.effectName(line[1])) {
                addLog(.effect, text, side: ref.side)
            }
        case "-crit":
            guard let ref = slotRef(line[0]) else { break }
            addLog(.effect, activesPerSide > 1 ? "A critical hit on \(name(ref))!" : "A critical hit!", side: ref.side)
            return [.crit(ref)]
        case "-supereffective":
            guard let ref = slotRef(line[0]) else { break }
            addLog(.effect, activesPerSide > 1 ? "It's super effective on \(name(ref))!" : "It's super effective!", side: ref.side)
            return [.effectiveness(ref, .superEffective)]
        case "-resisted":
            guard let ref = slotRef(line[0]) else { break }
            addLog(.effect, activesPerSide > 1 ? "It's not very effective on \(name(ref))..." : "It's not very effective...", side: ref.side)
            return [.effectiveness(ref, .resisted)]
        case "-immune":
            guard let ref = slotRef(line[0]) else { break }
            addLog(.effect, "It doesn't affect \(name(ref))...", side: ref.side)
            return [.effectiveness(ref, .immune)]
        case "-miss":
            let target = slotRef(line[1]) ?? slotRef(line[0])
            if let target {
                addLog(.effect, "\(name(target)) avoided the attack!", side: target.side)
                return [.miss(target)]
            }
        case "-fail":
            addLog(.effect, "But it failed!")
        case "-notarget":
            addLog(.effect, "But there was no target...")
        case "-nothing":
            addLog(.effect, "But nothing happened!")
        case "-ohko":
            addLog(.effect, "It's a one-hit KO!")
        case "-hitcount":
            let count = Int(line[1]) ?? 1
            addLog(.effect, "The Pokémon was hit \(count) time\(count == 1 ? "" : "s")!")
        case "-ability":
            guard let ref = slotRef(line[0]) else { break }
            let ability = line[1]
            mutate(ref) { $0.ability = ability }
            addLog(.effect, "[\(name(ref))'s \(ability)]", side: ref.side)
            return [.ability(ref, ability)]
        case "-endability":
            guard let ref = slotRef(line[0]) else { break }
            addLog(.effect, "\(name(ref))'s Ability was suppressed!", side: ref.side)
        case "-item":
            guard let ref = slotRef(line[0]) else { break }
            mutate(ref) { $0.item = line[1] }
            addLog(.effect, BattleText.item(name(ref), item: line[1], from: line.kwArgs["from"]), side: ref.side)
        case "-enditem":
            guard let ref = slotRef(line[0]) else { break }
            mutate(ref) { $0.item = "" }
            addLog(.effect, BattleText.endItem(name(ref), item: line[1], eaten: line.kwArgs["eat"] != nil, from: line.kwArgs["from"]), side: ref.side)
        case "-terastallize":
            guard let ref = slotRef(line[0]) else { break }
            mutate(ref) { $0.terastallized = line[1] }
            addLog(.action, "\(name(ref)) has Terastallized into the \(line[1]) type!", side: ref.side)
            return [.terastallize(ref, line[1])]
        case "-mega":
            guard let ref = slotRef(line[0]) else { break }
            addLog(.action, "\(name(ref)) has Mega Evolved into \(line[1])!", side: ref.side)
        case "-primal":
            guard let ref = slotRef(line[0]) else { break }
            addLog(.action, "\(name(ref))'s Primal Reversion! It reverted to its primal form!", side: ref.side)
        case "-zpower":
            guard let ref = slotRef(line[0]) else { break }
            addLog(.action, "\(name(ref)) surrounded itself with its Z-Power!", side: ref.side)
        case "-transform":
            guard let ref = slotRef(line[0]) else { break }
            let targetName = slotRef(line[1]).map { pokemon(at: $0)?.species ?? "" } ?? PokemonIdent(line[1])?.name ?? line[1]
            addLog(.effect, "\(name(ref)) transformed into \(targetName)!", side: ref.side)
        case "-prepare":
            guard let ref = slotRef(line[0]) else { break }
            addLog(.effect, "\(name(ref)) is preparing \(line[1])!", side: ref.side)
        case "-mustrecharge":
            break
        case "-hint", "-message", "message":
            addLog(.system, line[0])
        case "-center", "-combine", "-waiting", "upkeep", "done", "", "t:", "j", "J", "l", "L", "n", "N", "init", "deinit", "join", "leave", "name", "gen5", "badge", "seed", "teampreviewturn", "debug", "-anim", "uhtml", "uhtmlchange", "notify", "tempnotify", "tempnotifyoff", "unlink", "hidelines", "controlshtml", "fieldhtml", "sentchoice", "bigerror":
            break
        case "c", "chat":
            addChat(user: line[0], message: line[1])
        case "c:":
            addChat(user: line[1], message: line[2])
        case "raw", "html":
            let text = BattleText.stripHTML(line[0])
            if !text.isEmpty { addLog(.system, text) }
        case "error":
            addLog(.error, line[0])
        case "inactive":
            timerMessage = line[0]
            addLog(.minor, line[0])
        case "inactiveoff":
            timerMessage = nil
            addLog(.minor, line[0].isEmpty ? "Battle timer is now OFF." : line[0])
        case "win":
            ended = true
            winner = line[0]
            addLog(.result, "\(line[0]) won the battle!")
            return [.end(winner: line[0])]
        case "tie":
            ended = true
            addLog(.result, "Tie between \(sides["p1"]?.name ?? "p1") and \(sides["p2"]?.name ?? "p2")!")
            return [.end(winner: nil)]
        default:
            if line.kind.isEmpty, let text = line.args.first, !text.isEmpty {
                addLog(.system, text)
            }
        }
        return []
    }

    // MARK: - Specific handlers

    private mutating func applySwitch(_ line: ProtocolLine) -> [BattleEvent] {
        guard let ident = PokemonIdent(line[0]), let slot = ident.slot else { return [] }
        let details = PokemonDetails(line[1])
        let health = line[2].isEmpty ? nil : HealthStatus(line[2])
        ensureSide(ident.side)
        resizeActive(ident.side)
        var side = sides[ident.side]!

        if slot < side.active.count, let previous = side.active[slot], previous < side.pokemon.count {
            side.pokemon[previous].boosts = [:]
            side.pokemon[previous].volatiles = []
        }

        let index: Int
        if line.kind == "replace", slot < side.active.count, let current = side.active[slot] {
            // Illusion broke: the active Pokemon was someone else all along.
            if let existing = side.pokemon.firstIndex(where: { $0.name == ident.name && $0.species == details.species }) {
                index = existing
            } else {
                side.pokemon.append(makePokemon(side: ident.side, name: ident.name, details: details))
                index = side.pokemon.count - 1
            }
            if current != index { side.pokemon[current].volatiles = [] }
        } else if let existing = side.pokemon.firstIndex(where: { $0.name == ident.name && !$0.previewOnly && Self.sameBase($0.species, details.species) }) {
            index = existing
        } else if let existing = side.pokemon.firstIndex(where: { $0.name == ident.name && !$0.previewOnly }) {
            index = existing
        } else {
            side.pokemon.append(makePokemon(side: ident.side, name: ident.name, details: details))
            index = side.pokemon.count - 1
        }

        side.pokemon[index].apply(details: details)
        if let health { side.pokemon[index].apply(health: health) }
        if slot >= side.active.count {
            side.active += Array(repeating: nil, count: slot - side.active.count + 1)
        }
        side.active[slot] = index
        sides[ident.side] = side

        let ref = SlotRef(side: ident.side, slot: slot)
        switch line.kind {
        case "drag":
            addLog(.action, "\(name(ref)) was dragged out!", side: ident.side)
        case "replace":
            break
        default:
            if ident.side == perspective {
                addLog(.action, "Go! \(ident.name)!", side: ident.side)
            } else {
                addLog(.action, "\(side.name.isEmpty ? "The opponent" : side.name) sent out \(ident.name)!", side: ident.side)
            }
        }
        return [.switchIn(ref)]
    }

    private mutating func applyMove(_ line: ProtocolLine) -> [BattleEvent] {
        guard let ref = slotRef(line[0]) else { return [] }
        let move = line[1]
        let target = slotRef(line[2])
        mutate(ref) { mon in
            if line.kwArgs["from"] == nil, !mon.revealedMoves.contains(move) { mon.revealedMoves.append(move) }
        }
        var text = "\(name(ref)) used \(move)!"
        if let from = line.kwArgs["from"], from.hasPrefix("lockedmove") == false, !from.isEmpty {
            text = "\(name(ref)) used \(move)! (\(BattleText.effectName(from)))"
        }
        addLog(.action, text, side: ref.side)
        if line.kwArgs["miss"] != nil, let target {
            addLog(.effect, "\(name(target)) avoided the attack!", side: target.side)
            return [.move(ref, move: move, target: target), .miss(target)]
        }
        if line.kwArgs["notarget"] != nil {
            addLog(.effect, "But there was no target...")
        }
        return [.move(ref, move: move, target: target)]
    }

    private mutating func applyHealthChange(_ line: ProtocolLine) -> [BattleEvent] {
        guard let ref = slotRef(line[0]), let before = pokemon(at: ref) else { return [] }
        let health = HealthStatus(line[1])
        mutate(ref) { $0.apply(health: health) }
        guard let after = pokemon(at: ref) else { return [] }
        let delta = after.hpFraction - before.hpFraction
        let percent = Int((abs(delta) * 100).rounded())
        if line.kind == "-sethp" {
            addLog(.effect, "\(name(ref))'s HP changed.", side: ref.side)
            return []
        }
        if line.kind == "-damage" {
            if let from = line.kwArgs["from"] {
                addLog(.effect, BattleText.damageFrom(name(ref), from: from, of: line.kwArgs["of"].flatMap { slotRef($0) }.map { name($0) }), side: ref.side)
            } else {
                addLog(.minor, "(\(name(ref)) lost \(percent)% of its health!)", side: ref.side)
            }
            return delta < 0 ? [.damage(ref, amount: -delta)] : []
        }
        if let from = line.kwArgs["from"] {
            addLog(.effect, BattleText.healFrom(name(ref), from: from), side: ref.side)
        } else {
            addLog(.effect, "\(name(ref)) had its HP restored.", side: ref.side)
        }
        return delta > 0 ? [.heal(ref, amount: delta)] : []
    }

    // MARK: - Helpers

    static let singleTurnVolatiles: Set<String> = ["Protect", "Detect", "Endure", "King's Shield", "Spiky Shield", "Baneful Bunker", "Silk Trap", "Burning Bulwark", "Obstruct", "Max Guard", "Wide Guard", "Quick Guard", "Roost", "Focus Punch", "Helping Hand", "Follow Me", "Rage Powder", "Magic Coat", "Snatch", "Electrify", "Spotlight", "Instruct", "Beak Blast", "Shell Trap", "Crafty Shield", "Mat Block"]

    static func sameBase(_ a: String, _ b: String) -> Bool {
        a.split(separator: "-").first == b.split(separator: "-").first
    }

    private func sideID(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, trimmed.hasPrefix("p") else { return nil }
        return String(trimmed.prefix(2))
    }

    private mutating func ensureSide(_ id: String) {
        if sides[id] == nil {
            sides[id] = BattleSide(id: id)
            resizeActive(id)
        }
    }

    private mutating func resizeActive(_ id: String) {
        guard var side = sides[id] else { return }
        let count = activesPerSide
        if side.active.count < count {
            side.active += Array(repeating: nil, count: count - side.active.count)
        }
        sides[id] = side
    }

    private func makePokemon(side: String, name: String, details: PokemonDetails) -> BattlePokemon {
        let count = sides[side]?.pokemon.count ?? 0
        return BattlePokemon(
            id: "\(side)|\(count)|\(name)",
            name: name,
            species: details.species,
            level: details.level,
            gender: details.gender,
            shiny: details.shiny,
            hp: 100,
            maxHP: 100,
            status: nil,
            fainted: false,
            teraType: details.teraType
        )
    }

    func slotRef(_ text: String) -> SlotRef? {
        guard let ident = PokemonIdent(text) else { return nil }
        if let slot = ident.slot { return SlotRef(side: ident.side, slot: slot) }
        // Ident without a position: find whichever slot holds that Pokemon.
        guard let side = sides[ident.side] else { return nil }
        for (slot, index) in side.active.enumerated() {
            if let index, index < side.pokemon.count, side.pokemon[index].name == ident.name {
                return SlotRef(side: ident.side, slot: slot)
            }
        }
        return nil
    }

    private func indexOf(ident: PokemonIdent) -> Int? {
        sides[ident.side]?.pokemon.firstIndex { $0.name == ident.name }
    }

    private mutating func mutate(_ ref: SlotRef, _ body: (inout BattlePokemon) -> Void) {
        guard var side = sides[ref.side], ref.slot < side.active.count, let index = side.active[ref.slot], index < side.pokemon.count else { return }
        body(&side.pokemon[index])
        sides[ref.side] = side
    }

    /// "Goodra" for our side, "The opposing Raikou" for theirs.
    public func name(_ ref: SlotRef) -> String {
        let base = pokemon(at: ref)?.name ?? "The Pokémon"
        return ref.side == perspective ? base : "The opposing \(base)"
    }

    private mutating func addLog(_ kind: BattleLogEntry.Kind, _ text: String, side: String? = nil) {
        log.append(BattleLogEntry(id: nextLogID, kind: kind, text: text, side: side, author: nil))
        nextLogID += 1
    }

    private mutating func addChat(user: String, message: String) {
        if message.hasPrefix("/") && !message.hasPrefix("//") { return }
        let author = user.trimmingCharacters(in: .whitespaces)
        log.append(BattleLogEntry(id: nextLogID, kind: .chat, text: message, side: nil, author: author))
        nextLogID += 1
    }
}
