import SwiftUI
import ShowdownKit

/// Geometry from `battle-animations.ts` (`pos()` and `recalculatePos()`), in Showdown's 640×360 scene pixels.
enum SceneLayout {
    /// The phone view crops the 100px trainer bars off each side of the 640px scene.
    static let cropX: CGFloat = 100
    static let width: CGFloat = 440
    static let height: CGFloat = 360

    struct Placement {
        var center: CGPoint
        var scale: CGFloat
        var statbar: CGPoint
    }

    static func placement(isFront: Bool, slot: Int, activeCount: Int) -> Placement {
        let moreActive = activeCount - 1
        var x: CGFloat = 0
        switch moreActive {
        case 0: x = 0
        case 1: x = CGFloat(slot * -75 + 18) * (isFront ? 1 : -1)
        default: x = CGFloat(slot * -70 + 20) * (isFront ? 1 : -1)
        }
        let y: CGFloat = isFront ? CGFloat(slot * 7) : CGFloat(slot * -10)
        let z: CGFloat = isFront ? 200 : 0
        let scale = 1.5 - 0.5 * (z / 200)
        let left = 210 + 220 * (z / 200) + floor(x * scale)
        let top = 245 - 110 * (z / 200) - floor(y * scale)

        var statbarOffset: CGFloat = 0
        if isFront { statbarOffset = CGFloat(17 * slot) }
        if !isFront { statbarOffset = CGFloat(-7 * slot) }
        if isFront && moreActive == 2 { statbarOffset = CGFloat(14 * slot - 10) }
        statbarOffset += isFront ? 30 : 20
        let statTop = top - floor(96 * scale / 2) + 40
        let statbar = CGPoint(x: left - 80 - cropX, y: max(-4, statTop - 73 - statbarOffset))
        return Placement(center: CGPoint(x: left - cropX, y: top), scale: scale, statbar: statbar)
    }

    static let backdrops = [
        "bg-aquacordetown", "bg-beach", "bg-city", "bg-dampcave", "bg-darkbeach", "bg-darkcity", "bg-darkmeadow",
        "bg-deepsea", "bg-desert", "bg-earthycave", "bg-elite4drake", "bg-forest", "bg-icecave", "bg-leaderwallace",
        "bg-library", "bg-meadow", "bg-orasdesert", "bg-orassea", "bg-skypillar",
    ]

    static func backdrop(for roomID: String) -> String {
        let hash = roomID.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFFFFFF }
        return "sprites/gen6bgs/\(backdrops[hash % backdrops.count]).jpg"
    }
}

struct BattleSceneView: View {
    var battle: BattleController

    var body: some View {
        GeometryReader { proxy in
            let unit = proxy.size.width / SceneLayout.width
            let state = battle.state
            let count = state.activesPerSide
            ZStack(alignment: .topLeading) {
                PS.battleBG
                RemoteImage(path: SceneLayout.backdrop(for: battle.id), pixelated: false)
                    .frame(width: 700 * unit, height: 500 * unit)
                    .offset(x: (-50 - SceneLayout.cropX) * unit, y: -90 * unit)
                    .opacity(0.8)
                WeatherLayers(weather: state.weather, fields: state.fields, unit: unit)

                // Far side first so near sprites overlap it.
                ForEach(0..<count, id: \.self) { slot in
                    sprite(side: state.opponentSideID, slot: slot, isFront: true, count: count, unit: unit)
                }
                ForEach(0..<count, id: \.self) { slot in
                    sprite(side: state.perspective, slot: slot, isFront: false, count: count, unit: unit)
                }
                ForEach(0..<count, id: \.self) { slot in
                    statbar(side: state.opponentSideID, slot: slot, isFront: true, count: count, unit: unit)
                    statbar(side: state.perspective, slot: slot, isFront: false, count: count, unit: unit)
                }

                FieldText(state: state)
                    .scaleEffect(unit, anchor: .topLeading)
                    .offset(x: 15 * unit, y: 44 * unit)

                if state.turn > 0 {
                    Text("Turn \(state.turn)")
                        .font(PS.font(17, bold: true))
                        .foregroundStyle(Color(hex: 0x332200))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0xFCFAF2)))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: 0x332200), lineWidth: 2))
                        .scaleEffect(unit, anchor: .topLeading)
                        .offset(x: 10 * unit, y: 10 * unit)
                        .id(state.turn)
                        .transition(.opacity)
                }

                if state.inTeamPreview {
                    TeamPreviewIcons(state: state, unit: unit)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
        .aspectRatio(SceneLayout.width / SceneLayout.height, contentMode: .fit)
    }

    @ViewBuilder
    private func sprite(side: String, slot: Int, isFront: Bool, count: Int, unit: CGFloat) -> some View {
        let place = SceneLayout.placement(isFront: isFront, slot: slot, activeCount: count)
        let ref = SlotRef(side: side, slot: slot)
        if let mon = battle.state.sides[side]?.activePokemon(slot) {
            AnimatedSlotSprite(mon: mon, back: !isFront, scale: place.scale, unit: unit, effects: battle.effects[ref] ?? SlotEffects())
                .position(x: place.center.x * unit, y: place.center.y * unit)
                .id(mon.id)
                .transition(.asymmetric(insertion: .scale(scale: 0.1).combined(with: .opacity), removal: .opacity))
        }
    }

    @ViewBuilder
    private func statbar(side: String, slot: Int, isFront: Bool, count: Int, unit: CGFloat) -> some View {
        let place = SceneLayout.placement(isFront: isFront, slot: slot, activeCount: count)
        let ref = SlotRef(side: side, slot: slot)
        if let mon = battle.state.sides[side]?.activePokemon(slot), !mon.fainted {
            Statbar(mon: mon, isFront: isFront, showExactHP: side == battle.state.perspective && battle.isPlayer)
                .overlay(alignment: .bottom) {
                    ResultBadges(effects: battle.effects[ref] ?? SlotEffects(), banner: battle.abilityBanner?.ref == ref ? battle.abilityBanner : nil)
                        .offset(y: 26)
                }
                .scaleEffect(unit, anchor: .topLeading)
                .offset(x: place.statbar.x * unit, y: place.statbar.y * unit)
                .transition(.opacity)
        }
    }
}

// MARK: - Statbar

/// `.statbar`: name, HP bar with percentage tab, and status/boost tags.
struct Statbar: View {
    var mon: BattlePokemon
    var isFront: Bool
    var showExactHP: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Text(mon.name)
                    .font(PS.font(13, bold: true))
                    .foregroundStyle(Color(hex: 0x222222))
                if let gender = mon.gender {
                    RemoteImage(path: "fx/gender-\(gender.lowercased()).png")
                        .frame(width: 7, height: 10)
                }
                if mon.level != 100 {
                    Text("L\(mon.level)")
                        .font(PS.font(11))
                        .foregroundStyle(Color(hex: 0x222222))
                }
                if let tera = mon.terastallized {
                    RemoteImage(path: "sprites/types/Tera\(tera).png", pixelated: false)
                        .frame(width: 16, height: 16)
                }
            }
            .lineLimit(1)
            .fixedSize()
            .shadow(color: .white, radius: 0, x: 1, y: 1)
            .shadow(color: .white, radius: 0, x: -1, y: -1)
            .shadow(color: .white, radius: 0, x: 1, y: -1)
            .shadow(color: .white, radius: 0, x: -1, y: 1)
            .frame(width: 154)
            .padding(.bottom, 1)

            HPBox(fraction: mon.hpFraction, text: hpText, tabOnLeft: isFront)
            StatusTags(mon: mon)
        }
        .frame(width: 162, alignment: .leading)
        .padding(.vertical, 2)
    }

    private var hpText: String {
        "\(mon.hpPercent)%"
    }
}

/// The 151px HP bar, its three-tone fill, and the gray percentage tab.
private struct HPBox: View {
    var fraction: Double
    var text: String
    var tabOnLeft: Bool

    private var colors: (top: UInt32, fill: UInt32, bottom: UInt32, prev: UInt32) {
        if fraction > 0.5 { return (0x00DD60, 0x00BB51, 0x007734, 0xBBEECC) }
        if fraction > 0.2 { return (0xF8E379, 0xF5D538, 0xBE9F0A, 0xFCF4CA) }
        return (0xF37F67, 0xEE4928, 0xA3260D, 0xFACEC5)
    }

    var body: some View {
        ZStack(alignment: tabOnLeft ? .leading : .trailing) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0xFCFEFF))
                RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: 0x777777), lineWidth: 1)
                VStack(spacing: 0) {
                    Rectangle().fill(Color(hex: colors.top)).frame(height: 2)
                    Rectangle().fill(Color(hex: colors.fill)).frame(height: 4)
                    Rectangle().fill(Color(hex: colors.bottom)).frame(height: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .frame(width: max(fraction > 0 ? 2 : 0, 151 * fraction), height: 8)
                .padding(.leading, 2)
            }
            .frame(width: 155, height: 12)
            .animation(.easeInOut(duration: 0.5), value: fraction)

            Text(text)
                .font(.system(size: 9))
                .foregroundStyle(Color(hex: 0xEEEEEE))
                .shadow(color: .black, radius: 0, y: 1)
                .frame(width: 32, height: 12)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: tabOnLeft ? 4 : 0, bottomLeadingRadius: tabOnLeft ? 4 : 0,
                        bottomTrailingRadius: tabOnLeft ? 0 : 4, topTrailingRadius: tabOnLeft ? 0 : 4
                    )
                    .fill(Color(hex: 0x777777))
                )
                .offset(x: tabOnLeft ? -32 : 32)
                .contentTransition(.numericText())
        }
        .frame(width: 155, height: 12)
    }
}

/// Status, boosts and volatiles (`.statbar .status span`).
private struct StatusTags: View {
    var mon: BattlePokemon

    private static let boostTable: [Int: String] = [1: "1.5", 2: "2", 3: "2.5", 4: "3", 5: "3.5", 6: "4", -1: "0.67", -2: "0.5", -3: "0.4", -4: "0.33", -5: "0.29", -6: "0.25"]
    private static let accuracyTable: [Int: String] = [1: "1.33", 2: "1.67", 3: "2", 4: "2.33", 5: "2.67", 6: "3", -1: "0.75", -2: "0.6", -3: "0.5", -4: "0.43", -5: "0.38", -6: "0.33"]
    private static let statLabels = ["atk": "Atk", "def": "Def", "spa": "SpA", "spd": "SpD", "spe": "Spe", "accuracy": "Accuracy", "evasion": "Evasion"]
    private static let badVolatiles: Set<String> = ["confusion", "Leech Seed", "Taunt", "Encore", "Torment", "Yawn", "Disable", "Embargo", "Heal Block", "Salt Cure", "Curse", "Nightmare", "Perish Song", "perish3", "perish2", "perish1", "perish0", "Syrup Bomb", "Tar Shot"]
    private static let hidden: Set<String> = ["typechange", "Protect", "Detect", "Roost", "Endure"]

    var body: some View {
        FlowTags(tags: tags)
            .frame(width: 162, alignment: .leading)
            .frame(minHeight: 12, alignment: .topLeading)
    }

    private var tags: [(String, Tag.Style)] {
        var out: [(String, Tag.Style)] = []
        if let status = mon.status {
            out.append((status.uppercased(), .status(status)))
        }
        for stat in ["atk", "def", "spa", "spd", "spe", "accuracy", "evasion"] {
            guard let amount = mon.boosts[stat], amount != 0 else { continue }
            let table = stat == "accuracy" || stat == "evasion" ? Self.accuracyTable : Self.boostTable
            out.append(("\(table[amount] ?? "?")×\u{00A0}\(Self.statLabels[stat] ?? stat)", amount > 0 ? .good : .bad))
        }
        for volatile in mon.volatiles where !Self.hidden.contains(volatile) {
            let label = volatile.hasPrefix("perish") ? "Perish next turn" : volatile
            out.append((label, Self.badVolatiles.contains(volatile) ? .bad : .neutral))
        }
        return out
    }
}

struct Tag: View {
    enum Style: Equatable {
        case status(String), good, bad, neutral
    }

    var text: String
    var style: Style

    var body: some View {
        Text(text)
            .font(PS.font(9))
            .foregroundStyle(foreground)
            .padding(.horizontal, style.isStatus ? 2 : 1)
            .padding(.vertical, style.isStatus ? 1 : 0)
            .background(RoundedRectangle(cornerRadius: 3).fill(background))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(border, lineWidth: style.isStatus ? 0 : 1))
    }

    private var foreground: Color {
        switch style {
        case .status: return .white
        case .good: return Color(hex: 0x33AA00)
        case .bad: return Color(hex: 0xFF4400)
        case .neutral: return Color(hex: 0x555555)
        }
    }

    private var background: Color {
        switch style {
        case .status(let s): return PS.statusColor(s)
        case .good: return Color(hex: 0xE5FFE0)
        case .bad: return Color(hex: 0xFFE5E0)
        case .neutral: return Color(hex: 0xF0F0F0)
        }
    }

    private var border: Color {
        switch style {
        case .status: return .clear
        case .good: return Color(hex: 0x33AA00)
        case .bad: return Color(hex: 0xFF4400)
        case .neutral: return Color(hex: 0x555555)
        }
    }
}

private extension Tag.Style {
    var isStatus: Bool {
        if case .status = self { return true }
        return false
    }
}

/// Wraps tags onto multiple lines like inline spans.
struct FlowTags: View {
    var tags: [(String, Tag.Style)]

    var body: some View {
        FlowLayout(spacing: 2, lineSpacing: 1) {
            ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                Tag(text: tag.0, style: tag.1)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Weather and field

/// `.weather` / `.terrain` overlay layers with their background art.
private struct WeatherLayers: View {
    var weather: String?
    var fields: [String]
    var unit: CGFloat

    private static let weatherArt: [String: (UInt32, String)] = [
        "raindance": (0x99BBFF, "fx/weather-raindance.jpg"), "primordialsea": (0x99BBFF, "fx/weather-raindance.jpg"),
        "sunnyday": (0xFFEEBB, "fx/weather-sunnyday.jpg"), "desolateland": (0xFFEEBB, "fx/weather-sunnyday.jpg"),
        "sandstorm": (0xE6E0AC, "fx/weather-sandstorm.png"), "hail": (0xAADDEE, "fx/weather-hail.png"),
        "snow": (0xAADDEE, "fx/weather-hail.png"), "snowscape": (0xAADDEE, "fx/weather-hail.png"),
        "deltastream": (0xAAAAAA, "fx/weather-strongwind.png"),
    ]

    private static let fieldArt: [String: (UInt32, String)] = [
        "mistyterrain": (0xEEAACC, "fx/weather-mistyterrain.png"), "electricterrain": (0xEEEEAA, "fx/weather-electricterrain.png"),
        "grassyterrain": (0xCCEEAA, "fx/weather-grassyterrain.png"), "psychicterrain": (0xCCAAEE, "fx/weather-psychicterrain.png"),
        "gravity": (0xDDAAEE, "fx/weather-gravity.png"), "magicroom": (0xDDAAEE, "fx/weather-magicroom.png"),
        "trickroom": (0xDDAAEE, "fx/weather-trickroom.png"), "wonderroom": (0xDDAAEE, "fx/weather-wonderroom.png"),
    ]

    var body: some View {
        let terrain = fields.reversed().map(toID).first { Self.fieldArt[$0] != nil }
        let weatherID = weather.map(toID)
        let intense = ["desolateland", "primordialsea", "deltastream"].contains(weatherID ?? "")
        ZStack(alignment: .topLeading) {
            if let terrain, let art = Self.fieldArt[terrain] {
                layer(art)
                    .transition(.opacity)
            }
            if let weatherID, let art = Self.weatherArt[weatherID] {
                layer(art)
                    .opacity(intense ? 0.9 : 0.5)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: weather)
        .animation(.easeInOut(duration: 0.4), value: fields)
    }

    private func layer(_ art: (UInt32, String)) -> some View {
        ZStack(alignment: .topLeading) {
            Color(hex: art.0)
            RemoteImage(path: art.1, pixelated: false)
                .frame(width: 640 * unit, height: 360 * unit)
                .offset(x: -SceneLayout.cropX * unit)
        }
    }
}

/// Weather, field effects and screens listed in italics under the turn counter.
private struct FieldText: View {
    var state: BattleState

    private static let timedSideConditions: Set<String> = ["Reflect", "Light Screen", "Aurora Veil", "Tailwind", "Safeguard", "Mist", "Lucky Chant"]

    var body: some View {
        let lines = textLines
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                }
            }
            .font(PS.italic(16))
            .foregroundStyle(.black)
            .shadow(color: .white, radius: 0, x: 1, y: 1)
            .shadow(color: .white, radius: 0, x: -1, y: -1)
            .shadow(color: .white, radius: 0, x: 1, y: -1)
            .shadow(color: .white, radius: 0, x: -1, y: 1)
            .opacity(0.9)
            .fixedSize()
        }
    }

    private var textLines: [String] {
        var out: [String] = []
        if let weather = state.weather { out.append(Self.weatherName(weather)) }
        out += state.fields
        for side in [state.perspective, state.opponentSideID] {
            for condition in state.sides[side]?.conditionOrder ?? [] where Self.timedSideConditions.contains(condition) {
                out.append(side == state.perspective ? condition : "Foe's \(condition)")
            }
        }
        return out
    }

    static func weatherName(_ weather: String) -> String {
        switch toID(weather) {
        case "raindance": return "Rain"
        case "sunnyday": return "Sun"
        case "sandstorm": return "Sandstorm"
        case "hail": return "Hail"
        case "snow", "snowscape": return "Snow"
        case "desolateland": return "Intense Sun"
        case "primordialsea": return "Heavy Rain"
        case "deltastream": return "Strong Winds"
        default: return weather
        }
    }
}

// MARK: - Sprites and effects

private struct LungeMotion {
    var x: CGFloat = 0
    var y: CGFloat = 0
}

private struct HitMotion {
    var x: CGFloat = 0
    var opacity: Double = 1
}

private struct AnimatedSlotSprite: View {
    var mon: BattlePokemon
    var back: Bool
    var scale: CGFloat
    var unit: CGFloat
    var effects: SlotEffects

    var body: some View {
        let toward: CGFloat = back ? 1 : -1
        BattleSprite(species: mon.species, back: back, shiny: mon.shiny, scale: scale, unit: unit)
            .keyframeAnimator(initialValue: LungeMotion(), trigger: effects.lunge) { content, value in
                content.offset(x: value.x * unit, y: value.y * unit)
            } keyframes: { _ in
                KeyframeTrack(\.x) {
                    CubicKeyframe(0, duration: 0.05)
                    CubicKeyframe(40 * toward, duration: 0.2)
                    CubicKeyframe(0, duration: 0.3)
                }
                KeyframeTrack(\.y) {
                    CubicKeyframe(0, duration: 0.05)
                    CubicKeyframe(-25 * toward, duration: 0.2)
                    CubicKeyframe(0, duration: 0.3)
                }
            }
            .keyframeAnimator(initialValue: HitMotion(), trigger: effects.hit) { content, value in
                content.offset(x: value.x * unit).opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.x) {
                    LinearKeyframe(-6, duration: 0.05)
                    LinearKeyframe(6, duration: 0.07)
                    LinearKeyframe(-4, duration: 0.07)
                    LinearKeyframe(0, duration: 0.06)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0.3, duration: 0.07)
                    LinearKeyframe(1, duration: 0.07)
                    LinearKeyframe(0.3, duration: 0.07)
                    LinearKeyframe(1, duration: 0.07)
                }
            }
            .opacity(mon.fainted ? 0 : 1)
            .offset(y: mon.fainted ? 50 * unit : 0)
            .animation(.easeIn(duration: 0.5), value: mon.fainted)
    }
}

/// Floating result pills (`.result`): damage, heals, status, and ability announcements.
private struct ResultBadges: View {
    var effects: SlotEffects
    var banner: AbilityBanner?

    var body: some View {
        VStack(spacing: 2) {
            if let banner {
                Text(banner.ability)
                    .font(PS.font(12, bold: true))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Rectangle().fill(Color(hex: 0x0088AA)))
                    .transition(.opacity)
            }
            ForEach(effects.floating) { item in
                FloatingResult(item: item)
            }
        }
        .frame(width: 162)
    }
}

private struct FloatingResult: View {
    var item: FloatingText
    @State private var risen = false

    var body: some View {
        Text(item.text)
            .font(PS.font(12, bold: true))
            .foregroundStyle(.white)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 3).fill(item.color))
            .offset(y: risen ? -10 : 0)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeIn(duration: 0.5).delay(0.7)) { risen = true }
            }
    }
}

/// Both teams' icons shown in the middle of the field during team preview.
private struct TeamPreviewIcons: View {
    var state: BattleState
    var unit: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let foe = state.opponentSide {
                row(foe.pokemon)
                    .scaleEffect(unit * 1.4, anchor: .topLeading)
                    .offset(x: 190 * unit, y: 110 * unit)
            }
            if let mine = state.mySide {
                row(mine.pokemon)
                    .scaleEffect(unit * 1.4, anchor: .topLeading)
                    .offset(x: 30 * unit, y: 220 * unit)
            }
        }
    }

    private func row(_ team: [BattlePokemon]) -> some View {
        HStack(spacing: -4) {
            ForEach(team) { mon in
                PokemonIcon(species: mon.species, female: mon.gender == "F")
            }
        }
    }
}
