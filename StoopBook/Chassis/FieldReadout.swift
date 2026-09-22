import SwiftUI

/// The primary result for a measured visit figure.
/// The accent bar is gone: the number itself is the emphasis, set in the display
/// serif with air around it, and registration marks sit in the card's own margin.
struct FieldReadout: View {
    let label: String
    let value: String
    var unit: String?
    var context: String?
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(AppType.micro)
                .foregroundStyle(AppTheme.inkSoft)

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(value)
                    .font(AppType.figure(46))
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .rollingFigure()

                if let unit {
                    Text(unit)
                        .font(AppType.meta)
                        .foregroundStyle(AppTheme.data)
                        .padding(.bottom, 6)
                }
            }
            .accessibilityElement(children: .combine)

            if let context {
                Text(context)
                    .font(AppType.rowStrong)
                    .foregroundStyle(AppTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let note {
                Text(note)
                    .font(AppType.caption)
                    .foregroundStyle(AppTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardSurface(padding: AppMetrics.readoutPadding)
        .overlay {
            RegistrationMarks()
                .padding(7)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Two corner marks, the way a survey sheet frames its measurement.
private struct RegistrationMarks: View {
    var body: some View {
        Canvas { context, size in
            let arm: CGFloat = 7
            let tone = AppTheme.ink.opacity(0.24)
            let style = StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)

            var topLeft = Path()
            topLeft.move(to: CGPoint(x: 0, y: arm))
            topLeft.addLine(to: CGPoint(x: 0, y: 0))
            topLeft.addLine(to: CGPoint(x: arm, y: 0))
            context.stroke(topLeft, with: .color(tone), style: style)

            var bottomRight = Path()
            bottomRight.move(to: CGPoint(x: size.width, y: size.height - arm))
            bottomRight.addLine(to: CGPoint(x: size.width, y: size.height))
            bottomRight.addLine(to: CGPoint(x: size.width - arm, y: size.height))
            context.stroke(bottomRight, with: .color(tone), style: style)
        }
    }
}

#Preview {
    ScreenScaffold {
        FieldReadout(
            label: "CADENCE",
            value: "5",
            unit: "overdue",
            context: "Four households past their agreed interval",
            note: "Last visit day against each stoop's interval."
        )
    }
}
