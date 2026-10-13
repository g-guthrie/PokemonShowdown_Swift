import SwiftUI
import ShowdownKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Theme {
    static let background = Color(hex: 0x07080F)
    static let surface = Color(hex: 0x12152A)
    static let accent = Color(hex: 0x7C6CFF)
    static let accentPink = Color(hex: 0xFF4F9A)
    static let accentCyan = Color(hex: 0x3FD8FF)
    static let gold = Color(hex: 0xFFC94D)
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.4)

    static let accentGradient = LinearGradient(
        colors: [accent, accentPink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let typeColors: [String: UInt32] = [
        "Normal": 0x9FA19F, "Fire": 0xF57D31, "Water": 0x4D90FF, "Electric": 0xF7CB34,
        "Grass": 0x3FB950, "Ice": 0x5FD4E8, "Fighting": 0xE0443E, "Poison": 0xA650D8,
        "Ground": 0xC9925A, "Flying": 0x86A9F0, "Psychic": 0xF8508A, "Bug": 0x9DB51F,
        "Rock": 0xB8A86A, "Ghost": 0x7158A8, "Dragon": 0x5B5CF0, "Dark": 0x5A4F57,
        "Steel": 0x6AA6BF, "Fairy": 0xF27FD6, "Stellar": 0x45C7C0, "???": 0x6E8A86,
    ]

    static func typeColor(_ type: String) -> Color {
        Color(hex: typeColors[type] ?? 0x8890A0)
    }

    static func typeGradient(_ type: String) -> LinearGradient {
        let base = typeColor(type)
        return LinearGradient(colors: [base.opacity(0.95), base.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func statusColor(_ status: String) -> Color {
        switch status {
        case "brn": return Color(hex: 0xFF7A3D)
        case "par": return Color(hex: 0xF5C518)
        case "slp": return Color(hex: 0x9AA3B5)
        case "frz": return Color(hex: 0x6FD3F2)
        case "psn", "tox": return Color(hex: 0xB45CE6)
        default: return .gray
        }
    }

    static func hpColor(_ fraction: Double) -> Color {
        if fraction > 0.5 { return Color(hex: 0x3EE07F) }
        if fraction > 0.2 { return Color(hex: 0xFFC53D) }
        return Color(hex: 0xFF4D5E)
    }

    static func weatherSymbol(_ weather: String) -> String {
        switch weather {
        case "RainDance", "PrimordialSea": return "cloud.rain.fill"
        case "SunnyDay", "DesolateLand": return "sun.max.fill"
        case "Sandstorm": return "wind"
        case "Hail", "Snow", "Snowscape": return "snowflake"
        case "DeltaStream": return "tornado"
        default: return "cloud.fill"
        }
    }

    static func weatherTint(_ weather: String?) -> Color? {
        switch weather {
        case "RainDance", "PrimordialSea": return Color(hex: 0x2F6BFF)
        case "SunnyDay", "DesolateLand": return Color(hex: 0xFF9A2E)
        case "Sandstorm": return Color(hex: 0xC9A15A)
        case "Hail", "Snow", "Snowscape": return Color(hex: 0x9FE6FF)
        default: return nil
        }
    }

    static func terrainTint(_ fields: [String]) -> Color? {
        if fields.contains("Electric Terrain") { return Color(hex: 0xF7D23A) }
        if fields.contains("Grassy Terrain") { return Color(hex: 0x43C463) }
        if fields.contains("Psychic Terrain") { return Color(hex: 0xE45CE6) }
        if fields.contains("Misty Terrain") { return Color(hex: 0xF7A8E0) }
        return nil
    }
}

/// Slowly drifting color fields behind every screen.
struct AuroraBackground: View {
    var colors: [Color] = [Theme.accent, Theme.accentPink, Theme.accentCyan]
    var intensity: Double = 0.55

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Theme.background
                    ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                        let offset = blobOffset(index: index, time: t, size: size)
                        Circle()
                            .fill(color.opacity(intensity))
                            .frame(width: size.width * 0.95, height: size.width * 0.95)
                            .offset(x: offset.width, y: offset.height)
                            .blur(radius: 90)
                    }
                    LinearGradient(colors: [.clear, Theme.background.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func blobOffset(index: Int, time: Double, size: CGSize) -> CGSize {
        let i = Double(index)
        let phase: Double = time / (9 + i * 3) + i * 2.1
        let width = Double(size.width)
        let height = Double(size.height)
        let x: Double = cos(phase) * width * 0.35
        let y: Double = sin(phase * 1.3) * height * 0.28 - height * 0.18 + i * height * 0.16
        return CGSize(width: x, height: y)
    }
}

struct SectionHeader: View {
    var title: String
    var symbol: String?

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
            }
            Text(title.uppercased())
                .font(.caption.weight(.heavy))
                .tracking(1.2)
            Spacer()
        }
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 4)
    }
}
