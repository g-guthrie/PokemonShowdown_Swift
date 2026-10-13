import SwiftUI
import ShowdownKit

/// Editing one set. Tapping a field opens Showdown's search chart for it right below,
/// and picking a result moves on to the next field (species → item → ability → moves).
struct SetPage: View {
    var teamID: UUID
    var setID: UUID
    @Environment(TeamStore.self) private var teams
    @Environment(DexStore.self) private var dex
    @State private var field: Field?
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    enum Field: Hashable {
        case species, item, ability, move(Int)

        var title: String {
            switch self {
            case .species: return "Pokémon"
            case .item: return "Item"
            case .ability: return "Ability"
            case .move(let i): return "Move \(i + 1)"
            }
        }
    }

    private var set: PokemonSet? {
        teams.team(id: teamID)?.pokemon.first { $0.id == setID }
    }

    private func update(_ change: (inout PokemonSet) -> Void) {
        guard var team = teams.team(id: teamID), let index = team.pokemon.firstIndex(where: { $0.id == setID }) else { return }
        change(&team.pokemon[index])
        teams.update(team)
    }

    var body: some View {
        RoomPage {
            if let set {
                HStack {
                    BackButton(title: "Team")
                    Spacer()
                }
                header(set)
                if let field {
                    searchPanel(field, set: set)
                } else {
                    fields(set)
                    detailsBox(set)
                    StatsEditor(set: set, base: dex.data.species(named: set.species)?.baseStats, update: update)
                }
            }
        }
        .onAppear {
            if set?.species.isEmpty == true { open(.species) }
        }
    }

    private func open(_ newField: Field) {
        field = newField
        query = ""
        searchFocused = true
    }

    private func header(_ set: PokemonSet) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if !set.species.isEmpty {
                BattleSprite(species: set.species, back: false, shiny: set.shiny, scale: 1, unit: 1)
                    .frame(width: 110, height: 110)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(set.species.isEmpty ? "New Pokémon" : set.species).font(PS.font(18, bold: true))
                HStack(spacing: 3) {
                    ForEach(dex.data.species(named: set.species)?.types ?? [], id: \.self) { TypeIcon(type: $0) }
                }
                Text("Nickname").font(PS.font(10, bold: true)).foregroundStyle(Color(hex: 0x555555))
                TextField(set.species, text: Binding(get: { set.nickname }, set: { value in update { $0.nickname = value } }))
                    .textFieldStyle(PSTextFieldStyle())
                    .autocorrectionDisabled()
            }
        }
    }

    // MARK: Fields

    private func fields(_ set: PokemonSet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldButton("Pokémon", value: set.species, icon: set.species.isEmpty ? nil : AnyView(PokemonIcon(species: set.species))) { open(.species) }
            HStack(spacing: 8) {
                fieldButton("Item", value: set.item, icon: set.item.isEmpty ? nil : AnyView(ItemIcon(item: set.item))) { open(.item) }
                fieldButton("Ability", value: set.ability, icon: nil) { open(.ability) }
            }
            Text("Moves").font(PS.font(11, bold: true)).foregroundStyle(Color(hex: 0x555555))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 6) {
                ForEach(0..<4, id: \.self) { index in
                    let move = index < set.moves.count ? set.moves[index] : ""
                    let type = dex.data.move(named: move)?.type
                    Button {
                        open(.move(index))
                    } label: {
                        HStack(spacing: 4) {
                            if let type { TypeIcon(type: type, scale: 0.8) }
                            Text(move.isEmpty ? "(none)" : move)
                                .font(PS.font(13))
                                .foregroundStyle(move.isEmpty ? PS.gray : .black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 22)
                        .psTextBox()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func fieldButton(_ label: String, value: String, icon: AnyView?, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(PS.font(11, bold: true)).foregroundStyle(Color(hex: 0x555555))
            Button(action: action) {
                HStack(spacing: 4) {
                    if let icon { icon }
                    Text(value.isEmpty ? "(none)" : value)
                        .font(PS.font(13))
                        .foregroundStyle(value.isEmpty ? PS.gray : .black)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 22)
                .psTextBox()
            }
            .buttonStyle(.plain)
        }
    }

    private func detailsBox(_ set: PokemonSet) -> some View {
        let species = dex.data.species(named: set.species)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Details").font(PS.font(11, bold: true)).foregroundStyle(Color(hex: 0x555555))
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level").font(PS.font(10)).foregroundStyle(Color(hex: 0x555555))
                    Stepper(value: Binding(get: { set.level }, set: { value in update { $0.level = value } }), in: 1...100) {
                        Text("\(set.level)").font(PS.font(13))
                    }
                    .fixedSize()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shiny").font(PS.font(10)).foregroundStyle(Color(hex: 0x555555))
                    PSCheckbox(title: set.shiny ? "Yes" : "No", isOn: Binding(get: { set.shiny }, set: { value in update { $0.shiny = value } }))
                }
            }
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gender").font(PS.font(10)).foregroundStyle(Color(hex: 0x555555))
                    Picker("Gender", selection: Binding(get: { set.gender }, set: { value in update { $0.gender = value } })) {
                        Text("Random").tag("")
                        Text("Male").tag("M")
                        Text("Female").tag("F")
                    }
                    .pickerStyle(.segmented)
                    .disabled(species?.gender != nil)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Tera Type").font(PS.font(10)).foregroundStyle(Color(hex: 0x555555))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(TypeChart.types + ["Stellar"], id: \.self) { type in
                            Button {
                                update { $0.teraType = set.teraType == type ? "" : type }
                            } label: {
                                TypeIcon(type: type)
                                    .padding(3)
                                    .background(RoundedRectangle(cornerRadius: 4).fill(set.teraType == type ? Color(hex: 0xBBD4EE) : .clear))
                                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(set.teraType == type ? Color(hex: 0x004488) : .clear, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color(hex: 0xDAE5F0)))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color(hex: 0x999999), lineWidth: 1))
    }

    // MARK: Search chart

    private func searchPanel(_ field: Field, set: PokemonSet) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(field.title).font(PS.font(13, bold: true))
                TextField("Search", text: $query)
                    .textFieldStyle(PSTextFieldStyle())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($searchFocused)
                    .submitLabel(.done)
                Button("Done") { self.field = nil }
                    .buttonStyle(PSButtonStyle(size: .small))
            }
            if case .move = field {
                Button {
                    choose("", for: field)
                } label: {
                    Text("(no move)").font(PS.font(12)).foregroundStyle(PS.gray)
                }
                .buttonStyle(PSButtonStyle(size: .small))
            }
            UtiliChart(field: field, query: query, set: set) { value in
                choose(value, for: field)
            }
        }
    }

    private func choose(_ value: String, for field: Field) {
        switch field {
        case .species:
            let entry = dex.data.species(named: value)
            update { set in
                set.species = value
                if let entry, !entry.abilityList.contains(set.ability) { set.ability = entry.abilityList.first ?? "" }
            }
            open(.item)
        case .item:
            update { $0.item = value }
            open(.ability)
        case .ability:
            update { $0.ability = value }
            let moves = set?.moves ?? []
            if let empty = (0..<4).first(where: { $0 >= moves.count || moves[$0].isEmpty }) {
                open(.move(empty))
            } else {
                self.field = nil
            }
        case .move(let index):
            update { set in
                while set.moves.count <= index { set.moves.append("") }
                set.moves[index] = value
            }
            if index < 3 {
                open(.move(index + 1))
            } else {
                self.field = nil
            }
        }
    }
}

/// Showdown's search result list (`utilichart`).
private struct UtiliChart: View {
    var field: SetPage.Field
    var query: String
    var set: PokemonSet
    var onPick: (String) -> Void
    @Environment(DexStore.self) private var dex

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            switch field {
            case .species:
                ForEach(speciesResults, id: \.name) { species in
                    row { onPick(species.name) } content: { speciesRow(species) }
                }
            case .item:
                ForEach(itemResults, id: \.self) { item in
                    row { onPick(item) } content: {
                        HStack(spacing: 6) {
                            ItemIcon(item: item)
                            Text(item).font(PS.font(13))
                            Spacer()
                        }
                    }
                }
            case .ability:
                ForEach(abilityResults, id: \.self) { ability in
                    row { onPick(ability) } content: {
                        Text(ability).font(PS.font(13, bold: true)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            case .move:
                ForEach(moveResults, id: \.name) { move in
                    row { onPick(move.name) } content: { moveRow(move) }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 4).fill(PS.roomOpaque))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(PS.border, lineWidth: 1))
    }

    private func row<Content: View>(_ action: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            content()
                .foregroundStyle(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(RowStyle())
        .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0xD8DEE3)).frame(height: 1) }
    }

    private struct RowStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.background(configuration.isPressed ? Color(hex: 0xF8F8F8) : .clear)
        }
    }

    // Species

    private var speciesResults: [DexSpecies] {
        let all = dex.data.playableSpecies
        let id = toID(query)
        guard !id.isEmpty else { return Array(all.prefix(200)) }
        let starts = all.filter { toID($0.name).hasPrefix(id) }
        let contains = all.filter { !toID($0.name).hasPrefix(id) && (toID($0.name).contains(id) || $0.types.contains { toID($0) == id }) }
        return Array((starts + contains).prefix(200))
    }

    private func speciesRow(_ species: DexSpecies) -> some View {
        HStack(spacing: 4) {
            PokemonIcon(species: species.name)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(species.name).font(PS.font(13, bold: true)).lineLimit(1)
                    if let tier = species.tier {
                        Text(tier).font(PS.font(10)).foregroundStyle(PS.gray)
                    }
                }
                HStack(spacing: 2) {
                    ForEach(species.types, id: \.self) { TypeIcon(type: $0) }
                    Text(species.abilityList.joined(separator: " / "))
                        .font(PS.font(9))
                        .foregroundStyle(Color(hex: 0x555555))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 2)
            HStack(spacing: 2) {
                ForEach(StatSpread.keys, id: \.self) { key in
                    VStack(spacing: 0) {
                        Text(StatSpread.labels[key] ?? key).font(.system(size: 7)).foregroundStyle(PS.gray)
                        Text("\(species.baseStats[key])").font(PS.font(10))
                    }
                    .frame(width: 22)
                }
                VStack(spacing: 0) {
                    Text("BST").font(.system(size: 7)).foregroundStyle(PS.gray)
                    Text("\(species.baseStats.total)").font(PS.font(10, bold: true))
                }
                .frame(width: 26)
            }
        }
    }

    // Items and abilities

    private var itemResults: [String] {
        let names = Array(Set(dex.data.items.values)).sorted()
        guard !query.isEmpty else { return names }
        let id = toID(query)
        return names.filter { toID($0).contains(id) }
    }

    private var abilityResults: [String] {
        let legal = dex.data.species(named: set.species)?.abilityList ?? []
        if query.isEmpty, !legal.isEmpty { return legal }
        let id = toID(query)
        let all = Array(Set(dex.data.abilities.values)).sorted()
        return legal.filter { toID($0).contains(id) } + all.filter { !legal.contains($0) && toID($0).contains(id) }
    }

    // Moves

    private var moveResults: [DexMove] {
        let id = toID(query)
        return dex.data.moves.values
            .filter { $0.num > 0 && ($0.isNonstandard == nil || !id.isEmpty) }
            .filter { id.isEmpty || toID($0.name).contains(id) || toID($0.type) == id }
            .sorted { $0.name < $1.name }
    }

    private func moveRow(_ move: DexMove) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(move.name).font(PS.font(13, bold: true)).lineLimit(1)
                Spacer(minLength: 2)
                TypeIcon(type: move.type)
                CategoryIcon(category: move.category)
                stat("Pow", move.basePower > 0 ? "\(move.basePower)" : "—")
                stat("Acc", move.accuracy.map { "\($0)%" } ?? "—")
                stat("PP", "\(move.pp)")
            }
            if let desc = move.shortDesc {
                Text(desc).font(PS.font(10)).foregroundStyle(Color(hex: 0x555555)).lineLimit(2)
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            Text(label).font(.system(size: 7)).foregroundStyle(PS.gray)
            Text(value).font(PS.font(10))
        }
        .frame(width: 30)
    }
}

/// EVs, IVs and nature (`.statform`).
private struct StatsEditor: View {
    var set: PokemonSet
    var base: StatSpread?
    var update: ((inout PokemonSet) -> Void) -> Void

    var body: some View {
        let stats = StatCalculator.stats(for: set, base: base ?? StatSpread(all: 0))
        let remaining = 510 - set.evs.total
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Stats").font(PS.font(11, bold: true)).foregroundStyle(Color(hex: 0x555555))
                Spacer()
                Menu {
                    ForEach(Natures.all, id: \.self) { nature in
                        Button(natureLabel(nature)) { update { $0.nature = nature } }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(set.nature.isEmpty ? "Serious" : natureLabel(set.nature))
                        FAIcon(.caretDown, size: 12)
                    }
                    .font(PS.font(12))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [Color(hex: 0xF6F6F6), Color(hex: 0xE3E3E3)], startPoint: .top, endPoint: .bottom)))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: 0x888888), lineWidth: 1))
                }
            }
            HStack(spacing: 4) {
                Text("").frame(width: 30)
                Text("Base").frame(width: 60, alignment: .leading)
                Text("EVs").frame(maxWidth: .infinity, alignment: .leading)
                Text("IV").frame(width: 34)
                Text("").frame(width: 36)
            }
            .font(PS.font(9))
            .foregroundStyle(PS.gray)
            ForEach(StatSpread.keys, id: \.self) { key in
                HStack(spacing: 4) {
                    Text(StatSpread.labels[key] ?? key)
                        .font(PS.font(11, bold: true))
                        .foregroundStyle(natureColor(key))
                        .frame(width: 30, alignment: .leading)
                    HStack(spacing: 3) {
                        Rectangle()
                            .fill(StatColor.baseColor(base?[key] ?? 0))
                            .frame(width: CGFloat(min(255, base?[key] ?? 0)) / 255 * 34, height: 8)
                        Text("\(base?[key] ?? 0)").font(PS.font(10))
                    }
                    .frame(width: 60, alignment: .leading)
                    Slider(value: evBinding(key), in: 0...252, step: 4)
                        .tint(StatColor.color(for: stats[key], key: key))
                    Text("\(set.evs[key])").font(PS.font(10)).frame(width: 22, alignment: .trailing)
                    TextField("31", value: ivBinding(key), format: .number)
                        .keyboardType(.numberPad)
                        .font(PS.font(11))
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xF8FBFD)))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(PS.border, lineWidth: 1))
                    Text("\(stats[key])").font(PS.font(12, bold: true)).frame(width: 36, alignment: .trailing)
                }
            }
            HStack {
                Spacer()
                Text("Remaining: \(remaining)")
                    .font(PS.font(11, bold: remaining < 0))
                    .foregroundStyle(remaining < 0 ? Color(hex: 0xCC3311) : Color(hex: 0x555555))
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color(hex: 0xDAE5F0)))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color(hex: 0x999999), lineWidth: 1))
    }

    private func evBinding(_ key: String) -> Binding<Double> {
        Binding(
            get: { Double(set.evs[key]) },
            set: { value in
                update { set in
                    let others = set.evs.total - set.evs[key]
                    let capped = min(Int(value), max(0, 510 - others))
                    set.evs[key] = capped - capped % 4
                }
            }
        )
    }

    private func ivBinding(_ key: String) -> Binding<Int> {
        Binding(get: { set.ivs[key] }, set: { value in update { $0.ivs[key] = max(0, min(31, value)) } })
    }

    private func natureColor(_ key: String) -> Color {
        guard let effect = Natures.effects[set.nature] else { return .black }
        if effect.plus == key { return Color(hex: 0xCC3311) }
        if effect.minus == key { return Color(hex: 0x1155CC) }
        return .black
    }

    private func natureLabel(_ nature: String) -> String {
        guard let effect = Natures.effects[nature] else { return nature }
        return "\(nature) (+\(StatSpread.labels[effect.plus] ?? ""), -\(StatSpread.labels[effect.minus] ?? ""))"
    }
}
