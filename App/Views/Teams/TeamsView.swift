import SwiftUI
import ShowdownKit

struct TeamsView: View {
    @Environment(TeamStore.self) private var teams
    @Environment(AppModel.self) private var app
    @State private var path: [UUID] = []
    @State private var showImport = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AuroraBackground(colors: [Theme.accentCyan, Theme.accent, Theme.accentPink], intensity: 0.4)
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if teams.teams.isEmpty {
                            EmptyStateView(
                                symbol: "square.stack.3d.up.fill",
                                title: "No teams yet",
                                message: "Build a team from scratch, or paste one exported from Showdown or a Pokepaste."
                            )
                            .padding(.top, 60)
                            HStack(spacing: 12) {
                                Button {
                                    newTeam()
                                } label: {
                                    Label("New team", systemImage: "plus")
                                }
                                .buttonStyle(PillButtonStyle(tint: Theme.accentPink))
                                Button {
                                    showImport = true
                                } label: {
                                    Label("Import", systemImage: "doc.on.clipboard")
                                }
                                .buttonStyle(PillButtonStyle())
                            }
                        }
                        ForEach(teams.teams) { team in
                            NavigationLink(value: team.id) {
                                TeamCard(team: team, formatName: app.format(id: team.format)?.name ?? team.format)
                            }
                            .buttonStyle(PressableStyle())
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = TeamText.export(team.pokemon)
                                } label: {
                                    Label("Copy as text", systemImage: "doc.on.doc")
                                }
                                Button {
                                    teams.duplicate(team)
                                } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                Button(role: .destructive) {
                                    withAnimation { teams.delete(team) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Teams")
            .navigationDestination(for: UUID.self) { id in
                TeamDetailView(teamID: id)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            newTeam()
                        } label: {
                            Label("New team", systemImage: "plus")
                        }
                        Button {
                            showImport = true
                        } label: {
                            Label("Import from text", systemImage: "doc.on.clipboard")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .sheet(isPresented: $showImport) {
                ImportTeamSheet { imported in
                    if imported.count == 1, let team = imported.first {
                        path.append(team.id)
                    }
                }
            }
        }
    }

    private func newTeam() {
        let format = UserDefaults.standard.string(forKey: "lastTeamFormat") ?? "gen9ou"
        let team = teams.create(format: format)
        path.append(team.id)
    }
}

struct TeamCard: View {
    var team: Team
    var formatName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(team.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(formatName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { index in
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.06))
                            .frame(width: 46, height: 46)
                        if index < team.pokemon.count {
                            let set = team.pokemon[index]
                            PokemonArtwork(species: set.species, shiny: set.shiny, size: 50)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }
}

struct ImportTeamSheet: View {
    var onImport: ([Team]) -> Void
    @Environment(TeamStore.self) private var teams
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var formatID = UserDefaults.standard.string(forKey: "lastTeamFormat") ?? "gen9ou"
    @State private var showFormats = false
    @Environment(AppModel.self) private var app

    private var preview: [Team] {
        TeamText.importTeams(text, defaultFormat: formatID).filter { !$0.pokemon.isEmpty }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                TextEditor(text: $text)
                    .font(.system(.footnote, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .glassCard(cornerRadius: 18)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Paste a Showdown export here…")
                                .font(.footnote)
                                .foregroundStyle(Theme.textTertiary)
                                .padding(18)
                                .allowsHitTesting(false)
                        }
                    }
                HStack {
                    PasteButton(payloadType: String.self) { strings in
                        if let first = strings.first { text = first }
                    }
                    .buttonBorderShape(.capsule)
                    .tint(Theme.accent)
                    .labelStyle(.titleAndIcon)
                    Spacer()
                    Button {
                        showFormats = true
                    } label: {
                        Text(app.format(id: formatID)?.name ?? formatID)
                            .lineLimit(1)
                    }
                    .buttonStyle(PillButtonStyle(tint: Theme.accentCyan))
                }
                let found = preview
                if !found.isEmpty {
                    Text("\(found.count) team\(found.count == 1 ? "" : "s") · \(found.reduce(0) { $0 + $1.pokemon.count }) Pokémon")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                Button {
                    let imported = teams.importText(text, format: formatID)
                    dismiss()
                    onImport(imported)
                } label: {
                    Text("Import")
                }
                .buttonStyle(GlowButtonStyle())
                .disabled(found.isEmpty)
            }
            .padding(18)
            .background(Theme.background)
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .sheet(isPresented: $showFormats) {
                FormatPickerSheet(selection: $formatID, mode: .teambuilder)
            }
        }
        .presentationBackground(Theme.background)
    }
}
