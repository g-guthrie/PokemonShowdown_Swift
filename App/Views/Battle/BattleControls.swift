import SwiftUI
import ShowdownKit

struct BattleControls: View {
    var battle: BattleController
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            if battle.state.ended {
                ResultPanel(battle: battle)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if battle.controlsVisible, let request = battle.request {
                switch request.kind {
                case .teamPreview:
                    TeamPreviewPanel(battle: battle, request: request)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                case .forceSwitch:
                    SwitchPanel(battle: battle, request: request, forced: true)
                        .padding(16)
                        .glassCard(cornerRadius: 28)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                case .move:
                    MovePanel(battle: battle, request: request)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                case .wait:
                    WaitingPanel(battle: battle)
                }
            } else if battle.choiceSent {
                WaitingPanel(battle: battle)
                    .transition(.opacity)
            } else if !battle.isPlayer {
                Text("Spectating")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(12)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: battle.controlsVisible)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: battle.choiceSent)
    }
}

// MARK: - Moves

private struct MovePanel: View {
    var battle: BattleController
    var request: BattleRequest
    @Environment(DexStore.self) private var dex
    @State private var showSwitches = false
    @State private var targeting: (index: Int, move: RequestMove)?
    @State private var showTargets = false

    private var active: ActiveRequest? { battle.currentActive }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                if request.active.count > 1, let mon = battle.currentPokemon {
                    Text("What will \(mon.name) do?")
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                SegmentToggle(left: "Fight", right: "Pokémon", rightSelected: $showSwitches)
            }

            if showSwitches {
                SwitchPanel(battle: battle, request: request, forced: false)
                    .transition(.opacity)
            } else if let active {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(active.moves.enumerated()), id: \.offset) { index, move in
                        MoveButton(
                            move: move,
                            dexMove: dex.data.moves[move.id],
                            effectiveness: battle.effectiveness(of: move.id, dex: dex.data),
                            teraType: battle.terastallize ? active.canTerastallize : nil
                        ) {
                            pick(index: index + 1, move: move)
                        }
                    }
                }
                .transition(.opacity)
            }

            HStack(spacing: 10) {
                if let tera = active?.canTerastallize, !showSwitches {
                    TeraToggle(type: tera, isOn: Binding(get: { battle.terastallize }, set: { battle.terastallize = $0 }))
                }
                Spacer(minLength: 0)
                if battle.pendingChoices.contains(where: { $0 != .pass }) {
                    Button {
                        battle.undoLastPick()
                    } label: {
                        Label("Back", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(PillButtonStyle())
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 28)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showSwitches)
        .confirmationDialog("Choose a target", isPresented: $showTargets, titleVisibility: .visible) {
            if let targeting {
                ForEach(targets(for: targeting.move), id: \.value) { target in
                    Button(target.label) {
                        battle.choose(.move(index: targeting.index, target: target.value, terastallize: battle.terastallize))
                    }
                }
            }
        }
        .onChange(of: battle.currentSlot) { _, _ in showSwitches = false }
    }

    private func pick(index: Int, move: RequestMove) {
        if request.active.count > 1 && move.needsTarget {
            targeting = (index, move)
            showTargets = true
        } else {
            battle.choose(.move(index: index, terastallize: battle.terastallize))
        }
    }

    private struct Target {
        var label: String
        var value: Int
    }

    private func targets(for move: RequestMove) -> [Target] {
        let state = battle.state
        let count = state.activesPerSide
        let mine = battle.currentSlot
        var result: [Target] = []
        let target = move.target ?? "normal"
        if ["normal", "any", "adjacentFoe"].contains(target) {
            for slot in 0..<count {
                if let mon = state.opponentSide?.activePokemon(slot), !mon.fainted {
                    result.append(Target(label: "Foe \(mon.name)", value: slot + 1))
                }
            }
        }
        for slot in 0..<count {
            let isSelf = slot == mine
            let allowed: Bool
            switch target {
            case "normal", "any", "adjacentAlly": allowed = !isSelf
            case "adjacentAllyOrSelf": allowed = true
            default: allowed = false
            }
            if allowed, let mon = state.mySide?.activePokemon(slot), !mon.fainted {
                result.append(Target(label: isSelf ? "\(mon.name) (self)" : "Ally \(mon.name)", value: -(slot + 1)))
            }
        }
        return result
    }
}

private struct MoveButton: View {
    var move: RequestMove
    var dexMove: DexMove?
    var effectiveness: Double?
    var teraType: String?
    var action: () -> Void

    private var type: String {
        if move.id == "terablast", let teraType { return teraType }
        return dexMove?.type ?? "Normal"
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(move.name)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Spacer(minLength: 0)
                    if let effectiveness, effectiveness != 1 {
                        EffectivenessTag(multiplier: effectiveness)
                    }
                }
                HStack(spacing: 6) {
                    CategoryIcon(category: dexMove?.category ?? "Status")
                    Text(type.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                    if let power = dexMove?.basePower, power > 0 {
                        Text("\(power)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Spacer(minLength: 0)
                    if let pp = move.pp, let maxPP = move.maxPP {
                        Text("\(pp)/\(maxPP)")
                            .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(pp == 0 ? Color(hex: 0xFFB3B3) : .white.opacity(0.85))
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.typeGradient(type))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(teraType != nil ? 0.8 : 0.22), lineWidth: teraType != nil ? 1.5 : 1)
                    }
            }
            .shadow(color: Theme.typeColor(type).opacity(0.45), radius: 10, y: 4)
        }
        .buttonStyle(PressableStyle())
        .disabled(move.disabled)
        .saturation(move.disabled ? 0 : 1)
        .opacity(move.disabled ? 0.45 : 1)
    }
}

private struct EffectivenessTag: View {
    var multiplier: Double

    var body: some View {
        let text: String = multiplier == 0 ? "✕" : multiplier >= 4 ? "4×" : multiplier >= 2 ? "2×" : multiplier <= 0.25 ? "¼×" : "½×"
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(multiplier > 1 ? Color(hex: 0x1FD67A) : Color.black.opacity(0.35)))
    }
}

private struct TeraToggle: View {
    var type: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "diamond.fill" : "diamond")
                Text(isOn ? "Terastallizing · \(type)" : "Terastallize")
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                Capsule()
                    .fill(isOn ? AnyShapeStyle(Theme.typeGradient(type)) : AnyShapeStyle(Color.white.opacity(0.1)))
                    .shadow(color: isOn ? Theme.typeColor(type).opacity(0.8) : .clear, radius: 12)
            }
            .overlay(Capsule().strokeBorder(Theme.typeColor(type).opacity(0.7), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .hapticFeedback(.impact(weight: .medium), trigger: isOn)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
    }
}

private struct SegmentToggle: View {
    var left: String
    var right: String
    @Binding var rightSelected: Bool
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            segment(left, selected: !rightSelected) { rightSelected = false }
            segment(right, selected: rightSelected) { rightSelected = true }
        }
        .padding(3)
        .background(Capsule().fill(.black.opacity(0.3)))
    }

    private func segment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { action() }
        } label: {
            Text(title)
                .font(.footnote.weight(.bold))
                .foregroundStyle(selected ? .white : Theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    if selected {
                        Capsule()
                            .fill(Theme.accentGradient)
                            .matchedGeometryEffect(id: "segment", in: namespace)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Switching

private struct SwitchPanel: View {
    var battle: BattleController
    var request: BattleRequest
    var forced: Bool

    private var trapped: Bool {
        !forced && (battle.currentActive?.trapped ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if forced {
                Text("Choose a Pokémon to send in")
                    .font(.subheadline.weight(.bold))
            }
            if trapped {
                Label("You can't switch out right now.", systemImage: "lock.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.gold)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Array(request.side.pokemon.enumerated()), id: \.offset) { index, mon in
                    let disabled = mon.active || mon.health.fainted || trapped || battle.chosenSwitches.contains(index + 1) || mon.reviving
                    Button {
                        battle.choose(.switchTo(index: index + 1))
                    } label: {
                        SwitchCard(mon: mon)
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(disabled)
                    .opacity(disabled ? 0.4 : 1)
                }
            }
        }
    }
}

private struct SwitchCard: View {
    var mon: RequestPokemon

    var body: some View {
        let details = mon.parsedDetails
        let health = mon.health
        HStack(spacing: 8) {
            PokemonArtwork(species: details.species, shiny: details.shiny, size: 38)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(mon.name)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let status = health.status {
                        StatusChip(status: status)
                    }
                }
                HPBar(fraction: health.fraction, height: 5)
                Text(health.fainted ? "Fainted" : "\(health.hp)/\(health.maxHP)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .foregroundStyle(.white)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(mon.active ? 0.14 : 0.07)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Team preview

private struct TeamPreviewPanel: View {
    var battle: BattleController
    var request: BattleRequest
    @State private var order: [Int] = []

    private var needed: Int {
        min(request.maxChosenTeamSize ?? request.side.pokemon.count, request.side.pokemon.count)
    }

    var body: some View {
        VStack(spacing: 12) {
            if let foes = battle.state.opponentSide?.pokemon, !foes.isEmpty {
                HStack(spacing: 2) {
                    Text("Opponent")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 4)
                    ForEach(foes) { mon in
                        PokemonArtwork(species: mon.species, shiny: mon.shiny, size: 34)
                    }
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.isEmpty ? "Choose your lead" : "Pick your order")
                        .font(.headline)
                    Text(needed < request.side.pokemon.count ? "Bring \(needed) — tap in the order you want them" : "Tap Pokémon in the order to send them out")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if !order.isEmpty {
                    Button("Reset") { withAnimation { order = [] } }
                        .buttonStyle(PillButtonStyle())
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(request.side.pokemon.enumerated()), id: \.offset) { index, mon in
                    let position = order.firstIndex(of: index + 1)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            if let position {
                                order.remove(at: position)
                            } else if order.count < needed {
                                order.append(index + 1)
                            }
                        }
                    } label: {
                        VStack(spacing: 2) {
                            PokemonArtwork(species: mon.parsedDetails.species, shiny: mon.parsedDetails.shiny, size: 52)
                            Text(mon.name)
                                .font(.caption2.weight(.bold))
                                .lineLimit(1)
                                .foregroundStyle(.white)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(position != nil ? Theme.accent.opacity(0.35) : .white.opacity(0.07)))
                        .overlay(alignment: .topTrailing) {
                            if let position {
                                Text("\(position + 1)")
                                    .font(.caption.weight(.black))
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(Theme.accentPink))
                                    .padding(4)
                                    .transition(.scale)
                            }
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            Button {
                var final = order
                for index in 1...request.side.pokemon.count where final.count < needed && !final.contains(index) {
                    final.append(index)
                }
                battle.submitTeamOrder(final)
            } label: {
                Text(order.isEmpty ? "Start with default order" : "Lock in")
            }
            .buttonStyle(GlowButtonStyle())
        }
        .padding(16)
        .glassCard(cornerRadius: 28)
    }
}

// MARK: - Waiting & results

private struct WaitingPanel: View {
    var battle: BattleController

    var body: some View {
        HStack(spacing: 12) {
            SearchPulse()
            Text("Waiting for opponent…")
                .font(.subheadline.weight(.semibold))
            Spacer()
            if battle.choiceSent && !(battle.request?.noCancel ?? false) {
                Button("Undo") { battle.undo() }
                    .buttonStyle(PillButtonStyle())
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }
}

private struct ResultPanel: View {
    var battle: BattleController
    @Environment(AppModel.self) private var app
    @Environment(TeamStore.self) private var teams
    @AppStorage("selectedTeamID") private var selectedTeamID = ""
    @State private var appear = false

    var body: some View {
        let won = battle.didWin
        VStack(spacing: 14) {
            Text(won == true ? "Victory!" : won == false ? "Defeat" : (battle.state.winner.map { "\($0) won" } ?? "Tie"))
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(
                    won == true
                        ? AnyShapeStyle(LinearGradient(colors: [Theme.gold, Color(hex: 0xFF8A3D)], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color.white)
                )
                .shadow(color: (won == true ? Theme.gold : Theme.accent).opacity(0.6), radius: 18)
                .scaleEffect(appear ? 1 : 0.6)
                .opacity(appear ? 1 : 0)
            HStack(spacing: 10) {
                Button("Leave") { app.leave(battle) }
                    .buttonStyle(PillButtonStyle())
                if battle.isPlayer, let format = formatForRematch {
                    Button {
                        app.search(format: format, team: teams.team(id: UUID(uuidString: selectedTeamID)))
                        app.leave(battle)
                    } label: {
                        Label("Battle again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(PillButtonStyle(tint: Theme.gold))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 28, tint: won == true ? Theme.gold : nil)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appear = true }
        }
    }

    private var formatForRematch: BattleFormat? {
        let parts = battle.id.split(separator: "-")
        guard parts.count >= 2 else { return nil }
        return app.format(id: String(parts[1]))
    }
}
