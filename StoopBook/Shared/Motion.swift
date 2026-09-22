import SwiftUI

/// The motion law of this app, written down so it stays true.
///
/// Everything here moves something that is *already on the page*: an indicator
/// travelling to the tab you chose, a rule finding its length, a figure rolling to
/// its next value, ink rising in the house you are standing at. Nothing here fades
/// content in, nothing loops for decoration, and nothing lifts a card on press.
/// A page whose words depend on an animation finishing is a page that can render
/// empty — that trade is never worth the flourish.

/// A hairline that finds its length once, when it lands on the page.
///
/// It is a rule, not content: if the animation never runs, the worst case is a
/// shorter line. No word on the page depends on it.
struct DrawnRule: View {
    var tone: Color = AppTheme.edge
    var height: CGFloat = 1
    var duration: Double = 0.5
    var delay: Double = 0
    /// Nil means the full width of whatever holds it.
    var width: CGFloat?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let full = width ?? proxy.size.width
            Capsule(style: .continuous)
                .fill(tone)
                .frame(width: max(0.5, full * progress), height: height)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: height)
        .onAppear {
            guard !reduceMotion else {
                progress = 1
                return
            }
            withAnimation(.easeInOut(duration: duration).delay(delay)) {
                progress = 1
            }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// A figure that rolls to its next value instead of snapping.
    ///
    /// This animates a *change*: the value is on screen before and after. Nothing
    /// counts up from nothing, because a figure that starts at zero is a figure that
    /// can be read as zero.
    func rollingFigure() -> some View {
        contentTransition(.numericText())
    }

    /// Marks the thing a card opens out of. iOS 18 and later; older systems keep the
    /// plain push they always had.
    @ViewBuilder
    func zoomSource(_ id: String?, in namespace: Namespace.ID?) -> some View {
        if #available(iOS 18.0, *), let id, let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Opens this card out of the mark that was tapped rather than cutting to it.
    @ViewBuilder
    func zoomOpen(_ id: String?, in namespace: Namespace.ID?) -> some View {
        if #available(iOS 18.0, *), let id, let namespace {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}

/// The press language of the app: the control takes a tonal fill swept from the
/// leading edge, and it reaches the full track. The fill is masked rather than
/// scaled, so the shape's corners never morph halfway through — the giveaway of a
/// half-built fill. No lift, no shadow, no scale.
struct PressFillStyle: ButtonStyle {
    var tone: Color = AppTheme.ink.opacity(0.10)
    var radius: CGFloat = AppMetrics.controlRadius

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(tone)
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: configuration.isPressed ? proxy.size.width : 0)
                        }
                        .animation(reduceMotion ? nil : AppMotion.fill, value: configuration.isPressed)
                }
                .allowsHitTesting(false)
            }
    }
}

/// How far the page has scrolled, handed to the background so the morning light
/// rakes with the reader and the page stops feeling like a flat card.
struct PageRakeKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    ScreenScaffold {
        DrawnRule()
            .padding(.vertical, 12)
        DrawnRule(tone: AppTheme.brass, duration: 0.42, delay: 0.14, width: 28)
        Button("Press me") {}
            .font(AppType.rowStrong)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(AppTheme.ink, in: RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous))
            .foregroundStyle(AppTheme.paper)
            .buttonStyle(PressFillStyle(tone: AppTheme.brass.opacity(0.28)))
        Text("12")
            .font(AppType.figure(46))
            .rollingFigure()
    }
}
