import SwiftUI

/// Frosted card surface. Uses Liquid Glass on iOS 26 and a material fallback before that.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 24
    var tint: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private var glass: Glass {
        if let tint { return .regular.tint(tint.opacity(0.35)) }
        return .regular
    }
    #endif

    private func fallback(_ content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        if let tint {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(tint.opacity(0.18))
                        }
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            }
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 24, tint: Color? = nil) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, tint: tint))
    }
}

/// The big call-to-action button.
struct GlowButtonStyle: ButtonStyle {
    var gradient: LinearGradient = Theme.accentGradient
    var glow: Color = Theme.accentPink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background {
                Capsule(style: .continuous)
                    .fill(gradient)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
                            .padding(1.5)
                            .blendMode(.plusLighter)
                    }
                    .shadow(color: glow.opacity(configuration.isPressed ? 0.25 : 0.55), radius: configuration.isPressed ? 8 : 22, y: 8)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Small secondary pill button.
struct PillButtonStyle: ButtonStyle {
    var tint: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(tint.opacity(configuration.isPressed ? 0.22 : 0.12)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Press feedback for custom tappable cards.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
