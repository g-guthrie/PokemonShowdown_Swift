import SwiftUI
import ShowdownKit

struct SetEditorView: View {
    @Binding var set: PokemonSet
    @Environment(DexStore.self) private var dex
    @State private var showSpecies = false

    private var species: DexSpecies? { dex.data.species(named: set.species) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                detailsCard
                movesCard
                statsCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background {
            ZStack {
                Theme.background
                RadialGradient(colors: [Theme.typeColor(species?.types.first ?? "Normal").opacity(0.45), .clear], center: .top, startRadius: 0, endRadius: 420)
            }
            .ignoresSafeArea()
        }
        .navigationTitle(set.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSpecies) {
            NavigationStack {
                SpeciesPicker { picked in
                    set.species = picked.name
                    if !picked.abilityList.contains(set.ability) {
                        set.ability = picked.abilityList.first ?? ""
                    }
                    showSpecies = false
                }
            }
            .presentationBackground(Theme.background)
        }
        .onAppear {
            while set.moves.count < 4 { set.moves.append("") }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 8) {
            Button {
                showSpecies = true
            } label: {
                PokemonArtwork(species: set.species, shiny: set.shiny, size: 170)
                    .shadow(color: Theme.typeColor(species?.types.first ?? "Normal").opacity(0.6), radius: 30)
            }
            .buttonStyle(PressableStyle())
            Text(set.species)
                .font(.title.weight(.heavy))
            HStack(spacing: 6) {
                ForEach(species?.types ?? [], id: \.self) { TypeBadge(type: $0) }
            }
            Button("Change Pokémon") { showSpecies = true }
                .buttonStyle(PillButtonStyle())
                .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    // MARK: Details

    private var detailsCard: some View {
        VStack(spacing: 0) {
            EditorRow(title: "Nickname") {
                TextField(set.species, text: $set.nickname)
                    .multilineTextAlignment(.trailing)
            }
            Divider().overlay(.white.opacity(0.08))
            NavigationLink {
                ItemPicker(selection: $set.item)
            } label: {
                EditorRow(title: "Item") {
                    Text(set.item.isEmpty ? "None" : set.item)
                        .foregroundStyle(set.item.isEmpty ? Theme.textTertiary : .white)
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)
                }
            }
            Divider().overlay(.white.opacity(0.08))
            EditorRow(title: "Ability") {
                Menu {
                    ForEach(species?.abilityList ?? [], id: \.self) { ability in
                        Button(ability) { set.ability = ability }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(set.ability.isEmpty ? "Choose" : set.ability)
                        Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.bold))
                    }
                }
            }
            Divider().overlay(.white.opacity(0.08))
            EditorRow(title: "Tera Type") {
                Menu {
                    Button("None") { set.teraType = "" }
                    ForEach(TypeChart.types + ["Stellar"], id: \.self) { type in
                        Button(type) { set.teraType = type }
                    }
                } label: {
                    if set.teraType.isEmpty {
                        Text("Default").foregroundStyle(Theme.textTertiary)
                    } else {
                        TypeBadge(type: set.teraType)
                    }
                }
            }
            Divider().overlay(.white.opacity(0.08))
            EditorRow(title: "Level") {
                Stepper(value: $set.level, in: 1...100) {
                    Text("\(set.level)").monospacedDigit()
                }
                .fixedSize()
            }
            Divider().overlay(.white.opacity(0.08))
            EditorRow(title: "Gender") {
                Picker("Gender", selection: $set.gender) {
                    Text("Any").tag("")
                    Text("♂").tag("M")
                    Text("♀").tag("F")
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .disabled(species?.gender != nil)
            }
            Divider().overlay(.white.opacity(0.08))
            EditorRow(title: "Shiny") {
                Toggle("Shiny", isOn: $set.shiny)
                    .labelsHidden()
                    .tint(Theme.gold)
            }
        }
        .glassCard(cornerRadius: 22)
    }

    // MARK: Moves

    private var movesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Moves", symbol: "bolt.fill")
            ForEach(0..<4, id: \.self) { index in
                NavigationLink {
                    MovePicker(selection: moveBinding(index))
                } label: {
                    let name = index < set.moves.count ? set.moves[index] : ""
                    let move = dex.data.move(named: name)
                    HStack(spacing: 10) {
                        if let move {
                            TypeBadge(type: move.type, compact: true)
                            Text(move.name).font(.subheadline.weight(.bold))
                            Spacer()
                            CategoryIcon(category: move.category)
                            if move.basePower > 0 {
                                Text("\(move.basePower)").font(.caption.weight(.bold)).foregroundStyle(Theme.textSecondary)
                            }
                        } else {
                            Image(systemName: "plus.circle.fill").foregroundStyle(Theme.textTertiary)
                            Text(name.isEmpty ? "Add move" : name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(name.isEmpty ? Theme.textTertiary : .white)
                            Spacer()
                        }
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)
                    }
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(move.map { Theme.typeColor($0.type).opacity(0.18) } ?? Color.white.opacity(0.05)))
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func moveBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { index < set.moves.count ? set.moves[index] : "" },
            set: { newValue in
                while set.moves.count <= index { set.moves.append("") }
                set.moves[index] = newValue
            }
        )
    }

    // MARK: Stats

    private var statsCard: some View {
        let base = species?.baseStats ?? StatSpread(all: 0)
        let stats = StatCalculator.stats(for: set, base: base)
        let remaining = 510 - set.evs.total
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Stats", symbol: "chart.bar.fill")
                Menu {
                    ForEach(Natures.all, id: \.self) { nature in
                        Button(natureLabel(nature)) { set.nature = nature }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(set.nature.isEmpty ? "Nature" : set.nature)
                        Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            ForEach(StatSpread.keys, id: \.self) { key in
                VStack(spacing: 4) {
                    HStack {
                        Text(StatSpread.labels[key] ?? key)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(natureColor(key))
                            .frame(width: 34, alignment: .leading)
                        Text("\(base[key])")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 30, alignment: .leading)
                        Slider(value: evBinding(key), in: 0...252, step: 4)
                            .tint(Theme.typeColor(species?.types.first ?? "Normal"))
                        Text("\(set.evs[key])")
                            .font(.caption.monospacedDigit().weight(.bold))
                            .frame(width: 30, alignment: .trailing)
                        Text("\(stats[key])")
                            .font(.subheadline.monospacedDigit().weight(.heavy))
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            HStack {
                Text("EVs remaining")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(remaining)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(remaining < 0 ? Color(hex: 0xFF6B6B) : .white)
            }
            DisclosureGroup("IVs") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                    ForEach(StatSpread.keys, id: \.self) { key in
                        VStack(spacing: 2) {
                            Text(StatSpread.labels[key] ?? key)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.textSecondary)
                            Stepper(value: ivBinding(key), in: 0...31) {
                                Text("\(set.ivs[key])").font(.caption.monospacedDigit().weight(.bold))
                            }
                            .labelsHidden()
                            Text("\(set.ivs[key])").font(.caption.monospacedDigit().weight(.bold))
                        }
                    }
                }
                .padding(.top, 8)
            }
            .font(.subheadline.weight(.semibold))
            .tint(.white)
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func evBinding(_ key: String) -> Binding<Double> {
        Binding(
            get: { Double(set.evs[key]) },
            set: { newValue in
                let others = set.evs.total - set.evs[key]
                let capped = min(Int(newValue), max(0, 510 - others))
                set.evs[key] = capped - capped % 4
            }
        )
    }

    private func ivBinding(_ key: String) -> Binding<Int> {
        Binding(get: { set.ivs[key] }, set: { set.ivs[key] = $0 })
    }

    private func natureColor(_ key: String) -> Color {
        guard let effect = Natures.effects[set.nature] else { return .white }
        if effect.plus == key { return Color(hex: 0xFF8A8A) }
        if effect.minus == key { return Color(hex: 0x8AB4FF) }
        return .white
    }

    private func natureLabel(_ nature: String) -> String {
        guard let effect = Natures.effects[nature] else { return nature }
        return "\(nature)  (+\(StatSpread.labels[effect.plus] ?? "") −\(StatSpread.labels[effect.minus] ?? ""))"
    }
}

private struct EditorRow<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 12)
            content
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 50)
    }
}

// MARK: - Pickers

struct SpeciesPicker: View {
    var onSelect: (DexSpecies) -> Void
    @Environment(DexStore.self) private var dex
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [DexSpecies] {
        let all = dex.data.playableSpecies
        guard !query.isEmpty else { return all }
        let id = toID(query)
        return all.filter { toID($0.name).contains(id) || $0.types.contains { $0.localizedCaseInsensitiveContains(query) } }
    }

    var body: some View {
        List(results, id: \.name) { species in
            Button {
                onSelect(species)
            } label: {
                HStack(spacing: 12) {
                    PokemonArtwork(species: species.name, size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(species.name).font(.body.weight(.semibold)).foregroundStyle(.white)
                        HStack(spacing: 4) {
                            ForEach(species.types, id: \.self) { TypeBadge(type: $0, compact: true) }
                            if let tier = species.tier {
                                Text(tier).font(.caption2.weight(.bold)).foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                    Spacer()
                    Text("\(species.baseStats.total)")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .listRowBackground(Color.white.opacity(0.04))
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Pokémon or type")
        .navigationTitle("Pokémon")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
        .overlay {
            if !dex.isLoaded { ProgressView("Loading Pokédex…") }
        }
    }
}

struct MovePicker: View {
    @Binding var selection: String
    @Environment(DexStore.self) private var dex
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [DexMove] {
        let id = toID(query)
        return dex.data.moves.values
            .filter { $0.num > 0 && ($0.isNonstandard == nil || !id.isEmpty) }
            .filter { id.isEmpty || toID($0.name).contains(id) || toID($0.type) == id }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            if !selection.isEmpty {
                Button("Remove move", role: .destructive) {
                    selection = ""
                    dismiss()
                }
                .listRowBackground(Color.white.opacity(0.04))
            }
            ForEach(results, id: \.name) { move in
                Button {
                    selection = move.name
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            TypeBadge(type: move.type, compact: true)
                            Text(move.name).font(.body.weight(.semibold)).foregroundStyle(.white)
                            Spacer()
                            CategoryIcon(category: move.category)
                            Text(move.basePower > 0 ? "\(move.basePower)" : "—")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .frame(width: 28, alignment: .trailing)
                            Text(move.accuracy.map { "\($0)%" } ?? "—")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 38, alignment: .trailing)
                        }
                        if let desc = move.shortDesc {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(2)
                        }
                    }
                }
                .listRowBackground(move.name == selection ? Theme.accent.opacity(0.25) : Color.white.opacity(0.04))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search moves or type")
        .navigationTitle("Move")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ItemPicker: View {
    @Binding var selection: String
    @Environment(DexStore.self) private var dex
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [String] {
        let names = Array(Set(dex.data.items.values)).sorted()
        guard !query.isEmpty else { return names }
        return names.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            Button("No item") {
                selection = ""
                dismiss()
            }
            .listRowBackground(Color.white.opacity(0.04))
            ForEach(results, id: \.self) { item in
                Button {
                    selection = item
                    dismiss()
                } label: {
                    HStack {
                        Text(item).foregroundStyle(.white)
                        Spacer()
                        if item == selection {
                            Image(systemName: "checkmark").foregroundStyle(Theme.accentPink)
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.04))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search items")
        .navigationTitle("Item")
        .navigationBarTitleDisplayMode(.inline)
    }
}
