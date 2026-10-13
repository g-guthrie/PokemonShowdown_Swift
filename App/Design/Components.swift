import SwiftUI
import ShowdownKit

struct TypeBadge: View {
    var type: String
    var compact = false

    var body: some View {
        Text(compact ? String(type.prefix(3)).uppercased() : type.uppercased())
            .font(.system(size: compact ? 9 : 10, weight: .heavy, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.typeGradient(type)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
            .shadow(color: Theme.typeColor(type).opacity(0.4), radius: 4, y: 1)
    }
}

struct StatusChip: View {
    var status: String

    var body: some View {
        Text(status.uppercased())
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Theme.statusColor(status)))
    }
}

struct HPBar: View {
    var fraction: Double
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.45))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Theme.hpColor(fraction).opacity(0.85), Theme.hpColor(fraction)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.white.opacity(0.35))
                            .frame(height: max(1, height * 0.3))
                            .padding(.horizontal, 2)
                            .padding(.top, 1)
                    }
                    .frame(width: max(fraction > 0 ? height : 0, proxy.size.width * fraction))
                    .shadow(color: Theme.hpColor(fraction).opacity(0.7), radius: 4)
            }
        }
        .frame(height: height)
        .animation(.easeInOut(duration: 0.6), value: fraction)
    }
}

/// A row of team slots: alive, statused, fainted, unknown.
struct TeamDots: View {
    var side: BattleSide
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(side.teamSize, side.pokemon.count, 1), id: \.self) { index in
                let mon = index < side.pokemon.count ? side.pokemon[index] : nil
                Circle()
                    .fill(color(for: mon))
                    .frame(width: 7, height: 7)
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
            }
        }
    }

    private func color(for mon: BattlePokemon?) -> Color {
        guard let mon else { return .white.opacity(0.85) }
        if mon.fainted { return .white.opacity(0.15) }
        if let status = mon.status { return Theme.statusColor(status) }
        return Theme.hpColor(mon.hpFraction)
    }
}

struct BoostChip: View {
    var stat: String
    var amount: Int

    var body: some View {
        let label = StatSpread.labels[stat] ?? (stat == "accuracy" ? "Acc" : stat == "evasion" ? "Eva" : stat)
        Text("\(amount > 0 ? "+" : "")\(amount) \(label)")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(amount > 0 ? Color(hex: 0x9BE7FF) : Color(hex: 0xFFB199))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill((amount > 0 ? Color(hex: 0x2A8CFF) : Color(hex: 0xFF5A3D)).opacity(0.22)))
    }
}

struct CategoryIcon: View {
    var category: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white.opacity(0.9))
    }

    private var symbol: String {
        switch category {
        case "Physical": return "burst.fill"
        case "Special": return "sparkles"
        default: return "circle.dashed"
        }
    }
}

struct StatBar: View {
    var label: String
    var value: Int
    var maxValue: Int = 255
    var tint: Color = Theme.accent

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 34, alignment: .leading)
            Text("\(value)")
                .font(.caption.monospacedDigit().weight(.bold))
                .frame(width: 34, alignment: .trailing)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * min(1, Double(value) / Double(maxValue)))
                }
            }
            .frame(height: 6)
        }
    }
}

struct EmptyStateView: View {
    var symbol: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.accentGradient)
                .padding(22)
                .background(Circle().fill(.white.opacity(0.06)))
            Text(title)
                .font(.title3.weight(.bold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Haptic tap tied to a changing value, respecting the Settings toggle.
    func hapticFeedback<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View {
        sensoryFeedback(feedback, trigger: trigger) { _, _ in
            UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true
        }
    }
}
