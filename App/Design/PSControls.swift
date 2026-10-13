import SwiftUI
import ShowdownKit

// MARK: - Buttons

/// Showdown's standard `.button`: light gray gradient, 1px #AAA border, 5px corners.
struct PSButtonStyle: ButtonStyle {
    enum Size { case small, normal, big }
    var size: Size = .normal
    var selected = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let fill: LinearGradient = {
            if !isEnabled { return LinearGradient(colors: [Color(hex: 0xEEEEEE)], startPoint: .top, endPoint: .bottom) }
            if selected { return LinearGradient(colors: [Color(hex: 0xF8F8F8)], startPoint: .top, endPoint: .bottom) }
            if pressed { return LinearGradient(colors: [Color(hex: 0xBFBFBF), Color(hex: 0xF2F2F2)], startPoint: .top, endPoint: .bottom) }
            return LinearGradient(colors: [Color(hex: 0xF6F6F6), Color(hex: 0xE3E3E3)], startPoint: .top, endPoint: .bottom)
        }()
        configuration.label
            .font(PS.font(fontSize))
            .foregroundStyle(isEnabled ? (selected ? Color(hex: 0x444444) : PS.text) : Color(hex: 0x999999))
            .padding(.horizontal, padding.width)
            .padding(.vertical, padding.height)
            .background(RoundedRectangle(cornerRadius: 5).fill(fill))
            .overlay(alignment: .bottom) {
                if isEnabled && !pressed {
                    RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.9), lineWidth: 1).padding(1).mask(alignment: .bottom) { Rectangle().frame(height: 4) }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(isEnabled ? (pressed ? Color(hex: 0x606060) : PS.border) : Color(hex: 0xCCCCCC), lineWidth: 1))
            .shadow(color: .black.opacity(isEnabled ? 0.2 : 0.1), radius: 1, y: 1)
            .contentShape(Rectangle())
    }

    private var fontSize: CGFloat {
        switch size {
        case .small: return 11
        case .normal: return 13
        case .big: return 16
        }
    }

    private var padding: CGSize {
        switch size {
        case .small: return CGSize(width: 6, height: 3)
        case .normal: return CGSize(width: 9, height: 5)
        case .big: return CGSize(width: 12, height: 7)
        }
    }
}

/// The colored main-menu buttons; colors are derived from the wallpaper's hues.
struct MenuButtonStyle: ButtonStyle {
    var hue: Double
    var saturation: Double
    var big = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let top = Color(hue: hue, saturation: saturation, lightness: pressed ? 0.42 : 0.72)
        let bottom = Color(hue: hue, saturation: saturation, lightness: pressed ? 0.58 : 0.52)
        configuration.label
            .font(PS.font(big ? 19 : 16))
            .multilineTextAlignment(.center)
            .foregroundStyle(isEnabled ? .white : Color(hex: 0x999999))
            .shadow(color: isEnabled ? Color(hue: 210, saturation: 0.4, lightness: 0.1) : .clear, radius: 0, y: -1)
            .frame(maxWidth: big ? 290 : 260)
            .frame(height: big ? 62 : 38)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isEnabled ? AnyShapeStyle(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color(hex: 0xEEEEEE)))
            )
            .overlay(alignment: .top) {
                if isEnabled && !pressed {
                    RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.8), lineWidth: 1).padding(1).mask(alignment: .top) { Rectangle().frame(height: 3) }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(isEnabled ? Color(hue: hue, saturation: saturation, lightness: pressed ? 0.21 : 0.40) : Color(hex: 0xCCCCCC), lineWidth: 1))
            .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
            .contentShape(Rectangle())
    }
}

/// Move buttons in battle, tinted per type as in `sim-types.css`.
struct MoveButtonStyle: ButtonStyle {
    var type: String
    var disabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let (hue, sat) = PS.typeHS[type] ?? (0, 0)
        let pressed = configuration.isPressed
        let gradient: LinearGradient
        let border: Color
        if disabled {
            gradient = LinearGradient(colors: [Color(hex: 0xF3F3F3)], startPoint: .top, endPoint: .bottom)
            border = Color(hex: 0xCCCCCC)
        } else if pressed {
            gradient = LinearGradient(colors: [Color(hue: hue, saturation: sat, lightness: 0.77), Color(hue: hue, saturation: sat, lightness: 0.83)], startPoint: .top, endPoint: .bottom)
            border = Color(hue: hue, saturation: sat, lightness: 0.41)
        } else {
            gradient = LinearGradient(colors: [Color(hue: hue, saturation: sat, lightness: 0.97), Color(hue: hue, saturation: sat, lightness: 0.84)], startPoint: .top, endPoint: .bottom)
            border = Color(hue: hue, saturation: sat, lightness: 0.70)
        }
        return configuration.label
            .background(RoundedRectangle(cornerRadius: 5).fill(gradient))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(border, lineWidth: 1))
            .shadow(color: .black.opacity(disabled ? 0 : 0.2), radius: 1, y: 1)
            .opacity(disabled ? 0.75 : 1)
            .contentShape(Rectangle())
    }
}

/// Pokemon buttons in the switch menu (plain gray `.switchmenu button`).
struct SwitchButtonStyle: ButtonStyle {
    var disabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .background(
                RoundedRectangle(cornerRadius: 5).fill(
                    disabled ? LinearGradient(colors: [Color(hex: 0xF3F3F3)], startPoint: .top, endPoint: .bottom)
                        : pressed ? LinearGradient(colors: [Color(hex: 0xCFCFCF), Color(hex: 0xF2F2F2)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color(hex: 0xF6F6F6), Color(hex: 0xE3E3E3)], startPoint: .top, endPoint: .bottom)
                )
            )
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(disabled ? Color(hex: 0xCCCCCC) : (pressed ? Color(hex: 0x606060) : PS.border), lineWidth: 1))
            .shadow(color: .black.opacity(disabled ? 0 : 0.2), radius: 1, y: 1)
            .opacity(disabled ? 0.75 : 1)
            .contentShape(Rectangle())
    }
}

// MARK: - Select boxes

/// Showdown's `.select`: a dropdown-looking button with a caret.
struct PSSelect<Content: View>: View {
    var action: () -> Void
    var disabled = false
    @ViewBuilder var content: Content

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                FAIcon(.caretDown, size: 15)
                    .foregroundStyle(disabled ? Color(hex: 0xAAAAAA) : Color(hex: 0x777777))
            }
            .font(PS.font(13))
            .foregroundStyle(disabled ? Color(hex: 0x555555) : .black)
            .padding(.leading, 9)
            .padding(.trailing, 8)
            .padding(.vertical, 5)
            .frame(minHeight: 36)
        }
        .buttonStyle(SelectStyle(disabled: disabled))
        .disabled(disabled)
    }

    private struct SelectStyle: ButtonStyle {
        var disabled: Bool
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 4).fill(
                        disabled ? LinearGradient(colors: [Color(red: 220 / 255, green: 220 / 255, blue: 220 / 255, opacity: 0.65)], startPoint: .top, endPoint: .bottom)
                            : configuration.isPressed ? LinearGradient(colors: [Color(hex: 0xD1DCE6), Color(hex: 0xE7EDF2)], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color(hex: 0xF6F6F6), Color(hex: 0xE3E3E3)], startPoint: .top, endPoint: .bottom)
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(disabled ? Color(hex: 0x999999) : Color(hex: 0x888888), lineWidth: 1))
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Text boxes

struct PSTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(PS.font(14))
            .foregroundStyle(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xF8FBFD)))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(PS.border, lineWidth: 1))
            .shadow(color: .white.opacity(0.6), radius: 0, x: 1, y: 1)
    }
}

extension View {
    func psTextBox() -> some View {
        self
            .font(PS.font(14))
            .foregroundStyle(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xF8FBFD)))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(PS.border, lineWidth: 1))
    }
}

// MARK: - Containers

/// `.menugroup`: translucent dark rounded panel on the home screen.
struct MenuGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 10) { content }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 20).fill(.black.opacity(0.2)))
            .foregroundStyle(.white)
            .shadow(color: .black, radius: 0, y: 1)
    }
}

/// Bold label above form controls (`.label`).
struct PSLabel: View {
    var text: String
    var onDark = false

    var body: some View {
        Text(text)
            .font(PS.font(12, bold: true))
            .foregroundStyle(onDark ? .white : .black)
            .shadow(color: onDark ? .black : .clear, radius: 0, y: 1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A checkbox row, as in "Don't allow spectators".
struct PSCheckbox: View {
    var title: String
    @Binding var isOn: Bool
    var onDark = false

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(.white)
                    RoundedRectangle(cornerRadius: 3).strokeBorder(Color(hex: 0x767676), lineWidth: 1)
                    if isOn { FAIcon(.check, size: 11).foregroundStyle(Color(hex: 0x0075FF)) }
                }
                .frame(width: 16, height: 16)
                Text(title)
                    .font(PS.font(13))
                    .foregroundStyle(onDark ? .white : .black)
                    .shadow(color: onDark ? .black : .clear, radius: 0, y: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

/// `.ps-popup`: the pale blue-gray floating panel.
struct PSPopupBox<Content: View>: View {
    var maxWidth: CGFloat = 340
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(PS.popup))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white, lineWidth: 1).padding(1).opacity(0.8))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(PS.popupBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 0, x: 2, y: 2)
            .foregroundStyle(.black)
    }
}

/// Section header used in popup menus (`.popupmenu h3`).
struct PopupHeader: View {
    var text: String

    var body: some View {
        Text(text)
            .font(PS.font(11, bold: true))
            .foregroundStyle(Color(hex: 0x557799))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
            .padding(.bottom, 1)
    }
}

/// HP bar used in switch buttons and team lists: a 2px colored line.
struct MiniHPBar: View {
    var fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xEEEEEE))
                RoundedRectangle(cornerRadius: 2).strokeBorder(Color(hex: 0xAAAAAA), lineWidth: 1)
                Rectangle()
                    .fill(color)
                    .frame(width: max(1, (proxy.size.width - 2) * fraction), height: 2)
                    .padding(.leading, 1)
            }
        }
        .frame(height: 4)
        .opacity(0.8)
    }

    private var color: Color {
        if fraction > 0.5 { return Color(hex: 0x00BB51) }
        if fraction > 0.2 { return Color(hex: 0xA2A822) }
        return Color(hex: 0xFF5555)
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
