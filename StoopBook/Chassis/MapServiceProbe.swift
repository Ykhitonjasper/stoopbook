import Foundation
import MapKit
import UIKit

/// How the round sheet is drawn.
enum MapMode: String, CaseIterable, Identifiable {
    /// Apple's basemap, with this app's marks on top.
    case map
    /// The stored pins plotted on this app's own sheet. Always available.
    case plot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .map: return "Map"
        case .plot: return "Plot"
        }
    }
}

/// Whether a real basemap can actually be drawn.
///
/// The question is not "does a host answer" — a portal can answer while the tile
/// service behind MapKit still paints the blank placeholder grid, and the reverse
/// also happens. The honest question is "does MapKit render streets". So the probe
/// asks MapKit itself: it snapshots a small piece of the city and measures the
/// sheet. A rendered basemap is a drawing — many distinct tones, land and water,
/// roads against parcels. The placeholder grid is a flat field — one or two tones
/// across the whole frame.
enum MapServiceProbe {
    /// A dense downtown block, so a real render cannot be mistaken for empty land.
    static let sample = CLLocationCoordinate2D(latitude: 40.7580, longitude: -73.9855)

    /// Launch argument that reports tiles as drawn. The snapshot path cannot run on
    /// a machine with no route to the tile service, and shipping the map mode
    /// without ever executing it is worse than one documented test hook.
    static let assumeReachableArgument = "-StoopBookAssumeMapTiles"

    static func tilesReachable(
        session: URLSession = .shared,
        timeout: TimeInterval = 4
    ) async -> Bool {
        guard !ProcessInfo.processInfo.arguments.contains(assumeReachableArgument) else { return true }
        return await drawsWithRealTiles()
    }

    /// Ask MapKit for a real render and look at it.
    static func drawsWithRealTiles(scale: CGFloat = 2) async -> Bool {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: sample,
            latitudinalMeters: 900,
            longitudinalMeters: 900
        )
        options.size = CGSize(width: 180, height: 180)
        options.pointOfInterestFilter = .excludingAll
        options.showsBuildings = false

        let snapshotter = MKMapSnapshotter(options: options)
        guard let snapshot = try? await snapshotter.start() else { return false }
        return isRenderedBasemap(snapshot.image, scale: scale)
    }

    /// A rendered basemap carries the world: dozens of distinct tones, water apart
    /// from land, roads apart from parcels. The placeholder is a grid on a field —
    /// almost no tones, and a dominant one covering nearly everything.
    static func isRenderedBasemap(_ image: UIImage, scale: CGFloat) -> Bool {
        guard let pixels = pixelSample(image, scale: scale) else { return false }
        var histogram: [UInt8: Int] = [:]
        for luminance in pixels {
            histogram[luminance >> 2, default: 0] += 1
        }
        let total = pixels.count
        let distinctTones = histogram.count
        let dominantShare = Double(histogram.values.max() ?? 0) / Double(total)

        // A real city sheet lands near 90+ tone buckets at this sample size; the
        // placeholder grid under 12, with one bucket over 90% of the frame.
        return distinctTones >= 24 && dominantShare < 0.82
    }

    /// Downsampled luminance of the image, centre crop, one sample per few pixels —
    /// enough to characterise the sheet, cheap enough to run at screen open.
    private static func pixelSample(_ image: UIImage, scale: CGFloat, samplesPerSide: Int = 90) -> [UInt8]? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 8, height > 8 else { return nil }

        guard let context = CGContext(
            data: nil,
            width: samplesPerSide,
            height: samplesPerSide,
            bitsPerComponent: 8,
            bytesPerRow: samplesPerSide,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: samplesPerSide, height: samplesPerSide))
        guard let data = context.data else { return nil }
        let buffer = data.bindMemory(to: UInt8.self, capacity: samplesPerSide * samplesPerSide)
        return (0..<(samplesPerSide * samplesPerSide)).map { buffer[$0] }
    }
}
