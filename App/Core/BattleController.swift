import Foundation
import Observation
import SwiftUI
import ShowdownKit

struct FloatingText: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var color: Color
}

/// Per-slot animation triggers. Views key their keyframe animations off these counters.
struct SlotEffects: Equatable {
    var lunge = 0
    var hit = 0
    var heal = 0
    var tera = 0
    var floating: [FloatingText] = []
}

struct AbilityBanner: Equatable {
    var ref: SlotRef
    var pokemon: String
    var ability: String
}

/// Owns one battle room: plays the server's log back with pacing, and builds choices.
@Observable
@MainActor
final class BattleController: Identifiable {
    let id: String
    var state: BattleState
    var request: BattleRequest?
    var controlsVisible = false
    var choiceSent = false
    var pendingChoices: [BattleChoice] = []
    var terastallize = false
    var lastError: String?
    var currentMessage = ""
    var effects: [SlotRef: SlotEffects] = [:]
    var abilityBanner: AbilityBanner?
    var hitCounter = 0
    var superEffectiveCounter = 0
    var myUserID: String

    @ObservationIgnored private weak var app: AppModel?
    @ObservationIgnored private var queue: [String] = []
    @ObservationIgnored private var draining = false
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    init(roomID: String, app: AppModel) {
        id = roomID
        self.app = app
        myUserID = app.userID
        state = BattleState(roomID: roomID)
    }

    var formatName: String {
        if !state.tier.isEmpty { return state.tier }
        return id.split(separator: "-").dropFirst().first.map(String.init) ?? "Battle"
    }

    var isPlayer: Bool { request != nil || state.sides.values.contains { toID($0.name) == myUserID } }

    var didWin: Bool? {
        guard state.ended else { return nil }
        guard let winner = state.winner else { return nil }
        return toID(winner) == myUserID
    }

    func reset() {
        queue = []
        state = BattleState(roomID: id)
        request = nil
        controlsVisible = false
        choiceSent = false
        pendingChoices = []
        effects = [:]
        currentMessage = ""
    }

    // MARK: - Receiving

    func receive(_ lines: [String], instant: Bool) {
        for line in lines {
            if line.hasPrefix("|request|") {
                handleRequest(String(line.dropFirst("|request|".count)))
                continue
            }
            if line.hasPrefix("|error|") {
                let message = String(line.dropFirst("|error|".count))
                lastError = message
                if message.hasPrefix("[Invalid choice]") || message.hasPrefix("[Unavailable choice]") {
                    choiceSent = false
                    pendingChoices = []
                    scheduleRefresh()
                }
                continue
            }
            if instant {
                applyLine(line)
            } else {
                queue.append(line)
            }
        }
        if instant {
            currentMessage = state.log.last { $0.kind != .minor && $0.kind != .chat }?.text ?? ""
        }
        drain()
        scheduleRefresh()
    }

    private func handleRequest(_ json: String) {
        guard let parsed = BattleRequest.parse(json) else { return }
        if state.perspective != parsed.side.id { state.perspective = parsed.side.id }
        request = parsed
        choiceSent = false
        pendingChoices = []
        terastallize = false
        lastError = nil
        autoFillPasses()
        scheduleRefresh()
    }

    @discardableResult
    private func applyLine(_ line: String) -> [BattleEvent] {
        if line.hasPrefix("|player|") {
            let parsed = ProtocolLine(line)
            if !myUserID.isEmpty, toID(parsed[1]) == myUserID, request == nil {
                state.perspective = parsed[0]
            }
        }
        return state.apply(line)
    }

    private func drain() {
        guard !draining, !queue.isEmpty else { return }
        draining = true
        controlsVisible = false
        Task { @MainActor [weak self] in
            while let self, !self.queue.isEmpty {
                let line = self.queue.removeFirst()
                let pause = self.step(line)
                if pause > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(pause / self.speed * 1_000_000_000))
                }
            }
            self?.draining = false
            self?.scheduleRefresh()
        }
    }

    private var speed: Double {
        let value = UserDefaults.standard.double(forKey: "animationSpeed")
        return value <= 0 ? 1 : value
    }

    /// Applies one line with animation and returns how long to linger on it.
    private func step(_ line: String) -> Double {
        let logCount = state.log.count
        let events = withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            applyLine(line)
        }
        if state.log.count > logCount, let entry = state.log.last, entry.kind != .minor, entry.kind != .chat {
            withAnimation(.easeOut(duration: 0.2)) { currentMessage = entry.text }
        }
        var pause = 0.0
        for event in events {
            pause = max(pause, react(to: event))
        }
        if pause == 0, state.log.count > logCount, let entry = state.log.last {
            switch entry.kind {
            case .action, .effect: pause = 0.5
            case .turn: pause = 0.35
            default: pause = 0.05
            }
        }
        return pause
    }

    private func react(to event: BattleEvent) -> Double {
        switch event {
        case let .move(ref, _, _):
            effects[ref, default: SlotEffects()].lunge += 1
            return 0.7
        case let .damage(ref, amount):
            effects[ref, default: SlotEffects()].hit += 1
            hitCounter += 1
            float(ref, "\u{2212}\(max(1, Int((amount * 100).rounded())))%", color: Color(hex: 0xCC0000))
            return 0.75
        case let .heal(ref, amount):
            effects[ref, default: SlotEffects()].heal += 1
            float(ref, "+\(max(1, Int((amount * 100).rounded())))%", color: Color(hex: 0x00CC00))
            return 0.55
        case .faint:
            return 0.9
        case .switchIn:
            return 0.75
        case let .status(ref, status):
            float(ref, status.uppercased(), color: PS.statusColor(status))
            return 0.6
        case let .boost(ref, stat, amount):
            let label = StatSpread.labels[stat] ?? BattleText.statNames[stat] ?? stat
            float(ref, "\(amount > 0 ? "+" : "")\(amount) \(label)", color: amount > 0 ? Color(hex: 0x00CC00) : Color(hex: 0xCC0000))
            return 0.5
        case .crit:
            hitCounter += 1
            return 0.5
        case let .effectiveness(_, kind):
            if kind == .superEffective { superEffectiveCounter += 1 }
            return 0.55
        case .miss:
            return 0.5
        case let .ability(ref, ability):
            let name = state.pokemon(at: ref)?.name ?? ""
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                abilityBanner = AbilityBanner(ref: ref, pokemon: name, ability: ability)
            }
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                withAnimation(.easeOut(duration: 0.3)) {
                    if self?.abilityBanner?.ability == ability { self?.abilityBanner = nil }
                }
            }
            return 0.8
        case let .terastallize(ref, _):
            effects[ref, default: SlotEffects()].tera += 1
            return 1.1
        case .turn:
            return 0.3
        case .weather:
            return 0.6
        case .end:
            return 0
        }
    }

    private func float(_ ref: SlotRef, _ text: String, color: Color) {
        let item = FloatingText(text: text, color: color)
        effects[ref, default: SlotEffects()].floating.append(item)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            self?.effects[ref]?.floating.removeAll { $0.id == item.id }
        }
    }

    /// Requests arrive just before the log that leads up to them, so wait for playback to settle.
    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled, let self else { return }
            let ready = !self.draining && self.queue.isEmpty && self.request != nil && !self.choiceSent
                && self.request?.kind != .wait && !self.state.ended
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                self.controlsVisible = ready
            }
        }
    }

    // MARK: - Choosing

    /// Index of the active slot the player is currently deciding for.
    var currentSlot: Int { pendingChoices.count }

    var slotsToDecide: Int {
        guard let request else { return 0 }
        switch request.kind {
        case .move: return request.active.count
        case .forceSwitch: return request.forceSwitch?.count ?? 1
        default: return 0
        }
    }

    var currentActive: ActiveRequest? {
        guard let request, currentSlot < request.active.count else { return nil }
        return request.active[currentSlot]
    }

    var currentPokemon: RequestPokemon? {
        guard let request, currentSlot < request.side.pokemon.count else { return nil }
        return request.side.pokemon[currentSlot]
    }

    var currentMustSwitch: Bool {
        request?.kind == .forceSwitch
    }

    /// Bench Pokemon already picked to switch in during this decision.
    var chosenSwitches: Set<Int> {
        Set(pendingChoices.compactMap { if case let .switchTo(index) = $0 { return index } else { return nil } })
    }

    func choose(_ choice: BattleChoice) {
        guard request != nil, !choiceSent else { return }
        pendingChoices.append(choice)
        terastallize = false
        autoFillPasses()
    }

    func undoLastPick() {
        guard !pendingChoices.isEmpty, !choiceSent else { return }
        pendingChoices.removeLast()
        while let last = pendingChoices.last, last == .pass {
            pendingChoices.removeLast()
        }
        autoFillPasses()
    }

    /// Skips slots that need no decision (fainted, commanding, or not forced to switch).
    private func autoFillPasses() {
        guard let request else { return }
        while currentSlot < slotsToDecide {
            let slot = currentSlot
            let mon = slot < request.side.pokemon.count ? request.side.pokemon[slot] : nil
            var skip = false
            if request.kind == .forceSwitch {
                skip = !(request.forceSwitch?[slot] ?? false)
                let bench = request.side.pokemon.enumerated().filter { $0.offset >= request.forceSwitch!.count && !$0.element.health.fainted && !chosenSwitches.contains($0.offset + 1) }
                if bench.isEmpty { skip = true }
            } else if let mon, mon.health.fainted || mon.commanding {
                skip = true
            }
            guard skip else { break }
            pendingChoices.append(.pass)
        }
        if currentSlot >= slotsToDecide, slotsToDecide > 0 {
            submit()
        }
    }

    private func submit() {
        guard let request, !choiceSent else { return }
        let text = BattleChoice.join(pendingChoices)
        send("/choose \(text)|\(request.rqid.map(String.init) ?? "")")
        choiceSent = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { controlsVisible = false }
    }

    func submitTeamOrder(_ order: [Int]) {
        guard let request, !choiceSent else { return }
        send("/choose team \(order.map(String.init).joined())|\(request.rqid.map(String.init) ?? "")")
        choiceSent = true
        withAnimation { controlsVisible = false }
    }

    func undo() {
        send("/undo")
        choiceSent = false
        pendingChoices = []
        autoFillPasses()
        scheduleRefresh()
    }

    func forfeit() { send("/forfeit") }

    func toggleTimer(on: Bool) { send("/timer \(on ? "on" : "off")") }

    func sendChat(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        send(trimmed)
    }

    func saveReplay() { send("/savereplay") }

    private func send(_ text: String) {
        app?.send("\(id)|\(text)")
    }

    // MARK: - Helpers for views

    /// The foe's current types, accounting for Terastallization.
    func types(of mon: BattlePokemon, dex: DexData) -> [String] {
        if let tera = mon.terastallized, tera != "Stellar" { return [tera] }
        return dex.species(named: mon.species)?.types ?? []
    }

    func effectiveness(of moveID: String, dex: DexData) -> Double? {
        guard state.activesPerSide == 1, let move = dex.moves[moveID], move.category != "Status",
              let foe = state.opponentSide?.activePokemon(0) else { return nil }
        let types = types(of: foe, dex: dex)
        guard !types.isEmpty else { return nil }
        return TypeChart.multiplier(attack: move.type, defenders: types)
    }
}
