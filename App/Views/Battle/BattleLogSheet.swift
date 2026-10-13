import SwiftUI
import ShowdownKit

struct BattleLogSheet: View {
    var battle: BattleController
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var showMinor = false

    private var entries: [BattleLogEntry] {
        showMinor ? battle.state.log : battle.state.log.filter { $0.kind != .minor }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(entries) { entry in
                            LogRow(entry: entry, perspective: battle.state.perspective)
                                .id(entry.id)
                        }
                    }
                    .padding(16)
                }
                .onAppear {
                    if let last = entries.last { reader.scrollTo(last.id, anchor: .bottom) }
                }
                .onChange(of: battle.state.log.count) { _, _ in
                    if let last = entries.last {
                        withAnimation { reader.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    TextField("Message", text: $message)
                        .submitLabel(.send)
                        .onSubmit(send)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .glassCard(cornerRadius: 22)
                    Button(action: send) {
                        Image(systemName: "arrow.up")
                            .font(.headline.weight(.bold))
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Theme.accentGradient))
                    }
                    .disabled(message.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
            .background(Theme.background)
            .navigationTitle("Battle log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Toggle(isOn: $showMinor) {
                        Image(systemName: "list.bullet.indent")
                    }
                    .toggleStyle(.button)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.background)
    }

    private func send() {
        battle.sendChat(message)
        message = ""
    }
}

private struct LogRow: View {
    var entry: BattleLogEntry
    var perspective: String

    var body: some View {
        switch entry.kind {
        case .turn:
            HStack {
                Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
                Text(entry.text.uppercased())
                    .font(.caption.weight(.black))
                    .tracking(1.5)
                    .foregroundStyle(Theme.accentGradient)
                Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
            }
            .padding(.vertical, 8)
        case .action:
            Text(entry.text)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(entry.side == perspective ? Color(hex: 0xB9B2FF) : Color(hex: 0xFFB0CF))
        case .effect:
            Text(entry.text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
        case .minor:
            Text(entry.text)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        case .chat:
            HStack(alignment: .top, spacing: 6) {
                Text(entry.author ?? "")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Theme.accentCyan)
                Text(entry.text)
                    .font(.subheadline)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.07)))
        case .system:
            Text(entry.text)
                .font(.footnote.italic())
                .foregroundStyle(Theme.textSecondary)
        case .error:
            Text(entry.text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(hex: 0xFF8A8A))
        case .result:
            Text(entry.text)
                .font(.title3.weight(.heavy))
                .foregroundStyle(Theme.gold)
                .padding(.vertical, 6)
        }
    }
}
