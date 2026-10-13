import SwiftUI
import ShowdownKit

struct BattleView: View {
    var battle: BattleController
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var showLog = false
    @State private var confirmForfeit = false
    @State private var timerOn = false

    var body: some View {
        ZStack {
            BattleBackdrop(weather: battle.state.weather, fields: battle.state.fields)
            VStack(spacing: 10) {
                topBar
                BattleFieldView(battle: battle)
                    .frame(maxHeight: .infinity)
                MessageTicker(text: battle.currentMessage)
                    .onTapGesture { showLog = true }
                    .padding(.horizontal, 14)
                BattleControls(battle: battle)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }
        }
        .sheet(isPresented: $showLog) {
            BattleLogSheet(battle: battle)
        }
        .confirmationDialog("Forfeit this battle?", isPresented: $confirmForfeit, titleVisibility: .visible) {
            Button("Forfeit", role: .destructive) { battle.forfeit() }
        }
        .hapticFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: battle.hitCounter)
        .hapticFeedback(.impact(weight: .light), trigger: battle.state.turn)
        .hapticFeedback(battle.didWin == true ? .success : .warning, trigger: battle.state.ended)
        .hapticFeedback(.selection, trigger: battle.controlsVisible)
        .statusBarHidden()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.headline.weight(.bold))
                    .frame(width: 40, height: 40)
                    .glassCard(cornerRadius: 20)
            }
            .buttonStyle(PressableStyle())

            VStack(alignment: .leading, spacing: 1) {
                Text(battle.formatName)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                Text(battle.state.turn > 0 ? "Turn \(battle.state.turn)" : battle.state.inTeamPreview ? "Team preview" : "Starting…")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.numericText())
            }
            Spacer()
            if let timer = battle.state.timerMessage {
                Label(Self.shortTimer(timer), systemImage: "timer")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .glassCard(cornerRadius: 16, tint: Theme.gold)
                    .lineLimit(1)
            }
            Menu {
                Button {
                    showLog = true
                } label: {
                    Label("Battle log & chat", systemImage: "text.bubble")
                }
                if battle.isPlayer && !battle.state.ended {
                    Button {
                        timerOn.toggle()
                        battle.toggleTimer(on: timerOn)
                    } label: {
                        Label(timerOn ? "Stop timer" : "Start timer", systemImage: "timer")
                    }
                    Button(role: .destructive) {
                        confirmForfeit = true
                    } label: {
                        Label("Forfeit", systemImage: "flag.fill")
                    }
                }
                if battle.state.ended {
                    Button {
                        battle.saveReplay()
                    } label: {
                        Label("Save replay", systemImage: "square.and.arrow.up")
                    }
                }
                Button(role: .destructive) {
                    app.leave(battle)
                } label: {
                    Label("Leave battle", systemImage: "door.left.hand.open")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline.weight(.bold))
                    .frame(width: 40, height: 40)
                    .glassCard(cornerRadius: 20)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }

    /// "Time left: 150 sec this turn | 150 sec total" -> "150s"
    static func shortTimer(_ text: String) -> String {
        let digits = text.split(whereSeparator: { !$0.isNumber }).first
        return digits.map { "\($0)s" } ?? "Timer"
    }
}

// MARK: - Message ticker

struct MessageTicker: View {
    var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.bubble.fill")
                .font(.footnote)
                .foregroundStyle(Theme.accentGradient)
            Text(text.isEmpty ? "The battle is about to begin…" : text)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(text)
                .transition(.push(from: .bottom))
            Image(systemName: "chevron.up")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 52)
        .clipped()
        .glassCard(cornerRadius: 20)
        .contentShape(Rectangle())
    }
}

// MARK: - Backdrop

struct BattleBackdrop: View {
    var weather: String?
    var fields: [String]

    var body: some View {
        let tint = Theme.weatherTint(weather) ?? Theme.terrainTint(fields)
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0B0E24), Color(hex: 0x1A1440), Color(hex: 0x0A0B18)],
                startPoint: .top,
                endPoint: .bottom
            )
            if let tint {
                RadialGradient(colors: [tint.opacity(0.45), .clear], center: .top, startRadius: 10, endRadius: 520)
                    .transition(.opacity)
            }
            RadialGradient(colors: [Theme.accent.opacity(0.35), .clear], center: UnitPoint(x: 0.75, y: 0.3), startRadius: 0, endRadius: 260)
            RadialGradient(colors: [Theme.accentPink.opacity(0.25), .clear], center: UnitPoint(x: 0.2, y: 0.55), startRadius: 0, endRadius: 280)
            if let weather {
                WeatherParticles(weather: weather)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1), value: weather)
        .animation(.easeInOut(duration: 1), value: fields)
        .ignoresSafeArea()
    }
}

struct WeatherParticles: View {
    var weather: String

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                draw(in: &context, size: size, time: t)
            }
        }
        .allowsHitTesting(false)
    }

    /// Stable pseudo-random value in 0..<1 for a particle seed.
    private func noise(_ seed: Double) -> Double {
        let value = sin(seed) * 43758.5453
        return value - floor(value)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time t: Double) {
        let width = Double(size.width)
        let height = Double(size.height)
        switch weather {
        case "RainDance", "PrimordialSea":
            for i in 0..<90 {
                let seed = Double(i) * 12.9898
                let x: Double = noise(seed) * (width + 80) - 40
                let speed: Double = 500 + noise(seed * 2) * 300
                let travel: Double = noise(seed * 3) * height + t * speed
                let y: Double = travel.truncatingRemainder(dividingBy: height + 40) - 20
                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x - 6, y: y + 18))
                context.stroke(path, with: .color(.white.opacity(0.28)), lineWidth: 1.2)
            }
        case "Hail", "Snow", "Snowscape":
            for i in 0..<70 {
                let seed = Double(i) * 78.233
                let speed: Double = 30 + noise(seed) * 40
                let travel: Double = noise(seed * 5) * height + t * speed
                let y: Double = travel.truncatingRemainder(dividingBy: height + 20) - 10
                let sway: Double = sin(t + seed) * 12
                let x: Double = noise(seed * 7) * width + sway
                let r: Double = 1.5 + noise(seed * 11) * 2.5
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(0.6)))
            }
        case "Sandstorm":
            for i in 0..<60 {
                let seed = Double(i) * 33.71
                let speed: Double = 350 + noise(seed) * 250
                let travel: Double = noise(seed * 2) * width + t * speed
                let x: Double = travel.truncatingRemainder(dividingBy: width + 60) - 30
                let y: Double = noise(seed * 3) * height
                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + 26, y: y + 3))
                context.stroke(path, with: .color(Color(hex: 0xE8C27A).opacity(0.35)), lineWidth: 1.5)
            }
        case "SunnyDay", "DesolateLand":
            let center = CGPoint(x: width * 0.85, y: -20)
            for i in 0..<10 {
                let angle: Double = Double(i) / 10 * Double.pi + Double.pi / 2 + sin(t * 0.3) * 0.08
                let end = CGPoint(x: Double(center.x) + cos(angle) * 900, y: Double(center.y) + sin(angle) * 900)
                var path = Path()
                path.move(to: center)
                path.addLine(to: end)
                context.stroke(path, with: .color(Color(hex: 0xFFD27A).opacity(0.07)), lineWidth: 26)
            }
        default:
            break
        }
    }
}
