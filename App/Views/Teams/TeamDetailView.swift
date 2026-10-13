import SwiftUI
import ShowdownKit

struct TeamDetailView: View {
    var teamID: UUID
    @Environment(TeamStore.self) private var teams
    @Environment(AppModel.self) private var app
    @Environment(DexStore.self) private var dex
    @Environment(\.dismiss) private var dismiss
    @State private var team = Team(name: "", format: "gen9ou", pokemon: [])
    @State private var loaded = false
    @State private var showFormats = false
    @State private var showSpeciesPicker = false
    @State private var showTextEditor = false
    @State private var editingSetID: UUID?
    @State private var copied = false

    var body: some View {
        ZStack {
            AuroraBackground(colors: [Theme.accent, Theme.accentCyan], intensity: 0.3)
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Team name", text: $team.name)
                            .font(.title2.weight(.heavy))
                        Button {
                            showFormats = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trophy.fill")
                                Text(app.format(id: team.format)?.name ?? team.format)
                                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(PillButtonStyle(tint: Theme.accentCyan))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .glassCard(cornerRadius: 24)

                    ForEach(team.pokemon) { set in
                        Button {
                            editingSetID = set.id
                        } label: {
                            SetCard(set: set)
                        }
                        .buttonStyle(PressableStyle())
                        .contextMenu {
                            Button {
                                move(set, by: -1)
                            } label: {
                                Label("Move up", systemImage: "arrow.up")
                            }
                            Button {
                                move(set, by: 1)
                            } label: {
                                Label("Move down", systemImage: "arrow.down")
                            }
                            Button(role: .destructive) {
                                withAnimation { team.pokemon.removeAll { $0.id == set.id } }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }

                    if team.pokemon.count < 6 {
                        Button {
                            showSpeciesPicker = true
                        } label: {
                            Label("Add Pokémon", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background {
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                        }
                        .buttonStyle(PressableStyle())
                        .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(team.name.isEmpty ? "Team" : team.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        UIPasteboard.general.string = TeamText.export(team.pokemon)
                        copied = true
                    } label: {
                        Label("Copy as text", systemImage: "doc.on.doc")
                    }
                    ShareLink(item: TeamText.export(team.pokemon)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showTextEditor = true
                    } label: {
                        Label("Edit as text", systemImage: "text.alignleft")
                    }
                    Button(role: .destructive) {
                        teams.delete(team)
                        loaded = false
                        dismiss()
                    } label: {
                        Label("Delete team", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .navigationDestination(item: $editingSetID) { id in
            if let index = team.pokemon.firstIndex(where: { $0.id == id }) {
                SetEditorView(set: $team.pokemon[index])
            }
        }
        .sheet(isPresented: $showFormats) {
            FormatPickerSheet(selection: $team.format, mode: .teambuilder)
        }
        .sheet(isPresented: $showSpeciesPicker) {
            NavigationStack {
                SpeciesPicker { species in
                    var set = PokemonSet(species: species.name)
                    set.ability = species.abilityList.first ?? ""
                    set.moves = ["", "", "", ""]
                    if app.format(id: team.format)?.levelCap50 == true { set.level = 50 }
                    team.pokemon.append(set)
                    showSpeciesPicker = false
                    editingSetID = set.id
                }
            }
            .presentationBackground(Theme.background)
        }
        .sheet(isPresented: $showTextEditor) {
            TeamTextEditor(text: TeamText.export(team.pokemon)) { text in
                team.pokemon = TeamText.importSets(text)
            }
        }
        .alert("Copied to clipboard", isPresented: $copied) {
            Button("OK", role: .cancel) {}
        }
        .onAppear {
            guard !loaded, let stored = teams.team(id: teamID) else { return }
            team = stored
            loaded = true
        }
        .onChange(of: team) { _, newValue in
            guard loaded else { return }
            teams.update(newValue)
            UserDefaults.standard.set(newValue.format, forKey: "lastTeamFormat")
        }
    }

    private func move(_ set: PokemonSet, by offset: Int) {
        guard let index = team.pokemon.firstIndex(where: { $0.id == set.id }) else { return }
        let target = index + offset
        guard target >= 0, target < team.pokemon.count else { return }
        withAnimation { team.pokemon.swapAt(index, target) }
    }
}

struct SetCard: View {
    var set: PokemonSet
    @Environment(DexStore.self) private var dex

    var body: some View {
        let species = dex.data.species(named: set.species)
        let primary = species?.types.first ?? "Normal"
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Theme.typeColor(primary).opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 42))
                    .frame(width: 80, height: 80)
                PokemonArtwork(species: set.species, shiny: set.shiny, size: 70)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(set.displayName)
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                    if !set.nickname.isEmpty && set.nickname != set.species {
                        Text(set.species)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if !set.teraType.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "diamond.fill")
                            Text(set.teraType)
                        }
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.typeColor(set.teraType))
                    }
                }
                HStack(spacing: 4) {
                    ForEach(species?.types ?? [], id: \.self) { TypeBadge(type: $0, compact: true) }
                    Text([set.item, set.ability].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(Array(set.moves.filter { !$0.isEmpty }.enumerated()), id: \.offset) { _, move in
                        let type = dex.data.move(named: move)?.type ?? "Normal"
                        Text(move)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Theme.typeGradient(type)))
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .glassCard(cornerRadius: 24)
    }
}

struct TeamTextEditor: View {
    @State var text: String
    var onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(.system(.footnote, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Theme.background)
                .navigationTitle("Edit as text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(text)
                            dismiss()
                        }
                    }
                }
        }
        .presentationBackground(Theme.background)
    }
}
