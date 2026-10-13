import SwiftUI
import ShowdownKit

/// One team: name, format and its set charts (`panel-teambuilder-team.tsx`).
struct TeamPage: View {
    var teamID: UUID
    @Binding var path: [TeambuilderPage]
    @Environment(TeamStore.self) private var teams
    @Environment(AppModel.self) private var app
    @State private var showText = false
    @State private var text = ""

    private var team: Team? { teams.team(id: teamID) }

    private func update(_ change: (inout Team) -> Void) {
        guard var team else { return }
        change(&team)
        teams.update(team)
        UserDefaults.standard.set(team.format, forKey: "lastTeamFormat")
    }

    var body: some View {
        RoomPage {
            if let team {
                HStack(spacing: 6) {
                    BackButton(title: "List")
                    Spacer()
                    Button {
                        text = TeamText.export(team.pokemon)
                        showText.toggle()
                    } label: {
                        HStack(spacing: 4) { FAIcon(showText ? .list : .upload, size: 12); Text(showText ? "Set view" : "Import/Export") }
                    }
                    .buttonStyle(PSButtonStyle(size: .small))
                    Menu {
                        Button {
                            UIPasteboard.general.string = TeamText.export(team.pokemon)
                        } label: {
                            Label("Copy as text", systemImage: "doc.on.doc")
                        }
                        Button {
                            teams.duplicate(team)
                        } label: {
                            Label("Duplicate team", systemImage: "plus.square.on.square")
                        }
                        Button(role: .destructive) {
                            app.popup = .confirm(message: "Delete \(team.name)?", button: "Delete") {
                                teams.delete(team)
                                path.removeAll()
                            }
                        } label: {
                            Label("Delete team", systemImage: "trash")
                        }
                    } label: {
                        Text("•••").font(PS.font(12, bold: true)).foregroundStyle(PS.text)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 5).fill(LinearGradient(colors: [Color(hex: 0xF6F6F6), Color(hex: 0xE3E3E3)], startPoint: .top, endPoint: .bottom)))
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(PS.border, lineWidth: 1))
                    }
                }

                TextField("Team name", text: Binding(get: { team.name }, set: { name in update { $0.name = name } }))
                    .font(PS.font(16, bold: true))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xF8FBFD)))
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(PS.border, lineWidth: 1))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Format:").font(PS.font(11, bold: true))
                    FormatSelect(formatID: Binding(get: { team.format }, set: { format in update { $0.format = format } }), mode: .teambuilder)
                }

                if showText {
                    TextEditor(text: $text)
                        .font(.system(size: 12, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 420)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xF8FBFD)))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(PS.border, lineWidth: 1))
                    Button {
                        let sets = TeamText.importSets(text)
                        update { $0.pokemon = sets }
                        showText = false
                    } label: {
                        Text("Save changes").font(PS.font(13, bold: true))
                    }
                    .buttonStyle(PSButtonStyle())
                } else {
                    ForEach(Array(team.pokemon.enumerated()), id: \.element.id) { index, set in
                        SetChart(set: set) {
                            path.append(.set(team: teamID, set: set.id))
                        }
                        .contextMenu {
                            if index > 0 {
                                Button {
                                    update { $0.pokemon.swapAt(index, index - 1) }
                                } label: {
                                    Label("Move up", systemImage: "arrow.up")
                                }
                            }
                            if index < team.pokemon.count - 1 {
                                Button {
                                    update { $0.pokemon.swapAt(index, index + 1) }
                                } label: {
                                    Label("Move down", systemImage: "arrow.down")
                                }
                            }
                            Button {
                                UIPasteboard.general.string = TeamText.export(set)
                            } label: {
                                Label("Copy set", systemImage: "doc.on.doc")
                            }
                            Button(role: .destructive) {
                                update { $0.pokemon.removeAll { $0.id == set.id } }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    if team.pokemon.count < 6 {
                        Button {
                            var set = PokemonSet()
                            set.moves = ["", "", "", ""]
                            if app.format(id: team.format)?.levelCap50 == true { set.level = 50 }
                            update { $0.pokemon.append(set) }
                            path.append(.set(team: teamID, set: set.id))
                        } label: {
                            HStack(spacing: 5) { FAIcon(.plus, size: 13); Text("Add Pokémon") }
                        }
                        .buttonStyle(PSButtonStyle(size: .big))
                    }
                }
            }
        }
    }
}

/// `.setchart`: a compact summary of one set.
struct SetChart: View {
    var set: PokemonSet
    var action: () -> Void
    @Environment(DexStore.self) private var dex

    var body: some View {
        let species = dex.data.species(named: set.species)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 6) {
                    ZStack {
                        if !set.species.isEmpty {
                            RemoteImage(path: Sprites.battleURLs(species: set.species, back: false, shiny: set.shiny, dex: dex.data)[1].absoluteString)
                                .frame(width: 96, height: 96)
                        } else {
                            Text("?").font(PS.font(30, bold: true)).foregroundStyle(PS.gray)
                        }
                    }
                    .frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text(set.species.isEmpty ? "(new Pokémon)" : set.displayName)
                                .font(PS.font(14, bold: true))
                                .lineLimit(1)
                            if !set.nickname.isEmpty && set.nickname != set.species {
                                Text("(\(set.species))").font(PS.font(11)).foregroundStyle(PS.gray).lineLimit(1)
                            }
                        }
                        HStack(spacing: 3) {
                            ForEach(species?.types ?? [], id: \.self) { TypeIcon(type: $0) }
                            if !set.teraType.isEmpty {
                                Text("Tera").font(PS.font(9)).foregroundStyle(PS.gray)
                                RemoteImage(path: "sprites/types/Tera\(set.teraType).png", pixelated: false).frame(width: 14, height: 14)
                            }
                        }
                        detailRow("Level", set.level == 100 ? "100" : "\(set.level)")
                        HStack(spacing: 3) {
                            Text("Item").font(PS.font(10, bold: true)).foregroundStyle(Color(hex: 0x555555)).frame(width: 44, alignment: .leading)
                            if !set.item.isEmpty { ItemIcon(item: set.item, scale: 0.8) }
                            Text(set.item.isEmpty ? "—" : set.item).font(PS.font(12)).lineLimit(1)
                        }
                        detailRow("Ability", set.ability.isEmpty ? "—" : set.ability)
                    }
                    Spacer(minLength: 0)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                    ForEach(0..<4, id: \.self) { index in
                        let move = index < set.moves.count ? set.moves[index] : ""
                        Text(move.isEmpty ? " " : move)
                            .font(PS.font(12))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .psTextBox()
                    }
                }
                EVSummary(set: set, base: species?.baseStats)
            }
            .foregroundStyle(.black)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color(hex: 0xDAE5F0)))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.6), lineWidth: 1).padding(1))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color(hex: 0x999999), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(label).font(PS.font(10, bold: true)).foregroundStyle(Color(hex: 0x555555)).frame(width: 44, alignment: .leading)
            Text(value).font(PS.font(12)).lineLimit(1)
        }
    }
}

/// The stat bars beside a set (`.setstats`), colored like Showdown's.
struct EVSummary: View {
    var set: PokemonSet
    var base: StatSpread?

    var body: some View {
        let stats = base.map { StatCalculator.stats(for: set, base: $0) }
        HStack(spacing: 6) {
            ForEach(StatSpread.keys, id: \.self) { key in
                VStack(spacing: 1) {
                    Text(StatSpread.labels[key] ?? key).font(PS.font(9)).foregroundStyle(Color(hex: 0x555555))
                    GeometryReader { proxy in
                        let value = stats?[key] ?? 0
                        ZStack(alignment: .bottom) {
                            Rectangle().fill(.white.opacity(0.5))
                            Rectangle()
                                .fill(StatColor.color(for: value, key: key))
                                .frame(height: proxy.size.height * min(1, Double(value) / (key == "hp" ? 704 : 504)))
                        }
                    }
                    .frame(width: 18, height: 22)
                    .overlay(Rectangle().strokeBorder(Color(hex: 0x999999), lineWidth: 0.5))
                    Text(set.evs[key] > 0 ? "\(set.evs[key])" : "").font(PS.font(9)).frame(height: 10)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

enum StatColor {
    /// Showdown colors stat bars on a red→green→blue hue ramp.
    static func color(for value: Int, key: String) -> Color {
        let normalized = key == "hp" ? Double(value) * 0.5 : Double(value) * 0.75
        let hue = min(360, max(0, normalized * 180 / 255))
        return Color(hue: hue, saturation: 0.85, lightness: 0.45)
    }

    static func baseColor(_ base: Int) -> Color {
        let hue = min(360, Double(base) * 180 / 255)
        return Color(hue: hue, saturation: 0.85, lightness: 0.45)
    }
}
