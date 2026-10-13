import ImageIO
import SwiftUI
import UIKit
import ShowdownKit

/// Downloads sprites, decodes animated GIFs, and remembers which URLs don't exist.
final class SpriteLoader: @unchecked Sendable {
    static let shared = SpriteLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private var missing = Set<URL>()
    private let lock = NSLock()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
        cache.countLimit = 400
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
        view.contentMode = .scaleAspectFit
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

/// An in-battle sprite, drawn at its native proportions so small Pokemon stay small.
struct BattleSprite: View {
    var species: String
    var back: Bool
    var shiny: Bool
    var scale: CGFloat = 1.6

    @Environment(DexStore.self) private var dex
    @State private var image: UIImage?

    private var urls: [URL] {
        Sprites.battleURLs(species: species, back: back, shiny: shiny, dex: dex.isLoaded ? dex.data : nil)
    }

    var body: some View {
        Group {
            if let image {
                AnimatedImage(image: image, pixelated: true)
                    .frame(width: image.size.width * scale, height: image.size.height * scale)
            } else {
                Color.clear.frame(width: 80 * scale, height: 80 * scale)
            }
        }
        .task(id: urls) {
            if let cached = SpriteLoader.shared.cached(urls) {
                image = cached
                return
            }
            let loaded = await SpriteLoader.shared.load(urls)
            withAnimation(.easeOut(duration: 0.25)) { image = loaded }
        }
    }
}

/// HOME-style artwork for menus and the teambuilder.
struct PokemonArtwork: View {
    var species: String
    var shiny: Bool = false
    var size: CGFloat = 56

    @Environment(DexStore.self) private var dex
    @State private var image: UIImage?

    private var urls: [URL] {
        Sprites.artworkURLs(species: species, shiny: shiny, dex: dex.isLoaded ? dex.data : nil)
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                Image(systemName: "circle.dashed")
                    .font(.system(size: size * 0.35))
                    .foregroundStyle(.white.opacity(0.15))
            }
        }
        .frame(width: size, height: size)
        .task(id: urls) {
            guard !species.isEmpty else { return }
            if let cached = SpriteLoader.shared.cached(urls) {
                image = cached
                return
            }
            let loaded = await SpriteLoader.shared.load(urls)
            withAnimation(.easeOut(duration: 0.25)) { image = loaded }
        }
    }
}

struct TrainerAvatar: View {
    var avatar: String
    var name: String
    var size: CGFloat = 40

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle().fill(Theme.accentGradient)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(size * 0.06)
                    .clipShape(Circle())
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.45, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
        .task(id: avatar) {
            guard let url = Sprites.trainerURL(avatar) else {
                image = nil
                return
            }
            image = await SpriteLoader.shared.load([url])
        }
    }
}
