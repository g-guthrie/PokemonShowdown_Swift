import SwiftUI
import ShowdownKit

/// A battle tab: the scene (with its message box) on top, and below it either the
/// move/switch controls or, while the turn plays out, the play-by-play log.
struct BattleRoom: View {
    var battle: BattleController
    @Environment(AppModel.self) private var app
    @State private var showLog = false
    @State private var seenChats = 0

    private var chatCount: Int { battle.state.log.filter { $0.kind == .chat }.count }

    private var deciding: Bool {
        battle.controlsVisible && battle.request != nil && !battle.state.ended
    }

    var body: some View {
        VStack(spacing: 0) {
            if let foe = battle.state.opponentSide {
                TrainerStrip(side: foe, team: nil, isFoe: true)
            }
            BattleSceneView(battle: battle)
                .overlay(alignment: .bottom) {
                    BattleMessageBox(battle: battle, unreadChats: max(0, chatCount - seenChats)) {
                        showLog = true
                    }
                    .padding(6)
                }
                .overlay(alignment: .bottom) { Rectangle().fill(PS.border).frame(height: 1) }
            if let mine = battle.state.mySide {
                TrainerStrip(side: mine, team: battle.request?.side.pokemon, isFoe: false)
            }
            Group {
                if deciding {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        BattleControlsPanel(battle: battle)
                    }
                    .transition(.opacity)
                } else {
                    BattleLogView(battle: battle)
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            BattleControlsPanel(battle: battle)
                        }
                        .transition(.opacity)
                }
            }
            .frame(maxHeight: .infinity)
            .animation(.easeOut(duration: 0.2), value: deciding)
        }
        .background(PS.roomOpaque)
        .sheet(isPresented: $showLog) {
            BattleLogSheet(battle: battle)
        }
        .onChange(of: showLog) { _, open in
            if open { seenChats = chatCount }
        }
        .onChange(of: chatCount) { _, count in
            if showLog { seenChats = count }
        }
        .hapticFeedback(.impact(weight: .heavy, intensity: 0.8), trigger: battle.hitCounter)
        .hapticFeedback(.selection, trigger: battle.controlsVisible)
    }
}

/// The current battle text, in the translucent style of Showdown's phone overlay controls.
/// Tapping it opens the full log and chat.
private struct BattleMessageBox: View {
    var battle: BattleController
    var unreadChats: Int
    var openLog: () -> Void

    /// The last two meaningful lines of the current turn.
    private var lines: [BattleLogEntry] {
        let log = battle.state.log
        let start = (log.lastIndex { $0.kind == .turn }).map { $0 + 1 } ?? 0
        let kinds: [BattleLogEntry.Kind] = [.action, .effect, .result, .error]
        let turn = log[start...].filter { kinds.contains($0.kind) }
        if !turn.isEmpty { return Array(turn.suffix(2)) }
        return Array(log.filter { $0.kind != .minor && $0.kind != .chat && $0.kind != .turn }.suffix(1))
    }

    var body: some View {
        Button(action: openLog) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(lines) { entry in
                        Text(entry.kind == .action ? LogLine.boldMove(entry.text) : AttributedString(entry.text))
                            .font(PS.font(entry.kind == .action ? 13 : 12))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeOut(duration: 0.18), value: lines.map(\.id))
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 1) {
                        FAIcon(.comment, size: 15)
                        Text("Chat").font(PS.font(9))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    if unreadChats > 0 {
                        Text("\(unreadChats)")
                            .font(PS.font(9, bold: true))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 15, minHeight: 15)
                            .background(Capsule().fill(Color(hex: 0xCC3311)))
                            .offset(x: 8, y: -6)
                    }
                }
                .padding(.leading, 6)
                .overlay(alignment: .leading) { Rectangle().fill(.white.opacity(0.25)).frame(width: 1) }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.55)))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(lines.isEmpty ? 0 : 1)
    }
}

/// The full log with chat, as a pull-up sheet.
private struct BattleLogSheet: View {
    var battle: BattleController
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""

    var body: some View {
        NavigationStack {
            BattleLogView(battle: battle)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack(spacing: 6) {
                        TextField("Chat", text: $message)
                            .textFieldStyle(PSTextFieldStyle())
                            .submitLabel(.send)
                            .onSubmit(send)
                        Button(action: send) {
                            FAIcon(.paperPlane, size: 14).frame(width: 22, height: 20)
                        }
                        .buttonStyle(PSButtonStyle())
                        .disabled(message.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(8)
                    .background(PS.roomOpaque)
                    .overlay(alignment: .top) { Rectangle().fill(PS.border).frame(height: 1) }
                }
                .navigationTitle(battle.state.title.isEmpty ? "Battle log" : battle.state.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    private func send() {
        battle.sendChat(message)
        message = ""
    }
}

/// Trainer name, avatar and team icons (the scene's `.leftbar`/`.rightbar`, moved above and below it).
private struct TrainerStrip: View {
    var side: BattleSide
    var team: [RequestPokemon]?
    var isFoe: Bool

    var body: some View {
        HStack(spacing: 6) {
            TrainerSprite(avatar: side.avatar, size: 26)
                .scaleEffect(x: isFoe ? 1 : -1, y: 1)
            VStack(alignment: .leading, spacing: 0) {
                Text(side.name)
                    .font(PS.font(11, bold: true))
                    .foregroundStyle(Color(hex: 0x555555))
                    .lineLimit(1)
                if !side.rating.isEmpty {
                    Text("Rating: \(side.rating)")
                        .font(PS.font(9))
                        .foregroundStyle(Color(hex: 0x777777))
                }
            }
            Spacer(minLength: 4)
            HStack(spacing: -7) {
                ForEach(0..<max(side.teamSize, team?.count ?? 0, side.pokemon.count), id: \.self) { index in
                    icon(at: index)
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(Color(hex: 0xDDE3E8))
        .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0xC5CDD4)).frame(height: 1) }
    }

    @ViewBuilder
    private func icon(at index: Int) -> some View {
        if let team, index < team.count {
            let mon = team[index]
            PokemonIcon(species: mon.parsedDetails.species, female: mon.parsedDetails.gender == "F", facingLeft: !isFoe, fainted: mon.health.fainted)
        } else if index < side.pokemon.count {
            let mon = side.pokemon[index]
            PokemonIcon(species: mon.species, female: mon.gender == "F", facingLeft: !isFoe, fainted: mon.fainted)
        } else {
            PokeballIcon()
        }
    }
}

// MARK: - Controls

private struct BattleControlsPanel: View {
    var battle: BattleController
    @Environment(AppModel.self) private var app
    @State private var timerOn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if battle.state.ended {
                afterBattle
            } else if battle.controlsVisible, let request = battle.request {
                switch request.kind {
                case .teamPreview:
                    TeamPreviewControls(battle: battle, request: request)
                case .forceSwitch:
                    whatDo("Switch \(battle.currentPokemon?.name ?? "") to:")
                    PSSectionTitle(text: "Switch")
                    SwitchMenu(battle: battle, request: request, forced: true)
                case .move:
                    MoveControls(battle: battle, request: request, timer: timerButton)
                case .wait:
                    waiting
                }
            } else if battle.choiceSent || battle.request?.kind == .wait {
                waiting
            } else if !battle.isPlayer {
                Text("You are watching this battle.")
                    .font(PS.font(12))
                    .foregroundStyle(PS.subtleText)
            } else {
                Text(battle.state.started ? "The turn is playing out..." : "Waiting for the battle to start...")
                    .font(PS.font(12))
                    .foregroundStyle(PS.subtleText)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PS.roomOpaque.shadow(.drop(color: .black.opacity(0.12), radius: 3, y: -1)))
        .overlay(alignment: .top) { Rectangle().fill(PS.border).frame(height: 1) }
        .animation(.easeOut(duration: 0.2), value: battle.controlsVisible)
    }

    private func whatDo(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(PS.font(12))
                .foregroundStyle(PS.subtleText)
            Spacer()
            timerButton
        }
    }

    private var waiting: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Waiting for opponent...")
                    .font(PS.font(12))
                    .foregroundStyle(PS.subtleText)
                Spacer()
                timerButton
            }
            if battle.choiceSent && !(battle.request?.noCancel ?? false) {
                Button("Cancel") { battle.undo() }
                    .buttonStyle(PSButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var timerButton: some View {
        if battle.isPlayer {
            Button {
                timerOn.toggle()
                battle.toggleTimer(on: timerOn)
            } label: {
                HStack(spacing: 4) {
                    FAIcon(.clock, size: 12)
                    Text(battle.state.timerMessage.map(Self.shortTimer) ?? "Timer")
                }
                .foregroundStyle(timerOn || battle.state.timerMessage != nil ? Color(hex: 0x992222) : PS.text)
            }
            .buttonStyle(PSButtonStyle(size: .small))
        }
    }

    static func shortTimer(_ text: String) -> String {
        let digits = text.split(whereSeparator: { !$0.isNumber }).first
        return digits.map { "\($0) sec" } ?? "Timer"
    }

    private var afterBattle: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Button {
                    battle.saveReplay()
                } label: {
                    HStack(spacing: 4) { FAIcon(.upload, size: 12); Text("Upload and share replay") }
                }
                .buttonStyle(PSButtonStyle(size: .small))
            }
            HStack(spacing: 6) {
                Button {
                    app.leave(battle)
                } label: {
                    Text("Main menu").font(PS.font(13, bold: true))
                }
                .buttonStyle(PSButtonStyle())
                if battle.isPlayer, let format = rematchFormat {
                    Button {
                        let teamID = UserDefaults.standard.string(forKey: "selectedTeamID") ?? ""
                        app.search(format: format, team: app.teams.team(id: UUID(uuidString: teamID)))
                        app.leave(battle)
                    } label: {
                        Text("Find another battle").font(PS.font(13, bold: true))
                    }
                    .buttonStyle(PSButtonStyle())
                }
            }
        }
    }

    private var rematchFormat: BattleFormat? {
        let parts = battle.id.split(separator: "-")
        guard parts.count >= 2 else { return nil }
        return app.format(id: String(parts[1]))
    }
}

/// `h3` section labels in battle controls ("Attack", "Switch").
private struct PSSectionTitle: View {
    var text: String

    var body: some View {
        Text(text)
            .font(PS.font(12, bold: true))
            .foregroundStyle(Color(hex: 0x555555))
            .padding(.top, 2)
    }
}

private struct MoveControls<Timer: View>: View {
    var battle: BattleController
    var request: BattleRequest
    var timer: Timer
    @Environment(DexStore.self) private var dex
    @State private var targeting: (index: Int, move: RequestMove)?

    var body: some View {
        if let targeting {
            targetMenu(targeting)
        } else {
            menu
        }
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("What will \(battle.currentPokemon?.name ?? "") do?")
                    .font(PS.font(12))
                    .foregroundStyle(PS.subtleText)
                Spacer()
                if battle.pendingChoices.contains(where: { $0 != .pass }) {
                    Button("Back") { battle.undoLastPick() }
                        .buttonStyle(PSButtonStyle(size: .small))
                }
                timer
            }
            PSSectionTitle(text: "Attack")
            if let active = battle.currentActive {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                    ForEach(Array(active.moves.enumerated()), id: \.offset) { index, move in
                        MoveButton(move: move, dexMove: dex.data.moves[move.id], teraType: battle.terastallize ? active.canTerastallize : nil) {
                            pick(index + 1, move)
                        }
                    }
                }
                if let tera = active.canTerastallize {
                    Button {
                        battle.terastallize.toggle()
                    } label: {
                        HStack(spacing: 5) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 3).fill(.white)
                                RoundedRectangle(cornerRadius: 3).strokeBorder(Color(hex: 0x767676), lineWidth: 1)
                                if battle.terastallize { FAIcon(.check, size: 11).foregroundStyle(Color(hex: 0x0075FF)) }
                            }
                            .frame(width: 16, height: 16)
                            Text("Terastallize").font(PS.font(13))
                            RemoteImage(path: "sprites/types/Tera\(tera).png", pixelated: false)
                                .frame(width: 18, height: 18)
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(battle.terastallize ? Color(hex: 0xD8E8F8) : .clear))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            PSSectionTitle(text: "Switch")
            SwitchMenu(battle: battle, request: request, forced: false)
        }
        .onChange(of: battle.currentSlot) { _, _ in targeting = nil }
    }

    private func pick(_ index: Int, _ move: RequestMove) {
        if request.active.count > 1 && move.needsTarget {
            targeting = (index, move)
        } else {
            battle.choose(.move(index: index, terastallize: battle.terastallize))
        }
    }

    /// Inline target picker from `renderMoveTargetControls`: foes (right to left), then allies.
    private func targetMenu(_ targeting: (index: Int, move: RequestMove)) -> some View {
        let state = battle.state
        let count = state.activesPerSide
        let target = targeting.move.target ?? "normal"
        let userSlot = battle.currentSlot
        let userCross = count - 1 - userSlot
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("At who? (\(targeting.move.name))")
                    .font(PS.font(12))
                    .foregroundStyle(PS.subtleText)
                Spacer()
                Button("Back") { self.targeting = nil }
                    .buttonStyle(PSButtonStyle(size: .small))
            }
            HStack(spacing: 4) {
                ForEach((0..<count).reversed(), id: \.self) { i in
                    let mon = state.opponentSide?.activePokemon(i)
                    let disabled = target == "adjacentAlly" || target == "adjacentAllyOrSelf"
                        || ((target == "normal" || target == "adjacentFoe") && abs(userCross - i) > 1)
                    targetButton(mon, disabled: disabled || mon == nil || mon?.fainted == true) {
                        battle.choose(.move(index: targeting.index, target: i + 1, terastallize: battle.terastallize))
                        self.targeting = nil
                    }
                }
            }
            HStack(spacing: 4) {
                ForEach(0..<count, id: \.self) { i in
                    let mon = state.mySide?.activePokemon(i)
                    let selfTarget = i == userSlot
                    let disabled = target == "adjacentFoe"
                        || (selfTarget && target != "adjacentAllyOrSelf")
                        || abs(userSlot - i) > 1
                    targetButton(mon, disabled: disabled || mon == nil || mon?.fainted == true) {
                        battle.choose(.move(index: targeting.index, target: -(i + 1), terastallize: battle.terastallize))
                        self.targeting = nil
                    }
                }
            }
        }
    }

    private func targetButton(_ mon: BattlePokemon?, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                if let mon {
                    PokemonIcon(species: mon.species, female: mon.gender == "F")
                    Text(mon.name).font(PS.font(12)).lineLimit(1)
                } else {
                    Text("(empty slot)").font(PS.font(12))
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(SwitchButtonStyle(disabled: disabled))
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
}

/// `.movebutton`: move name centered, type on the left, PP on the right.
private struct MoveButton: View {
    var move: RequestMove
    var dexMove: DexMove?
    var teraType: String?
    var action: () -> Void

    private var type: String {
        if move.id == "terablast", let teraType { return teraType }
        return dexMove?.type ?? "Normal"
    }

    var body: some View {
        let (hue, sat) = PS.typeHS[type] ?? (0, 0)
        Button(action: action) {
            VStack(spacing: 3) {
                Text(move.name)
                    .font(PS.font(13))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                HStack {
                    Text(type)
                    Spacer()
                    Text(move.maxPP.map { "\(move.pp ?? 0)/\($0)" } ?? "\u{2014}")
                }
                .font(PS.font(10))
                .foregroundStyle(move.disabled ? Color(hex: 0x777777) : Color(hue: hue, saturation: sat, lightness: 0.41))
            }
            .foregroundStyle(move.disabled ? Color(hex: 0x707070) : .black)
            .padding(.horizontal, 5)
            .padding(.top, 7)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(MoveButtonStyle(type: type, disabled: move.disabled))
        .disabled(move.disabled)
    }
}

/// `.switchmenu`: party buttons with icon, name, HP line and status dot.
private struct SwitchMenu: View {
    var battle: BattleController
    var request: BattleRequest
    var forced: Bool

    private var trapped: Bool { !forced && (battle.currentActive?.trapped ?? false) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if trapped {
                Text("You are trapped and cannot switch!")
                    .font(PS.italic(12))
                    .foregroundStyle(Color(hex: 0x992222))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                ForEach(Array(request.side.pokemon.enumerated()), id: \.offset) { index, mon in
                    let numActive = request.active.isEmpty ? (request.forceSwitch?.count ?? 1) : request.active.count
                    let disabled = trapped || index < numActive || battle.chosenSwitches.contains(index + 1) || mon.health.fainted
                    Button {
                        battle.choose(.switchTo(index: index + 1))
                    } label: {
                        PartyButtonLabel(mon: mon)
                    }
                    .buttonStyle(SwitchButtonStyle(disabled: disabled))
                    .disabled(disabled)
                }
            }
        }
    }
}

private struct PartyButtonLabel: View {
    var mon: RequestPokemon

    var body: some View {
        let details = mon.parsedDetails
        let health = mon.health
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                PokemonIcon(species: details.species, female: details.gender == "F", fainted: health.fainted)
                    .padding(.leading, -4)
                    .opacity(0.8)
                Text(mon.name)
                    .font(PS.font(12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.black)
            .frame(height: 30)
            if !health.fainted {
                MiniHPBar(fraction: health.fraction)
                    .padding(.leading, 4)
                    .padding(.trailing, health.status != nil ? 10 : 2)
                    .padding(.bottom, 2)
            }
            if let status = health.status {
                RoundedRectangle(cornerRadius: 2)
                    .fill(PS.statusColor(status))
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color(hex: 0xC2C2C2), lineWidth: 1))
                    .frame(width: 7, height: 7)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 2)
                    .padding(.bottom, 1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 34)
    }
}

private struct TeamPreviewControls: View {
    var battle: BattleController
    var request: BattleRequest
    @State private var order: [Int] = []

    private var needed: Int {
        let size = request.side.pokemon.count
        if let max = request.maxChosenTeamSize, max < size { return max }
        return min(battle.state.activesPerSide, size)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(order.isEmpty ? "How will you start the battle?" : "Choose Pokémon \(order.count + 1) of \(needed):")
                .font(PS.font(12))
                .foregroundStyle(PS.subtleText)
            if !order.isEmpty {
                Text("You picked " + order.map { request.side.pokemon[$0 - 1].name }.joined(separator: ", ") + ".")
                    .font(PS.font(12))
            }
            PSSectionTitle(text: "Team")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                ForEach(Array(request.side.pokemon.enumerated()), id: \.offset) { index, mon in
                    let picked = order.contains(index + 1)
                    Button {
                        pick(index + 1)
                    } label: {
                        PartyButtonLabel(mon: mon)
                    }
                    .buttonStyle(SwitchButtonStyle(disabled: picked))
                    .disabled(picked)
                    .opacity(picked ? 0.5 : 1)
                }
            }
            if !order.isEmpty {
                Button("Back") { order.removeLast() }
                    .buttonStyle(PSButtonStyle(size: .small))
            }
        }
    }

    private func pick(_ index: Int) {
        order.append(index)
        guard order.count >= needed else { return }
        var final = order
        for i in 1...request.side.pokemon.count where !final.contains(i) {
            final.append(i)
        }
        if let max = request.maxChosenTeamSize { final = Array(final.prefix(max)) }
        battle.submitTeamOrder(final)
        order = []
    }
}

// MARK: - Log

struct BattleLogView: View {
    var battle: BattleController

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(battle.state.log) { entry in
                        LogLine(entry: entry)
                            .id(entry.id)
                    }
                    Color.clear.frame(height: 4).id("bottom")
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: battle.state.log.count) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) { reader.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: battle.controlsVisible) { _, _ in
                reader.scrollTo("bottom", anchor: .bottom)
            }
        }
        .background(PS.roomOpaque)
    }
}

struct LogLine: View {
    var entry: BattleLogEntry

    var body: some View {
        switch entry.kind {
        case .turn:
            Text(entry.text)
                .font(PS.font(18, bold: true))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: 0xDCE2E7))
                .overlay(alignment: .top) { Rectangle().fill(Color(hex: 0xBBC4CC)).frame(height: 1) }
                .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0xBBC4CC)).frame(height: 1) }
                .padding(.horizontal, -8)
                .padding(.top, 8)
                .padding(.bottom, 6)
        case .action:
            Text(Self.boldMove(entry.text))
                .font(PS.font(13))
                .foregroundStyle(.black)
                .padding(.top, 6)
        case .effect, .minor:
            Text(entry.text)
                .font(PS.font(11))
                .foregroundStyle(.black)
                .padding(.top, 1)
        case .chat:
            (Text((entry.author ?? "") + ": ").font(PS.font(12, bold: true)).foregroundColor(PS.usernameBlue)
                + Text(entry.text).font(PS.font(12)).foregroundColor(.black))
                .padding(.vertical, 3)
        case .system:
            Text(entry.text)
                .font(PS.font(11))
                .foregroundStyle(Color(hex: 0x555555))
                .padding(.top, 2)
        case .error:
            Text(entry.text)
                .font(PS.font(12))
                .foregroundStyle(Color(hex: 0x992222))
                .padding(.top, 2)
        case .result:
            Text(entry.text)
                .font(PS.font(13, bold: true))
                .foregroundStyle(.black)
                .padding(.vertical, 6)
        }
    }

    /// "Goodra used **Thunderbolt**!"
    static func boldMove(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        guard let used = text.range(of: " used "), text.hasSuffix("!") else { return result }
        let moveStart = used.upperBound
        guard let bang = text[moveStart...].firstIndex(of: "!") else { return result }
        let moveText = String(text[moveStart..<bang])
        if let range = result.range(of: moveText) {
            result[range].font = PS.font(13, bold: true)
        }
        return result
    }
}
