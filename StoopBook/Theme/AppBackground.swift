import CoreGraphics
import SwiftUI

/// Stone paper with one directional rake of morning light and a fine grain.
/// No blob, no ring, no bloom, and nothing that sits over the content.
struct AppBackground: View {
    /// How far the page above it has been read. The light and the grain ride this by
    /// a few points, so the paper sits under the content instead of behind it.
    var rake: CGFloat = 0

    private var clampedRake: CGFloat {
        min(max(rake, -26), 26)
    }

    var body: some View {
        ZStack {
            AppTheme.paper

            LinearGradient(
                stops: [
                    .init(color: AppTheme.surface.opacity(0.92), location: 0.00),
                    .init(color: AppTheme.surface.opacity(0.46), location: 0.22),
                    .init(color: AppTheme.surface.opacity(0.12), location: 0.48),
                    .init(color: .clear, location: 0.74)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .offset(y: clampedRake * 0.5)

            PaperGrain()
                .offset(y: clampedRake)
        }
        .ignoresSafeArea()
    }
}

/// Film grain on the substrate, behind everything anyone needs to read. The tile is
/// larger than the sheet it rides, so a small offset never exposes an edge.
struct PaperGrain: View {
    var body: some View {
        Image(decorative: GrainTile.image, scale: 1)
            .resizable(resizingMode: .tile)
            .blendMode(.multiply)
            .opacity(0.055)
            .padding(-80)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }
}

private enum GrainTile {
    static let image: CGImage = make(size: 96)

    private static func make(size: Int) -> CGImage {
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        var seed: UInt32 = 0x51F0_2A17
        for index in 0..<(size * size) {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let value = UInt8(truncatingIfNeeded: seed >> 24)
            let offset = index * 4
            pixels[offset] = value
            pixels[offset + 1] = value
            pixels[offset + 2] = value
            pixels[offset + 3] = 255
        }

        let image = pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            return context.makeImage()
        }

        return image ?? fallback()
    }

    private static func fallback() -> CGImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        let image = renderer.image { context in
            UIColor(white: 0.5, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        return image.cgImage ?? UIImage().cgImage!
    }
}

#Preview {
    AppBackground()
}
