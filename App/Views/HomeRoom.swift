import SwiftUI
import ShowdownKit

/// The main menu (`panel-mainmenu.tsx`), laid out the way Showdown's tiny layout stacks it.
struct HomeRoom: View {
    @Environment(AppModel.self) private var app
    @Environment(TeamStore.self) private var teams
    @AppStorage("selectedFormat") private var formatID = "gen9randombattle"
    @AppStorage("selectedTeamID") private var teamID = ""
    @AppStorage("background") private var backgroundID = "charizards"

    private var background: PSBackground { .named(backgroundID) }
    private var format: BattleFormat? { app.format(id: formatID) }
    private var team: Team? { teams.team(id: UUID(uuidString: teamID)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if !app.battles.isEmpty || !app.incomingChallenges.isEmpty || app.outgoingChallenge != nil {
                    gamesGroup
                }
                searchGroup
                MenuGroup {
                    menuButton("Teambuilder", hue: 2) { app.open(.teambuilder) }
                    menuButton("Ladder", hue: 3, online: true) { app.open(.ladder) }
                }
                MenuGroup {
                    menuButton("Watch a battle", hue: 4, online: true) { app.popup = .watchBattles }
                    menuButton("Find a user", hue: 5, online: true) { app.popup = .findUser }
                }
                Text(background.credit)
                    .font(PS.font(11))
                    .foregroundStyle(Color(hex: 0xBBBBBB))
                    .shadow(color: .black, radius: 2)
                    .padding(.bottom, 24)
            }
            .padding(.top, 26)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Battle form

    private var searchGroup: some View {
        MenuGroup {
            VStack(alignment: .leading, spacing: 4) {
                PSLabel(text: "Format:", onDark: true)
                FormatSelect(formatID: $formatID, mode: .ladder)
            }
            if format?.requiresTeam ?? false {
                VStack(alignment: .leading, spacing: 4) {
                    PSLabel(text: "Team:", onDark: true)
                    TeamSelect(formatID: formatID, teamID: $teamID)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    PSLabel(text: "Team:", onDark: true)
                    RandomTeamSelect()
                }
            }
            searchButton
                .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var searchButton: some View {
        let (hue, sat) = background.hueSat(1)
        if app.connectionState != .connected {
            Button {} label: {
                Text(app.connectionState == .connecting ? "Connecting..." : "Disconnected")
                    .font(PS.italic(19))
            }
            .buttonStyle(MenuButtonStyle(hue: hue, saturation: sat, big: true))
            .disabled(true)
            if app.connectionState == .disconnected {
                Button {
                    app.reconnect()
                } label: {
                    Text("Reconnect").font(PS.font(13, bold: true))
                }
                .buttonStyle(PSButtonStyle())
            }
        } else if !app.searching.isEmpty {
            Button {} label: {
                HStack(spacing: 8) {
                    SpinningIcon()
                    Text("Searching...").font(PS.font(19, bold: true))
                }
            }
            .buttonStyle(MenuButtonStyle(hue: hue, saturation: sat, big: true))
            .disabled(true)
            Button("Cancel") { app.cancelSearch() }
                .buttonStyle(PSButtonStyle())
        } else {
            Button {
                guard let format else {
                    app.sheet = .format(selected: formatID, mode: .ladder) { formatID = $0 }
                    return
                }
                app.search(format: format, team: team)
            } label: {
                VStack(spacing: 1) {
                    Text("Battle!").font(PS.font(19, bold: true))
                    Text("Find a random opponent").font(PS.font(12))
                }
            }
            .buttonStyle(MenuButtonStyle(hue: hue, saturation: sat, big: true))
            .hapticFeedback(.impact(weight: .medium), trigger: app.searching)
        }
    }

    // MARK: Games & challenges

    private var gamesGroup: some View {
        MenuGroup {
            ForEach(app.incomingChallenges) { challenge in
                ChallengeBox(challenge: challenge)
            }
            if let outgoing = app.outgoingChallenge {
                VStack(spacing: 6) {
                    Text("Challenging \(outgoing.user)...")
                        .font(PS.font(13, bold: true))
                    Text(app.format(id: outgoing.format)?.name ?? outgoing.format)
                        .font(PS.font(12))
                    Button("Cancel") { app.cancelChallenge() }
                        .buttonStyle(PSButtonStyle())
                }
            }
            if !app.battles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    PSLabel(text: "Games:", onDark: true)
                    ForEach(app.battles) { battle in
                        Button {
                            app.open(.battle(battle.id))
                        } label: {
                            HStack(spacing: 4) {
                                if let mine = battle.state.mySide?.pokemon.first {
                                    PokemonIcon(species: mine.species)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(battle.state.title.isEmpty ? battle.formatName : battle.state.title)
                                        .font(PS.font(12, bold: true))
                                        .lineLimit(1)
                                    Text(battle.state.ended ? "Ended" : battle.controlsVisible ? "Your move!" : "Turn \(battle.state.turn)")
                                        .font(PS.font(11))
                                        .foregroundStyle(battle.controlsVisible ? Color(hex: 0xAA6600) : PS.subtleText)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PSButtonStyle())
                    }
                }
            }
        }
    }

    private func menuButton(_ title: String, hue index: Int, online: Bool = false, action: @escaping () -> Void) -> some View {
        let (hue, sat) = background.hueSat(index)
        return Button(action: action) {
            Text(title)
        }
        .buttonStyle(MenuButtonStyle(hue: hue, saturation: sat))
        .disabled(online && app.connectionState != .connected)
    }
}

/// Incoming challenge, with its own team select when the format needs one.
private struct ChallengeBox: View {
    var challenge: Challenge
    @Environment(AppModel.self) private var app
    @Environment(TeamStore.self) private var teams
    @State private var teamID = ""

    private var needsTeam: Bool { app.format(id: challenge.format)?.requiresTeam ?? !challenge.format.contains("random") }

    var body: some View {
        VStack(spacing: 6) {
            Text("Challenge from \(challenge.user)")
                .font(PS.font(13, bold: true))
            Text(app.format(id: challenge.format)?.name ?? challenge.format)
                .font(PS.font(12))
            if needsTeam {
                TeamSelect(formatID: challenge.format, teamID: $teamID)
            }
            HStack(spacing: 6) {
                Button {
                    app.accept(challenge, team: teams.team(id: UUID(uuidString: teamID)))
                } label: {
                    Text("Accept").font(PS.font(13, bold: true))
                }
                .buttonStyle(PSButtonStyle())
                Button("Reject") { app.reject(challenge) }
                    .buttonStyle(PSButtonStyle())
            }
        }
    }
}

/// Format dropdown.
struct FormatSelect: View {
    @Binding var formatID: String
    var mode: FormatMode
    @Environment(AppModel.self) private var app

    var body: some View {
        PSSelect(action: {
            app.sheet = .format(selected: formatID, mode: mode) { formatID = $0 }
        }) {
            Text(app.format(id: formatID).map(Self.displayName) ?? (app.formatSections.isEmpty ? "Loading..." : formatID))
                .lineLimit(1)
        }
    }

    /// Showdown hides the generation tag for current-gen formats.
    static func displayName(_ format: BattleFormat) -> String {
        format.genLabel == "Gen 9" ? format.shortName : format.name
    }
}

/// Team dropdown (`.teamselect`): team name over its icons.
struct TeamSelect: View {
    var formatID: String
    @Binding var teamID: String
    @Environment(AppModel.self) private var app
    @Environment(TeamStore.self) private var teams

    private var team: Team? { teams.team(id: UUID(uuidString: teamID)) }

    var body: some View {
        PSSelect(action: {
            app.sheet = .team(format: formatID, selected: teamID) { teamID = $0 }
        }) {
            VStack(spacing: 0) {
                if let team {
                    Text(team.name)
                        .font(PS.font(11, bold: true))
                        .lineLimit(1)
                    HStack(spacing: -6) {
                        ForEach(team.pokemon.prefix(6)) { set in
                            PokemonIcon(species: set.species, female: set.gender == "F")
                        }
                    }
                } else {
                    Text(teams.teams.isEmpty ? "You have no teams" : "Choose a team")
                        .font(PS.font(11, bold: true))
                        .frame(height: 30)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            if team == nil, let first = teams.teams.first(where: { $0.format == formatID }) {
                teamID = first.id.uuidString
            }
        }
    }
}

/// The disabled team box shown for random formats.
struct RandomTeamSelect: View {
    var body: some View {
        PSSelect(action: {}, disabled: true) {
            VStack(spacing: 0) {
                Text("Random team")
                    .font(PS.font(11, bold: true))
                    .foregroundStyle(Color(hex: 0x777777))
                HStack(spacing: -6) {
                    ForEach(0..<6, id: \.self) { _ in PokeballIcon() }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// `fa-refresh fa-spin`
struct SpinningIcon: View {
    @State private var spinning = false

    var body: some View {
        FAIcon(.refresh, size: 17)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
    }
}
