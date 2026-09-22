import SwiftUI

/// One world, held with discipline: stone paper, green-black ink, brass thread,
/// rust and sage only for cadence state. Nothing here is a default.
enum AppTheme {
    // Ground
    static let paper = Color("BgBase")
    static let surface = Color("BgElevated")
    static let surfaceLow = Color("SurfaceLow")
    static let edge = Color("Hairline")

    // Ink
    static let ink = Color("TextPrimary")
    static let inkSoft = Color("TextSecondary")
    static let inkFaint = Color("InkFaint")

    // Measured data sits in mono, and it is the only thing that does
    static let data = Color("TextMono")

    // Cadence state and the one brand line
    static let brass = Color("Brass")
    static let accent = Color("AccentColor")
    static let rust = Color("Danger")
    static let sage = Color("Sage")

    // Legacy token names kept so screens read the same palette
    static let bgBase = paper
    static let bgElevated = surface
    static let textPrimary = ink
    static let textSecondary = inkSoft
    static let textMono = data
    static let danger = rust
    static let hairline = edge

    static var displayName: String {
        let display = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        let trimmed = (display ?? name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "App" : trimmed
    }
}

/// Three roles, never one costume on every small string:
/// display is a serif with real character, prose is the neutral system sans,
/// and numbers, ids and windows sit in mono because that content is data.
enum AppType {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Screen and readout headline voice.
    static let masthead = Font.system(size: 27, weight: .semibold, design: .serif)
    static let title = Font.system(size: 20, weight: .semibold, design: .serif)

    /// Big measured figure. Air is added at the call site with tracking.
    static func figure(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static let sectionTitle = Font.headline
    static let row = Font.subheadline
    static let rowStrong = Font.subheadline.weight(.semibold)
    static let body = Font.subheadline
    static let caption = Font.footnote
    static let data = Font.subheadline.monospaced()
    static let meta = Font.footnote.monospaced()
    static let micro = Font.caption2.monospaced()
}

extension CadenceState {
    /// Cadence state is the only thing on the page allowed colour.
    var tone: Color {
        switch self {
        case .overdue: return AppTheme.rust
        case .dueToday: return AppTheme.accent
        case .ahead: return AppTheme.sage
        }
    }
}

/// Every curve the app owns. Motion earns its place by moving something already on
/// the page — an indicator, a rule, a figure, an ink fill — never by revealing
/// content, and never on a loop.
enum AppMotion {
    static let quick = Animation.spring(response: 0.26, dampingFraction: 0.88)
    static let settle = Animation.spring(response: 0.44, dampingFraction: 0.92)
    /// The one authored draw. Content below it is never gated on this finishing.
    static let thread = Animation.easeInOut(duration: 0.85)
    /// An indicator travelling to where the eye already is.
    static let slide = Animation.spring(response: 0.32, dampingFraction: 0.86)
    /// One fill, swept from the leading edge, reaching the whole track.
    static let fill = Animation.easeOut(duration: 0.34)
    /// The map opening on the round rather than cutting to it.
    static let openMap = Animation.easeInOut(duration: 0.75)
    /// A page being replaced by the next one, both of them always legible.
    static let page = Animation.easeInOut(duration: 0.28)
}
