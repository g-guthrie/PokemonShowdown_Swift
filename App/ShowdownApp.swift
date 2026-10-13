import SwiftUI
import ShowdownKit

@main
struct ShowdownApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(app.dex)
                .environment(app.teams)
                .preferredColorScheme(.light)
                .task { app.start() }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            PSWallpaper()
            VStack(spacing: 0) {
                TopBar()
                ZStack {
                    switch app.currentRoom {
                    case .home:
                        HomeRoom()
                    case .teambuilder:
                        TeambuilderRoom()
                    case .ladder:
                        LadderRoom()
                    case .battle(let id):
                        if let battle = app.battle(id) {
                            BattleRoom(battle: battle)
                                .id(id)
                        } else {
                            ConnectingRoom()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            PopupHost()
        }
        .sheet(item: Binding(get: { app.sheet }, set: { app.sheet = $0 })) { sheet in
            switch sheet {
            case let .format(selected, mode, onSelect):
                FormatSheet(selected: selected, mode: mode, onSelect: onSelect)
            case let .team(format, selected, onSelect):
                TeamSheet(formatID: format, selected: selected, onSelect: onSelect)
            default:
                EmptyView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            app.scenePhaseChanged(phase)
        }
    }
}

private struct ConnectingRoom: View {
    var body: some View {
        VStack {
            ProgressView()
            Text("Joining battle…").font(PS.font(13)).foregroundStyle(PS.subtleText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PS.roomLight)
    }
}

/// Showdown's header: logo, room tabs, and the user buttons.
struct TopBar: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                RemoteImage(path: "pokemonshowdownbeta.png", pixelated: false)
                    .scaledToFit()
                    .frame(width: 86, height: 38)
                    .padding(.leading, 4)
                    .padding(.bottom, 3)
                ScrollViewReader { reader in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .bottom, spacing: -1) {
                            ForEach(app.openRooms, id: \.self) { room in
                                RoomTab(room: room)
                                    .id(room)
                            }
                        }
                        .padding(.leading, 6)
                    }
                    .onChange(of: app.currentRoom) { _, room in
                        withAnimation { reader.scrollTo(room, anchor: .center) }
                    }
                }
                userButtons
                    .padding(.trailing, 6)
                    .padding(.bottom, 8)
            }
            .frame(height: 46)
            .background {
                ZStack {
                    LinearGradient(colors: [Color(hex: 0xF4F6F8), Color(hex: 0xDCE1E6)], startPoint: .top, endPoint: .bottom)
                    RemoteImage(path: "fx/client-topbar-bg.png", pixelated: false)
                }
                .ignoresSafeArea(edges: .top)
            }
            // `.maintabbarbottom`
            Rectangle()
                .fill(Color(hex: 0xF8F8F8))
                .frame(height: 6)
                .overlay(alignment: .top) { Rectangle().fill(PS.border).frame(height: 1) }
                .overlay(alignment: .bottom) { Rectangle().fill(PS.border).frame(height: 1) }
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
        }
    }

    private var userButtons: some View {
        HStack(spacing: 4) {
            Button {
                app.popup = .login
            } label: {
                if app.isNamed {
                    HStack(spacing: 4) {
                        FAIcon(.user, size: 12).foregroundStyle(Color(hex: 0x777777))
                        Text(app.username)
                            .font(PS.font(12, bold: true))
                            .lineLimit(1)
                    }
                } else {
                    Text(app.connectionState == .connected ? "Choose name" : "Connecting…")
                        .font(PS.font(12))
                }
            }
            .buttonStyle(PSButtonStyle(size: .small))
            Button {
                app.popup = .options
            } label: {
                FAIcon(.cog, size: 15)
                    .frame(width: 18, height: 17)
            }
            .buttonStyle(PSButtonStyle(size: .small))
        }
        .frame(maxWidth: 150, alignment: .trailing)
    }
}

/// One tab in the header tab bar (`.tabbar a.button`).
private struct RoomTab: View {
    var room: Room
    @Environment(AppModel.self) private var app

    private var selected: Bool { app.currentRoom == room }

    var body: some View {
        Group {
            VStack(spacing: 1) {
                icon
                Text(title)
                    .font(PS.font(10))
                    .lineLimit(1)
                    .frame(maxWidth: 92)
            }
            .foregroundStyle(selected ? Color(hex: 0x444444) : PS.text)
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, selected ? 6 : 4)
            .frame(minWidth: 58)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5)
                    .fill(selected
                          ? AnyShapeStyle(Color(hex: 0xF8F8F8))
                          : AnyShapeStyle(LinearGradient(colors: [Color(hex: notifying ? 0xF6D6B6 : 0xF6F6F6), Color(hex: notifying ? 0xD3B396 : 0xE3E3E3)], startPoint: .top, endPoint: .bottom)))
            )
            .overlay(
                UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5)
                    .strokeBorder(PS.border, lineWidth: 1)
                    .mask(alignment: .top) { Rectangle().padding(.bottom, selected ? 1 : 0) }
            )
            .overlay(alignment: .topTrailing) {
                if room != .home {
                    Button {
                        close()
                    } label: {
                        FAIcon(.timesCircle, size: 13)
                            .foregroundStyle(Color(hex: 0x999999))
                            .padding(3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .offset(y: selected ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { app.currentRoom = room }
    }

    private var notifying: Bool {
        if case .battle(let id) = room, !selected, let battle = app.battle(id) {
            return battle.controlsVisible
        }
        return false
    }

    @ViewBuilder
    private var icon: some View {
        switch room {
        case .home:
            FAIcon(.home, size: 14)
        case .teambuilder:
            FAIcon(.pencilSquare, size: 14)
        case .ladder:
            FAIcon(.barChart, size: 14)
        case .battle(let id):
            if let battle = app.battle(id), let mine = battle.state.mySide?.activePokemon(0) ?? battle.state.mySide?.pokemon.first {
                PokemonIcon(species: mine.species, scale: 0.6)
                    .frame(height: 14)
            } else {
                FAIcon(.comment, size: 14)
            }
        }
    }

    private var title: String {
        switch room {
        case .home: return "Home"
        case .teambuilder: return "Teambuilder"
        case .ladder: return "Ladder"
        case .battle(let id):
            guard let battle = app.battle(id) else { return "Battle" }
            if let p1 = battle.state.sides["p1"]?.name, let p2 = battle.state.sides["p2"]?.name, !p1.isEmpty, !p2.isEmpty {
                return battle.isPlayer ? (battle.state.opponentSide?.name ?? p2) : "\(p1) vs. \(p2)"
            }
            return battle.formatName
        }
    }

    private func close() {
        if case .battle(let id) = room, let battle = app.battle(id) {
            if battle.isPlayer && !battle.state.ended && battle.state.started {
                app.popup = .confirm(message: "Forfeit and close this battle?", button: "Forfeit and close") {
                    battle.forfeit()
                    app.leave(battle)
                }
            } else {
                app.leave(battle)
            }
        } else {
            app.closeRoom(room)
        }
    }
}
