import SwiftUI

enum AppMetrics {
    static let screenPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 26
    static let cardPadding: CGFloat = 18
    static let cardRadius: CGFloat = 14
    static let contentSpacing: CGFloat = 12
    static let tightSpacing: CGFloat = 6
    static let hairlineWidth: CGFloat = 1
    static let iconColumn: CGFloat = 24
    static let tileMinWidth: CGFloat = 148
    static let controlRadius: CGFloat = 10
    static let inputVerticalPadding: CGFloat = 13
    static let segmentVerticalPadding: CGFloat = 9
    static let readoutPadding: CGFloat = 20
}

extension View {
    /// Tonal elevation: the surface steps up from the paper, a stroke in the paper's own
    /// stone family defines the lip, and one hairline of light catches the top edge.
    /// No contrasting outline, no drop shadow bloom.
    func cardSurface(
        padding: CGFloat = AppMetrics.cardPadding,
        radius: CGFloat = AppMetrics.cardRadius
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape
                    .fill(AppTheme.surface)
                    .overlay {
                        shape.strokeBorder(AppTheme.edge.opacity(0.9), lineWidth: AppMetrics.hairlineWidth)
                    }
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(0.6))
                            .frame(height: 1)
                            .padding(.horizontal, radius * 0.8)
                    }
                    .clipShape(shape)
            }
    }

    /// A recessed well for controls that sit below the surface.
    func wellSurface(
        padding: CGFloat = AppMetrics.cardPadding,
        radius: CGFloat = AppMetrics.controlRadius
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape
                    .fill(AppTheme.surfaceLow.opacity(0.75))
                    .overlay {
                        shape.strokeBorder(AppTheme.ink.opacity(0.06), lineWidth: AppMetrics.hairlineWidth)
                    }
                    .clipShape(shape)
            }
    }
}

/// The one drawn arrow: out and up, away from the page. Everywhere a row opens
/// something, this is the mark, so the app never leans on a stock chevron.
struct OutwardArrow: View {
    var size: CGFloat = 12
    var tone: Color = AppTheme.inkSoft

    var body: some View {
        Canvas { context, canvasSize in
            let width = canvasSize.width
            let height = canvasSize.height
            var shaft = Path()
            shaft.move(to: CGPoint(x: 0.5, y: height - 0.5))
            shaft.addLine(to: CGPoint(x: width - 0.5, y: 0.5))
            context.stroke(
                shaft,
                with: .color(tone),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
            )

            var head = Path()
            head.move(to: CGPoint(x: width * 0.34, y: 0.5))
            head.addLine(to: CGPoint(x: width - 0.5, y: 0.5))
            head.addLine(to: CGPoint(x: width - 0.5, y: height * 0.66))
            context.stroke(
                head,
                with: .color(tone),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
        Text("Elevated block")
            .foregroundStyle(AppTheme.textPrimary)
            .cardSurface()
        Text("Recessed well")
            .foregroundStyle(AppTheme.textPrimary)
            .wellSurface()
        OutwardArrow()
    }
    .padding(AppMetrics.screenPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(AppBackground())
}
