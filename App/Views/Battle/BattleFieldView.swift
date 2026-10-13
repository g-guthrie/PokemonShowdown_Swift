import SwiftUI
import ShowdownKit

struct BattleFieldView: View {
    var battle: BattleController

    var body: some View {
        let state = battle.state
        let count = state.activesPerSide
        let foeID = state.opponentSideID
        let myID = state.perspective

        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                ForEach(0..<count, id: \.self) { slot in
                    Platform(width: size.width * (count > 1 ? 0.3 : 0.44))
                        .position(foePoint(slot, count: count, size: size))
                    Platform(width: size.width * (count > 1 ? 0.36 : 0.56))
                        .position(myPoint(slot, count: count, size: size))
                }

                ForEach(0..<count, id: \.self) { slot in
                    spriteAnchor(side: foeID, slot: slot, back: false, scale: count > 1 ? 1.15 : 1.45)
                        .position(foePoint(slot, count: count, size: size))
                }
                ForEach(0..<count, id: \.self) { slot in
                    spriteAnchor(side: myID, slot: slot, back: true, scale: count > 1 ? 1.45 : 1.85)
                        .position(myPoint(slot, count: count, size: size))
                }

                VStack(alignment: .leading, spacing: 6) {
                    if let side = state.opponentSide {
                        TrainerTag(side: side)
                        ForEach(0..<count, id: \.self) { slot in
                            if let mon = side.activePokemon(slot) {
                                BattleInfoCard(mon: mon, isMine: false, compact: count > 1, gen: state.gen)
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                            }
                        }
                        SideConditions(side: side)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 14)
                .padding(.top, 4)

                VStack(alignment: .trailing, spacing: 6) {
                    if let side = state.mySide {
                        SideConditions(side: side)
                        ForEach(0..<count, id: \.self) { slot in
                            if let mon = side.activePokemon(slot) {
                                BattleInfoCard(mon: mon, isMine: true, compact: count > 1, gen: state.gen)
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                        TrainerTag(side: side)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.horizontal, 14)
                .padding(.bottom, 2)

                FieldChips(weather: state.weather, fields: state.fields)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 14)
                    .padding(.top, 6)

                if let banner = battle.abilityBanner {
                    AbilityBannerView(banner: banner)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: banner.ref.side == myID ? .leading : .trailing)
                        .padding(.horizontal, 10)
                        .offset(y: banner.ref.side == myID ? size.height * 0.12 : -size.height * 0.05)
                        .transition(.move(edge: banner.ref.side == myID ? .leading : .trailing).combined(with: .opacity))
                }
            }
        }
    }

    @ViewBuilder
    private func spriteAnchor(side: String, slot: Int, back: Bool, scale: CGFloat) -> some View {
        let ref = SlotRef(side: side, slot: slot)
        Color.clear
            .frame(width: 1, height: 1)
            .overlay(alignment: .bottom) {
                if let mon = battle.state.sides[side]?.activePokemon(slot) {
                    SlotSprite(
                        mon: mon,
                        back: back,
                        scale: scale,
                        effects: battle.effects[ref] ?? SlotEffects()
                    )
                    .id(mon.id)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.05, anchor: .bottom).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.6, anchor: .bottom))
                    ))
                    .offset(y: 10)
                }
            }
    }

    private func foePoint(_ slot: Int, count: Int, size: CGSize) -> CGPoint {
        if count == 1 { return CGPoint(x: size.width * 0.7, y: size.height * 0.46) }
        let xs: [CGFloat] = [0.82, 0.56, 0.3]
        return CGPoint(x: size.width * xs[min(slot, 2)], y: size.height * (0.44 - CGFloat(slot) * 0.03))
    }

    private func myPoint(_ slot: Int, count: Int, size: CGSize) -> CGPoint {
        if count == 1 { return CGPoint(x: size.width * 0.29, y: size.height * 0.9) }
        let xs: [CGFloat] = [0.2, 0.5, 0.78]
        return CGPoint(x: size.width * xs[min(slot, 2)], y: size.height * (0.9 + CGFloat(slot) * 0.02))
    }
}

private struct Platform: View {
    var width: CGFloat

    var body: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.04), .clear], center: .center, startRadius: 0, endRadius: width / 2))
            Ellipse()
                .strokeBorder(LinearGradient(colors: [Theme.accentCyan.opacity(0.5), Theme.accentPink.opacity(0.35)], startPoint: .leading, endPoint: .trailing), lineWidth: 1.2)
                .padding(width * 0.08)
        }
        .frame(width: width, height: width * 0.26)
    }
}

// MARK: - Sprite with effects

private struct LungeMotion {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var scale: CGFloat = 1
}

private struct HitMotion {
    var shake: CGFloat = 0
    var opacity: Double = 1
}

private struct GlowMotion {
    var amount: Double = 0
}

struct SlotSprite: View {
    var mon: BattlePokemon
    var back: Bool
    var scale: CGFloat
    var effects: SlotEffects

    var body: some View {
        let direction: CGFloat = back ? 1 : -1
        BattleSprite(species: mon.species, back: back, shiny: mon.shiny, scale: scale)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 6)
            .keyframeAnimator(initialValue: LungeMotion(), trigger: effects.lunge) { content, value in
                content
                    .offset(x: value.x, y: value.y)
                    .scaleEffect(value.scale, anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack(\.x) {
                    SpringKeyframe(-8 * direction, duration: 0.12)
                    SpringKeyframe(34 * direction, duration: 0.16)
                    SpringKeyframe(0, duration: 0.4)
                }
                KeyframeTrack(\.y) {
                    SpringKeyframe(4 * direction, duration: 0.12)
                    SpringKeyframe(-18 * direction, duration: 0.16)
                    SpringKeyframe(0, duration: 0.4)
                }
                KeyframeTrack(\.scale) {
                    CubicKeyframe(0.96, duration: 0.12)
                    CubicKeyframe(1.08, duration: 0.16)
                    CubicKeyframe(1, duration: 0.4)
                }
            }
            .keyframeAnimator(initialValue: HitMotion(), trigger: effects.hit) { content, value in
                content
                    .offset(x: value.shake)
                    .opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.shake) {
                    LinearKeyframe(-11, duration: 0.05)
                    LinearKeyframe(10, duration: 0.06)
                    LinearKeyframe(-7, duration: 0.06)
                    LinearKeyframe(5, duration: 0.06)
                    LinearKeyframe(-2, duration: 0.05)
                    LinearKeyframe(0, duration: 0.05)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0.15, duration: 0.06)
                    LinearKeyframe(1, duration: 0.07)
                    LinearKeyframe(0.15, duration: 0.07)
                    LinearKeyframe(1, duration: 0.1)
                }
            }
            .keyframeAnimator(initialValue: GlowMotion(), trigger: effects.heal) { content, value in
                content.shadow(color: Color(hex: 0x5BE38A).opacity(value.amount), radius: 18)
            } keyframes: { _ in
                KeyframeTrack(\.amount) {
                    LinearKeyframe(0.95, duration: 0.2)
                    LinearKeyframe(0, duration: 0.6)
                }
            }
            .keyframeAnimator(initialValue: GlowMotion(), trigger: effects.tera) { content, value in
                content
                    .brightness(value.amount * 0.5)
                    .shadow(color: Theme.accentCyan.opacity(value.amount), radius: 30)
                    .scaleEffect(1 + value.amount * 0.12, anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack(\.amount) {
                    CubicKeyframe(1, duration: 0.35)
                    CubicKeyframe(0.6, duration: 0.25)
                    CubicKeyframe(0, duration: 0.5)
                }
            }
            .overlay(alignment: .top) {
                VStack(spacing: 2) {
                    ForEach(effects.floating) { item in
                        FloatingLabel(item: item)
                    }
                }
                .offset(y: -18)
            }
            .opacity(mon.fainted ? 0 : 1)
            .offset(y: mon.fainted ? 40 : 0)
            .animation(.easeIn(duration: 0.55), value: mon.fainted)
            .saturation(mon.terastallized != nil ? 1.25 : 1)
    }
}

private struct FloatingLabel: View {
    var item: FloatingText
    @State private var shown = false
    @State private var faded = false

    var body: some View {
        Text(item.text)
            .font(.system(size: 17, weight: .black, design: .rounded))
            .foregroundStyle(item.color)
            .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
            .scaleEffect(shown ? 1 : 0.4)
            .offset(y: shown ? -14 : 8)
            .opacity(faded ? 0 : 1)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { shown = true }
                withAnimation(.easeIn(duration: 0.35).delay(0.85)) { faded = true }
            }
    }
}

// MARK: - Info card

struct BattleInfoCard: View {
    var mon: BattlePokemon
    var isMine: Bool
    var compact: Bool
    var gen: Int
    @Environment(DexStore.self) private var dex

    private var types: [String] {
        if let tera = mon.terastallized, tera != "Stellar" { return [tera] }
        return dex.data.species(named: mon.species)?.types ?? []
    }

    private static let hiddenVolatiles: Set<String> = ["typechange", "Protect", "Roost", "Endure", "Detect"]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(mon.name)
                    .font(.system(size: compact ? 13 : 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let gender = mon.gender {
                    Text(gender == "M" ? "♂" : "♀")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(gender == "M" ? Color(hex: 0x6CB4FF) : Color(hex: 0xFF7EB9))
                }
                Spacer(minLength: 4)
                if let tera = mon.terastallized {
                    Image(systemName: "diamond.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.typeColor(tera))
                        .shadow(color: Theme.typeColor(tera), radius: 4)
                }
                Text("Lv\(mon.level)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            HPBar(fraction: mon.hpFraction, height: compact ? 6 : 8)
            HStack(spacing: 4) {
                if let status = mon.status {
                    StatusChip(status: status)
                }
                if !compact {
                    ForEach(types, id: \.self) { type in
                        TypeBadge(type: type, compact: true)
                    }
                }
                Spacer(minLength: 0)
                Text(isMine ? "\(mon.hp)/\(mon.maxHP)" : "\(mon.hpPercent)%")
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.numericText(value: Double(mon.hp)))
                    .animation(.easeOut(duration: 0.5), value: mon.hp)
            }
            let boosts = StatSpread.keys.dropFirst().map { $0 } + ["accuracy", "evasion"]
            let active = boosts.filter { (mon.boosts[$0] ?? 0) != 0 }
            let volatiles = mon.volatiles.filter { !Self.hiddenVolatiles.contains($0) }.prefix(2)
            if !active.isEmpty || !volatiles.isEmpty {
                HStack(spacing: 3) {
                    ForEach(active, id: \.self) { stat in
                        BoostChip(stat: stat, amount: mon.boosts[stat] ?? 0)
                    }
                    ForEach(Array(volatiles), id: \.self) { effect in
                        Text(effect)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.white.opacity(0.12)))
                    }
                }
                .lineLimit(1)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(width: compact ? 158 : 196)
        .glassCard(cornerRadius: 16, tint: isMine ? Theme.accent : nil)
    }
}

private struct TrainerTag: View {
    var side: BattleSide

    var body: some View {
        HStack(spacing: 6) {
            TrainerAvatar(avatar: side.avatar, name: side.name.isEmpty ? "?" : side.name, size: 20)
            Text(side.name)
                .font(.caption.weight(.bold))
                .lineLimit(1)
            if !side.rating.isEmpty {
                Text(side.rating)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            TeamDots(side: side)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(.black.opacity(0.25)))
    }
}

private struct SideConditions: View {
    var side: BattleSide

    var body: some View {
        if !side.conditionOrder.isEmpty {
            HStack(spacing: 4) {
                ForEach(side.conditionOrder, id: \.self) { name in
                    let layers = side.conditions[name] ?? 1
                    Text(layers > 1 ? "\(name) ×\(layers)" : name)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.gold.opacity(0.2)))
                        .foregroundStyle(Theme.gold)
                }
            }
        }
    }
}

private struct FieldChips: View {
    var weather: String?
    var fields: [String]

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let weather {
                Label(BattleText.weatherName(weather), systemImage: Theme.weatherSymbol(weather))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassCard(cornerRadius: 12, tint: Theme.weatherTint(weather))
            }
            ForEach(fields, id: \.self) { field in
                Text(field)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassCard(cornerRadius: 12, tint: Theme.terrainTint([field]))
            }
        }
    }
}

private struct AbilityBannerView: View {
    var banner: AbilityBanner

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(banner.pokemon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Text(banner.ability)
                .font(.subheadline.weight(.heavy))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 14, tint: Theme.accentPink)
        .shadow(color: Theme.accentPink.opacity(0.4), radius: 12)
    }
}
