import SwiftUI
import ShowdownKit

struct PlayView: View {
    @Environment(AppModel.self) private var app
    @Environment(TeamStore.self) private var teams
    @AppStorage("selectedFormat") private var selectedFormatID = "gen9randombattle"
    @AppStorage("selectedTeamID") private var selectedTeamID = ""
    @State private var showFormats = false
    @State private var showLogin = false
    @State private var showChallenge = false
    @State private var acceptingChallenge: Challenge?

    private var format: BattleFormat? { app.format(id: selectedFormatID) }

    private var selectedTeam: Team? {
        teams.team(id: UUID(uuidString: selectedTeamID))
    }

    private var isSearching: Bool { app.searching.contains(selectedFormatID) || !app.searching.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        header
                        if app.connectionState != .connected {
                            connectionBanner
                        }
                        heroCard
                        if !app.incomingChallenges.isEmpty || app.outgoingChallenge != nil {
                            challengesSection
                        }
                        if !app.battles.isEmpty {
                            battlesSection
                        }
                        Button {
                            showChallenge = true
                        } label: {
                            Label("Challenge a player", systemImage: "person.2.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PillButtonStyle())
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showFormats) {
                FormatPickerSheet(selection: $selectedFormatID, mode: .ladder)
            }
            .sheet(isPresented: $showLogin) {
                LoginSheet()
            }
            .sheet(isPresented: $showChallenge) {
                ChallengeSheet(initialFormat: selectedFormatID)
            }
            .sheet(item: $acceptingChallenge) { challenge in
                AcceptChallengeSheet(challenge: challenge)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SHOWDOWN")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(Theme.accentGradient)
                Text(app.isNamed ? "Ready, \(app.username)?" : "Let's battle")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
            Button {
                showLogin = true
            } label: {
                HStack(spacing: 8) {
                    TrainerAvatar(avatar: app.avatar, name: app.username.isEmpty ? "?" : app.username, size: 34)
                    Circle()
                        .fill(app.connectionState == .connected ? Color.green : app.connectionState == .connecting ? Color.yellow : Color.red)
                        .frame(width: 8, height: 8)
                }
                .padding(5)
                .padding(.trailing, 6)
                .glassCard(cornerRadius: 30)
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.top, 12)
    }

    private var connectionBanner: some View {
        HStack(spacing: 12) {
            if app.connectionState == .connecting {
                ProgressView().tint(.white)
                Text("Connecting to Showdown…")
                    .font(.subheadline.weight(.semibold))
            } else {
                Image(systemName: "wifi.exclamationmark")
                Text("Disconnected")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Retry") { app.reconnect() }
                    .buttonStyle(PillButtonStyle(tint: Theme.gold))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard(cornerRadius: 18, tint: app.connectionState == .connecting ? nil : .red)
    }

    // MARK: Hero

    private var heroCard: some View {
        VStack(spacing: 16) {
            Button {
                showFormats = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.accentGradient)
                        Image(systemName: format?.isRandom ?? true ? "shuffle" : "trophy.fill")
                            .font(.title3.weight(.bold))
                    }
                    .frame(width: 50, height: 50)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(format?.genLabel?.uppercased() ?? "FORMAT")
                            .font(.caption2.weight(.heavy))
                            .tracking(1.5)
                            .foregroundStyle(Theme.textSecondary)
                        Text(format?.shortName ?? (app.formatSections.isEmpty ? "Loading formats…" : "Choose a format"))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .buttonStyle(PressableStyle())

            if format?.requiresTeam == true {
                Divider().overlay(.white.opacity(0.1))
                TeamMenu(formatID: selectedFormatID, selectedTeamID: $selectedTeamID)
            }

            searchButton
        }
        .padding(18)
        .glassCard(cornerRadius: 28)
    }

    @ViewBuilder
    private var searchButton: some View {
        if isSearching {
            Button {
                app.cancelSearch()
            } label: {
                HStack(spacing: 12) {
                    SearchPulse()
                    Text("Searching for an opponent…")
                    Spacer(minLength: 0)
                    Text("Cancel")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 22)
            }
            .buttonStyle(GlowButtonStyle(gradient: LinearGradient(colors: [Color(hex: 0x2B2F55), Color(hex: 0x3A2E6B)], startPoint: .leading, endPoint: .trailing), glow: Theme.accent))
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else {
            Button {
                guard let format else {
                    showFormats = true
                    return
                }
                app.search(format: format, team: selectedTeam)
            } label: {
                Label("Battle!", systemImage: "bolt.fill")
            }
            .buttonStyle(GlowButtonStyle())
            .disabled(app.connectionState != .connected)
            .opacity(app.connectionState == .connected ? 1 : 0.5)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .hapticFeedback(.impact(weight: .medium), trigger: app.searching)
        }
    }

    // MARK: Challenges

    private var challengesSection: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Challenges", symbol: "flag.2.crossed.fill")
            ForEach(app.incomingChallenges) { challenge in
                HStack(spacing: 12) {
                    TrainerAvatar(avatar: "", name: challenge.user, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(challenge.user).font(.headline)
                        Text(app.format(id: challenge.format)?.name ?? challenge.format)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Button {
                        app.reject(challenge)
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(PillButtonStyle(tint: .white))
                    Button {
                        let needsTeam = app.format(id: challenge.format)?.requiresTeam ?? false
                        if needsTeam {
                            acceptingChallenge = challenge
                        } else {
                            app.accept(challenge, team: nil)
                        }
                    } label: {
                        Text("Accept")
                    }
                    .buttonStyle(PillButtonStyle(tint: Color(hex: 0x5BE38A)))
                }
                .padding(14)
                .glassCard(cornerRadius: 20, tint: Theme.accent)
            }
            if let outgoing = app.outgoingChallenge {
                HStack(spacing: 12) {
                    ProgressView().tint(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Waiting for \(outgoing.user)")
                            .font(.headline)
                        Text(app.format(id: outgoing.format)?.name ?? outgoing.format)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Button("Cancel") { app.cancelChallenge() }
                        .buttonStyle(PillButtonStyle())
                }
                .padding(14)
                .glassCard(cornerRadius: 20)
            }
        }
    }

    // MARK: Battles

    private var battlesSection: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Your battles", symbol: "flame.fill")
            ForEach(app.battles) { battle in
                Button {
                    app.presentedBattle = battle
                } label: {
                    BattleRow(battle: battle)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

private struct BattleRow: View {
    var battle: BattleController

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: -14) {
                if let mine = battle.state.mySide?.activePokemon(0) {
                    PokemonArtwork(species: mine.species, shiny: mine.shiny, size: 44)
                }
                if let theirs = battle.state.opponentSide?.activePokemon(0) {
                    PokemonArtwork(species: theirs.species, shiny: theirs.shiny, size: 44)
                }
            }
            .frame(minWidth: 60)
            VStack(alignment: .leading, spacing: 3) {
                Text(battle.state.opponentSide.map { "vs. \($0.name)" } ?? battle.state.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(battle.formatName)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if let won = battle.didWin {
                Text(won ? "WON" : "LOST")
                    .font(.caption.weight(.black))
                    .foregroundStyle(won ? Color(hex: 0x5BE38A) : Color(hex: 0xFF6B6B))
            } else if battle.controlsVisible {
                Text("YOUR MOVE")
                    .font(.caption2.weight(.black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.accentPink))
            } else {
                Text("Turn \(battle.state.turn)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(14)
        .glassCard(cornerRadius: 20)
    }
}

/// Concentric rings that pulse while matchmaking.
struct SearchPulse: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(.white.opacity(0.7), lineWidth: 1.5)
                    .scaleEffect(animate ? 1.6 : 0.4)
                    .opacity(animate ? 0 : 0.9)
                    .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false).delay(Double(index) * 0.5), value: animate)
            }
            Circle().fill(.white).frame(width: 6, height: 6)
        }
        .frame(width: 22, height: 22)
        .onAppear { animate = true }
    }
}

/// Picks one of the player's teams, preferring ones built for the format.
struct TeamMenu: View {
    var formatID: String
    @Binding var selectedTeamID: String
    @Environment(TeamStore.self) private var teams

    private var selected: Team? { teams.team(id: UUID(uuidString: selectedTeamID)) }

    var body: some View {
        let matching = teams.teams.filter { $0.format == formatID }
        let others = teams.teams.filter { $0.format != formatID }
        Menu {
            if !matching.isEmpty {
                Section("For this format") {
                    ForEach(matching) { team in
                        Button(team.name) { selectedTeamID = team.id.uuidString }
                    }
                }
            }
            if !others.isEmpty {
                Section("Other teams") {
                    ForEach(others) { team in
                        Button("\(team.name) · \(team.format)") { selectedTeamID = team.id.uuidString }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                if let selected {
                    HStack(spacing: -8) {
                        ForEach(selected.pokemon.prefix(6)) { set in
                            PokemonArtwork(species: set.species, shiny: set.shiny, size: 34)
                        }
                    }
                    Spacer()
                    Text(selected.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                } else {
                    Image(systemName: "square.stack.3d.up.slash")
                    Text(teams.teams.isEmpty ? "No teams yet — build one in Teams" : "Choose a team")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .foregroundStyle(Theme.textSecondary)
        }
        .disabled(teams.teams.isEmpty)
        .onAppear {
            if selected == nil, let first = matching.first {
                selectedTeamID = first.id.uuidString
            }
        }
    }
}
