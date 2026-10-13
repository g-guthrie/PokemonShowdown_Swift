import ImageIO
import SwiftUI
import UIKit
import ShowdownKit

/// Downloads images from Showdown's servers, decodes animated GIFs, and remembers missing URLs.
final class SpriteLoader: @unchecked Sendable {
    static let shared = SpriteLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private var missing = Set<URL>()
    private let lock = NSLock()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 48 * 1024 * 1024, diskCapacity: 512 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
        cache.countLimit = 600
    }

    func cached(_ urls: [URL]) -> UIImage? {
        for url in urls {
            if let image = cache.object(forKey: url as NSURL) { return image }
            if !isMissing(url) { return nil }
        }
        return nil
    }

    func load(_ urls: [URL]) async -> UIImage? {
        for url in urls {
            if let image = cache.object(forKey: url as NSURL) { return image }
            if isMissing(url) { continue }
            guard let result = try? await session.data(from: url) else { continue }
            guard (result.1 as? HTTPURLResponse)?.statusCode == 200, let image = Self.decode(result.0) else {
                markMissing(url)
                continue
            }
            cache.setObject(image, forKey: url as NSURL)
            return image
        }
        return nil
    }

    private func isMissing(_ url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return missing.contains(url)
    }

    private func markMissing(_ url: URL) {
        lock.lock()
        missing.insert(url)
        lock.unlock()
    }

    static func decode(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        if count <= 1 { return UIImage(data: data) }
        var frames: [UIImage] = []
        var duration = 0.0
        for index in 0..<count {
            guard let frame = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: frame))
            duration += frameDelay(source, index)
        }
        return UIImage.animatedImage(with: frames, duration: duration)
    }

    private static func frameDelay(_ source: CGImageSource, _ index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else { return 0.1 }
        let delay = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
        return delay < 0.02 ? 0.1 : delay
    }
}

/// UIImageView wrapper so animated GIF frames play.
struct AnimatedImage: UIViewRepresentable {
    let image: UIImage
    var pixelated = false

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleToFill
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        view.layer.magnificationFilter = pixelated ? .nearest : .linear
        if view.image !== image {
            view.image = image
            if image.images != nil { view.startAnimating() }
        }
    }
}

/// Any image from Showdown's server.
struct RemoteImage: View {
    var path: String
    var pixelated = true
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(pixelated ? .none : .high)
            } else {
                Color.clear
            }
        }
        .task(id: path) {
            guard let url = URL(string: path.hasPrefix("http") ? path : PS.resource + path) else { return }
            if let cached = SpriteLoader.shared.cached([url]) {
                image = cached
                return
            }
            image = await SpriteLoader.shared.load([url])
        }
    }
}

/// Type label image (`sprites/types/Fire.png`, 32×14).
struct TypeIcon: View {
    var type: String
    var scale: CGFloat = 1

    var body: some View {
        RemoteImage(path: "sprites/types/\(type).png")
            .frame(width: 32 * scale, height: 14 * scale)
    }
}

/// Physical / Special / Status icon (32×14).
struct CategoryIcon: View {
    var category: String
    var scale: CGFloat = 1

    var body: some View {
        RemoteImage(path: "sprites/categories/\(category).png")
            .frame(width: 32 * scale, height: 14 * scale)
    }
}

/// A battle sprite, sized the way Showdown's scene sizes it.
struct BattleSprite: View {
    var species: String
    var back: Bool
    var shiny: Bool
    /// Showdown's depth scale: 1.5 near, 1.0 far.
    var scale: CGFloat
    /// Points per Showdown pixel in the current scene.
    var unit: CGFloat

    @Environment(DexStore.self) private var dex
    @State private var image: UIImage?

    private var urls: [URL] {
        Sprites.battleURLs(species: species, back: back, shiny: shiny, dex: dex.isLoaded ? dex.data : nil)
    }

    var body: some View {
        let size = image.map { CGSize(width: $0.size.width, height: $0.size.height) } ?? CGSize(width: 96, height: 96)
        Group {
            if let image {
                AnimatedImage(image: image, pixelated: true)
            } else {
                Color.clear
            }
        }
        .frame(width: floor(size.width * scale) * unit, height: floor(size.height * scale) * unit)
        .task(id: urls) {
            if let cached = SpriteLoader.shared.cached(urls) {
                image = cached
                return
            }
            image = await SpriteLoader.shared.load(urls)
        }
    }
}

/// Showdown's menu icons, cut from `pokemonicons-sheet.png` (40×30 cells, 12 per row).
enum PokemonIconSheet {
    static let url = URL(string: PS.resource + "sprites/pokemonicons-sheet.png?v22")!
    static let pokeballURL = URL(string: PS.resource + "sprites/pokemonicons-pokeball-sheet.png")!

    private static let tables: (indexes: [String: Int], left: [String: Int]) = {
        struct Tables: Decodable {
            var indexes: [String: Int]
            var left: [String: Int]
        }
        guard let url = Bundle.main.url(forResource: "PokemonIconIndexes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let tables = try? JSONDecoder().decode(Tables.self, from: data) else { return ([:], [:]) }
        return (tables.indexes, tables.left)
    }()

    static func index(species: String, dex: DexData, female: Bool = false, facingLeft: Bool = false) -> Int {
        var name = species
        if name.hasSuffix("-*") { name = String(name.dropLast(2)) }
        let id = toID(name)
        var num = dex.species[id]?.num ?? 0
        if num < 0 || num > 1025 { num = 0 }
        if let special = tables.indexes[id] { num = special }
        if female, ["unfezant", "frillish", "jellicent", "meowstic", "pyroar"].contains(id), let f = tables.indexes[id + "f"] { num = f }
        if facingLeft, let left = tables.left[id] { num = left }
        return num
    }

    @MainActor private static var sheet: CGImage?

    @MainActor static func crop(_ index: Int, from image: UIImage) -> UIImage? {
        if sheet == nil { sheet = image.cgImage }
        guard let cg = sheet else { return nil }
        let scale = CGFloat(cg.width) / 480
        let rect = CGRect(x: CGFloat(index % 12) * 40 * scale, y: CGFloat(index / 12) * 30 * scale, width: 40 * scale, height: 30 * scale)
        guard let piece = cg.cropping(to: rect) else { return nil }
        return UIImage(cgImage: piece)
    }
}

/// A 40×30 party icon.
struct PokemonIcon: View {
    var species: String
    var female = false
    var facingLeft = false
    var fainted = false
    var scale: CGFloat = 1

    @Environment(DexStore.self) private var dex
    @State private var sheet: UIImage?

    var body: some View {
        ZStack {
            if let sheet, !species.isEmpty, let icon = PokemonIconSheet.crop(PokemonIconSheet.index(species: species, dex: dex.data, female: female, facingLeft: facingLeft), from: sheet) {
                Image(uiImage: icon)
                    .resizable()
                    .interpolation(.none)
                    .opacity(fainted ? 0.3 : 1)
                    .grayscale(fainted ? 1 : 0)
                    .brightness(fainted ? -0.25 : 0)
                    .scaleEffect(x: facingLeft ? -1 : 1, y: 1)
            }
        }
        .frame(width: 40 * scale, height: 30 * scale)
        .task {
            if let cached = SpriteLoader.shared.cached([PokemonIconSheet.url]) {
                sheet = cached
                return
            }
            sheet = await SpriteLoader.shared.load([PokemonIconSheet.url])
        }
    }
}

/// Pokeball placeholders for unrevealed team slots (`pokemonicons-pokeball-sheet.png`).
struct PokeballIcon: View {
    enum Kind: Int { case normal = 0, statused = 1, fainted = 2 }
    var kind: Kind = .normal
    var scale: CGFloat = 1
    @State private var sheet: UIImage?

    var body: some View {
        ZStack {
            if let cg = sheet?.cgImage {
                let unit = CGFloat(cg.height) / 30
                if let piece = cg.cropping(to: CGRect(x: CGFloat(kind.rawValue) * 40 * unit, y: 0, width: 40 * unit, height: min(30 * unit, CGFloat(cg.height)))) {
                    Image(uiImage: UIImage(cgImage: piece))
                        .resizable()
                        .interpolation(.none)
                        .opacity(kind == .fainted ? 0.4 : 1)
                        .offset(y: 4 * scale)
                }
            }
        }
        .frame(width: 40 * scale, height: 30 * scale)
        .task { sheet = await SpriteLoader.shared.load([PokemonIconSheet.pokeballURL]) }
    }
}

/// 24×24 item icon from `itemicons-sheet.png` (16 per row).
struct ItemIcon: View {
    var item: String
    var scale: CGFloat = 1
    @Environment(DexStore.self) private var dex
    @State private var sheet: UIImage?
    private static let url = URL(string: PS.resource + "sprites/itemicons-sheet.png")!

    var body: some View {
        ZStack {
            if let cg = sheet?.cgImage, let num = dex.data.itemSprites[toID(item)] {
                let unit = CGFloat(cg.width) / 384
                if let piece = cg.cropping(to: CGRect(x: CGFloat(num % 16) * 24 * unit, y: CGFloat(num / 16) * 24 * unit, width: 24 * unit, height: 24 * unit)) {
                    Image(uiImage: UIImage(cgImage: piece)).resizable().interpolation(.none)
                }
            }
        }
        .frame(width: 24 * scale, height: 24 * scale)
        .task {
            guard !item.isEmpty else { return }
            sheet = await SpriteLoader.shared.load([Self.url])
        }
    }
}

/// Trainer sprite (`sprites/trainers/<avatar>.png`), with Showdown's numbered avatars mapped to names.
struct TrainerSprite: View {
    var avatar: String
    var size: CGFloat = 80

    var body: some View {
        RemoteImage(path: Self.path(avatar))
            .scaledToFit()
            .frame(width: size, height: size)
    }

    static func path(_ avatar: String) -> String {
        var name = avatar.hasPrefix("#") ? String(avatar.dropFirst()) : avatar
        if let number = Int(name) { name = numbered[number] ?? "unknown" }
        if name.isEmpty { name = "unknown" }
        return "sprites/trainers/\(name).png"
    }

    /// Showdown's numbered avatars (from the client's `BattleAvatarNumbers`).
    static let numbered: [Int: String] = {
        guard let url = Bundle.main.url(forResource: "AvatarNumbers", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        var out: [Int: String] = [:]
        for (key, value) in table { if let number = Int(key) { out[number] = value } }
        return out
    }()
}
