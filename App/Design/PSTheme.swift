import SwiftUI
import ShowdownKit

// Visual language of play.pokemonshowdown.com, translated to points.
// CSS sizes: 9pt = 12, 10pt = 13, 11pt = 15, 12pt = 16, 14pt = 19.

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

    /// CSS `hsl(h, s%, l%)`.
    init(hue: Double, saturation: Double, lightness: Double, opacity: Double = 1) {
        let c = (1 - abs(2 * lightness - 1)) * saturation
        let hp = (hue.truncatingRemainder(dividingBy: 360)) / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        var rgb: (Double, Double, Double)
        switch hp {
        case 0..<1: rgb = (c, x, 0)
        case 1..<2: rgb = (x, c, 0)
        case 2..<3: rgb = (0, c, x)
        case 3..<4: rgb = (0, x, c)
        case 4..<5: rgb = (x, 0, c)
        default: rgb = (c, 0, x)
        }
        let m = lightness - c / 2
        self.init(.sRGB, red: rgb.0 + m, green: rgb.1 + m, blue: rgb.2 + m, opacity: opacity)
    }
}

enum PS {
    static let resource = "https://play.pokemonshowdown.com/"

    // Text
    static func font(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "Verdana-Bold" : "Verdana", fixedSize: size)
    }

    static func italic(_ size: CGFloat) -> Font {
        .custom("Verdana-Italic", fixedSize: size)
    }

    // Surfaces
    static let roomLight = Color(red: 242 / 255, green: 247 / 255, blue: 250 / 255, opacity: 0.88)
    static let roomOpaque = Color(hex: 0xEEF2F5)
    static let popup = Color(hex: 0xE1E8E8)
    static let popupBorder = Color(hex: 0x999999)
    static let border = Color(hex: 0xAAAAAA)
    static let text = Color(hex: 0x222222)
    static let subtleText = Color(hex: 0x555555)
    static let gray = Color(hex: 0x888888)
    static let link = Color(hex: 0x2277FF)
    static let headerBlue = Color(hex: 0x557799)
    static let battleBG = Color(hex: 0xCFD5DA)
    static let usernameBlue = Color(hex: 0x40576A)

    // Status colors from battle.css
    static func statusColor(_ status: String) -> Color {
        switch status {
        case "brn": return Color(hex: 0xEE5533)
        case "psn", "tox": return Color(hex: 0xA4009A)
        case "par": return Color(hex: 0x9AA400)
        case "slp": return Color(hex: 0xAA77AA)
        case "frz": return Color(hex: 0x009AA4)
        default: return Color(hex: 0x999999)
        }
    }

    /// Hue and saturation used by sim-types.css for move buttons.
    static let typeHS: [String: (Double, Double)] = [
        "Normal": (60, 0.14), "Fighting": (3, 0.40), "Flying": (255, 0.20), "Poison": (300, 0.30), "Ground": (44, 0.27),
        "Rock": (49, 0.35), "Bug": (66, 0.42), "Ghost": (262, 0.21), "Steel": (240, 0.06), "Fire": (25, 0.40),
        "Water": (222, 0.29), "Grass": (100, 0.30), "Electric": (48, 0.41), "Psychic": (342, 0.33), "Ice": (180, 0.15),
        "Dragon": (257, 0.39), "Dark": (24, 0.18), "Fairy": (310, 0.41), "Stellar": (180, 0.15), "???": (180, 0.10),
    ]
}

/// FontAwesome 4.7 glyphs, as used throughout Showdown's UI.
enum FA: String {
    case home = "\u{f015}"
    case pencilSquare = "\u{f044}"
    case cog = "\u{f013}"
    case volumeUp = "\u{f028}"
    case volumeOff = "\u{f026}"
    case caretDown = "\u{f0d7}"
    case timesCircle = "\u{f057}"
    case times = "\u{f00d}"
    case plus = "\u{f067}"
    case plusCircle = "\u{f055}"
    case search = "\u{f002}"
    case folder = "\u{f07b}"
    case chevronLeft = "\u{f053}"
    case chevronRight = "\u{f054}"
    case undo = "\u{f0e2}"
    case clock = "\u{f017}"
    case flag = "\u{f024}"
    case download = "\u{f019}"
    case upload = "\u{f093}"
    case comment = "\u{f0e5}"
    case user = "\u{f007}"
    case users = "\u{f0c0}"
    case trophy = "\u{f091}"
    case eye = "\u{f06e}"
    case info = "\u{f05a}"
    case copy = "\u{f0c5}"
    case clipboard = "\u{f0ea}"
    case trash = "\u{f1f8}"
    case check = "\u{f00c}"
    case refresh = "\u{f021}"
    case signOut = "\u{f08b}"
    case list = "\u{f03a}"
    case random = "\u{f074}"
    case barChart = "\u{f080}"
    case pencil = "\u{f040}"
    case paperPlane = "\u{f1d8}"
    case warning = "\u{f071}"
    case arrowUp = "\u{f062}"
    case arrowDown = "\u{f063}"
    case caretRight = "\u{f0da}"
    case squareO = "\u{f096}"
    case checkSquare = "\u{f046}"
    case play = "\u{f04b}"
}

struct FAIcon: View {
    var icon: FA
    var size: CGFloat = 14

    init(_ icon: FA, size: CGFloat = 14) {
        self.icon = icon
        self.size = size
    }

    var body: some View {
        Text(icon.rawValue).font(.custom("FontAwesome", fixedSize: size))
    }
}

/// The five rotating client wallpapers and the menu button hues Showdown pairs with each.
struct PSBackground: Identifiable, Hashable {
    var id: String
    var name: String
    var credit: String
    var hues: [String]

    var url: URL { URL(string: PS.resource + "fx/client-bg-\(id).jpg")! }

    static let all: [PSBackground] = [
        PSBackground(id: "horizon", name: "Horizon", credit: "\"Horizon\" background by Vivian Zou", hues: ["318.87640449438203,35.177865612648226%", "216,46.2962962962963%", "221.25,32.25806451612904%", "197.8021978021978,52.60115606936417%", "232.00000000000003,19.480519480519483%", "228.38709677419354,60.7843137254902%"]),
        PSBackground(id: "ocean", name: "Ocean", credit: "\"Sunrise Ocean\" background by Quanyails", hues: ["82.8169014084507,34.63414634146342%", "216.16438356164383,29.55465587044534%", "212.92682926829266,59.42028985507245%", "209.18918918918916,57.51295336787566%", "199.2857142857143,48.275862068965495%", "213.11999999999998,55.06607929515419%"]),
        PSBackground(id: "shaymin", name: "Shaymin", credit: "\"Shaymin\" background by Daniel Kong", hues: ["39.000000000000064,21.7391304347826%", "170.00000000000003,2.380952380952378%", "157.5,11.88118811881188%", "174.78260869565216,12.041884816753928%", "185.00000000000003,12.76595744680851%", "20,5.660377358490567%"]),
        PSBackground(id: "charizards", name: "Charizards", credit: "\"Charizards\" background by Jessica Valencia", hues: ["37.159090909090914,74.57627118644066%", "10.874999999999998,70.79646017699115%", "179.51612903225808,52.10084033613446%", "20.833333333333336,36.73469387755102%", "192.3076923076923,80.41237113402063%", "210,29.629629629629633%"]),
        PSBackground(id: "psday", name: "PS Day", credit: "Pokémon Showdown Day background by LifeisDANK", hues: ["24.705882352941174,25.37313432835821%", "260.4651162790697,59.44700460829492%", "165.3191489361702,46.07843137254901%", "16.363636363636367,42.63565891472869%", "259.04761904761904,34.05405405405405%", "24.705882352941174,25.37313432835821%"]),
    ]

    static func named(_ id: String) -> PSBackground {
        all.first { $0.id == id } ?? all[3]
    }

    /// Hue and saturation for main menu button `n` (1-based).
    func hueSat(_ n: Int) -> (Double, Double) {
        let raw = hues[min(max(n - 1, 0), hues.count - 1)]
        let parts = raw.replacingOccurrences(of: "%", with: "").split(separator: ",")
        let hue = Double(parts.first ?? "0") ?? 0
        let sat = parts.count > 1 ? (Double(parts[1]) ?? 0) / 100 : 0
        return (hue, sat)
    }
}

/// The wallpaper behind every room.
struct PSWallpaper: View {
    @AppStorage("background") private var backgroundID = "charizards"
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(hex: 0x546BAC)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
                        .clipped()
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .task(id: backgroundID) {
            let url = PSBackground.named(backgroundID).url
            if let cached = SpriteLoader.shared.cached([url]) {
                image = cached
                return
            }
            let loaded = await SpriteLoader.shared.load([url])
            withAnimation(.easeOut(duration: 0.4)) { image = loaded }
        }
    }
}
