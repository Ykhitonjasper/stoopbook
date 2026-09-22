import SwiftUI

/// Seven marks drawn in one house style on a shared 16-unit grid, one stroke
/// weight, round caps and round joins. Each carries the idea of its kit:
/// an interval ruler, an open window, a pin hop, a cluster of pins, a door swing,
/// a load against its track, and a step taken over a gap.
struct KitMark: View {
    let kind: VisitKitKind
    var size: CGFloat = 16
    var tone: Color = AppTheme.ink

    var body: some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / 16
            let style = StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round, lineJoin: .round)
            let faded = tone.opacity(0.4)

            switch kind {
            case .cadence:
                var rail = Path()
                rail.move(to: point(1.5, 8, scale))
                rail.addLine(to: point(14.5, 8, scale))
                context.stroke(rail, with: .color(faded), style: style)

                for mark in [(1.5, 4.5, 11.5), (8.0, 5.5, 10.5), (14.5, 4.5, 11.5)] {
                    var tick = Path()
                    tick.move(to: point(mark.0, mark.1, scale))
                    tick.addLine(to: point(mark.0, mark.2, scale))
                    context.stroke(tick, with: .color(mark.0 == 8 ? AppTheme.brass : tone), style: style)
                }

            case .windowFit:
                var left = Path()
                left.move(to: point(5, 3, scale))
                left.addLine(to: point(2.2, 3, scale))
                left.addLine(to: point(2.2, 13, scale))
                left.addLine(to: point(5, 13, scale))
                context.stroke(left, with: .color(tone), style: style)

                var right = Path()
                right.move(to: point(11, 3, scale))
                right.addLine(to: point(13.8, 3, scale))
                right.addLine(to: point(13.8, 13, scale))
                right.addLine(to: point(11, 13, scale))
                context.stroke(right, with: .color(tone), style: style)

                var span = Path()
                span.move(to: point(5.6, 8, scale))
                span.addLine(to: point(10.4, 8, scale))
                context.stroke(span, with: .color(AppTheme.brass), style: style)

            case .pinTravel:
                var hop = Path()
                hop.move(to: point(4.6, 5.4, scale))
                hop.addLine(to: point(11.4, 10.6, scale))
                context.stroke(
                    hop,
                    with: .color(faded),
                    style: StrokeStyle(lineWidth: 1.3 * scale, lineCap: .round, dash: [1.8 * scale, 2.2 * scale])
                )
                context.fill(circle(3.4, 4.2, 1.7, scale), with: .color(tone))
                context.fill(circle(12.6, 11.8, 1.7, scale), with: .color(AppTheme.brass))

            case .cluster:
                context.stroke(roundedBox(1.6, 2.2, 4.4, scale), with: .color(tone), style: style)
                context.stroke(roundedBox(6.8, 2.2, 4.4, scale), with: .color(faded), style: style)
                context.stroke(roundedBox(4.2, 9.4, 4.4, scale), with: .color(AppTheme.brass), style: style)

            case .accessNotes:
                var frame = Path()
                frame.move(to: point(4.4, 13, scale))
                frame.addLine(to: point(4.4, 3, scale))
                frame.addLine(to: point(10.2, 3, scale))
                context.stroke(frame, with: .color(tone), style: style)

                var swing = Path()
                swing.move(to: point(10.2, 9.6, scale))
                swing.addQuadCurve(
                    to: point(13.4, 13, scale),
                    control: point(13.4, 9.6, scale)
                )
                context.stroke(swing, with: .color(faded), style: style)

                var leaf = Path()
                leaf.move(to: point(10.2, 13, scale))
                leaf.addLine(to: point(12.6, 10.6, scale))
                context.stroke(leaf, with: .color(tone), style: style)

            case .roundLoad:
                context.fill(
                    Path(roundedRect: rect(1.5, 6.4, 13, 3.2, scale), cornerRadius: 1.6 * scale),
                    with: .color(faded)
                )
                context.fill(
                    Path(roundedRect: rect(1.5, 6.4, 8.4, 3.2, scale), cornerRadius: 1.6 * scale),
                    with: .color(AppTheme.brass)
                )

            case .skipCost:
                var walk = Path()
                walk.move(to: point(1.6, 12.4, scale))
                walk.addLine(to: point(4.8, 12.4, scale))
                context.stroke(walk, with: .color(tone), style: style)

                var landing = Path()
                landing.move(to: point(11.2, 12.4, scale))
                landing.addLine(to: point(14.4, 12.4, scale))
                context.stroke(landing, with: .color(tone), style: style)

                var hop = Path()
                hop.move(to: point(4.8, 12.4, scale))
                hop.addQuadCurve(to: point(11.2, 12.4, scale), control: point(8, 4.4, scale))
                context.stroke(
                    hop,
                    with: .color(AppTheme.rust),
                    style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round, dash: [1.8 * scale, 2.2 * scale])
                )
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func point(_ x: CGFloat, _ y: CGFloat, _ scale: CGFloat) -> CGPoint {
        CGPoint(x: x * scale, y: y * scale)
    }

    private func rect(_ x: CGFloat, _ y: CGFloat, _ side: CGFloat, _ scale: CGFloat) -> CGRect {
        rect(x, y, side, side, scale)
    }

    private func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ scale: CGFloat) -> CGRect {
        CGRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
    }

    private func roundedBox(_ x: CGFloat, _ y: CGFloat, _ side: CGFloat, _ scale: CGFloat) -> Path {
        Path(roundedRect: rect(x, y, side, scale), cornerRadius: 1.2 * scale)
    }

    private func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ scale: CGFloat) -> Path {
        Path(ellipseIn: CGRect(
            x: (x - radius) * scale,
            y: (y - radius) * scale,
            width: radius * 2 * scale,
            height: radius * 2 * scale
        ))
    }
}

/// A kit as a row of a printed index: its own drawn mark, its name, and the one
/// line that says what it measures out of.
struct KitRow: View {
    let kind: VisitKitKind
    let title: String
    let summary: String
    var trailing: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                KitMark(kind: kind, size: 20, tone: AppTheme.ink)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppType.rowStrong)
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.leading)

                    Text(summary)
                        .font(AppType.caption)
                        .foregroundStyle(AppTheme.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    if let trailing {
                        Text(trailing)
                            .font(AppType.micro)
                            .foregroundStyle(AppTheme.data)
                    }

                    OutwardArrow(tone: AppTheme.ink.opacity(0.42))
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(summary)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 18) {
        ForEach(VisitKitKind.allCases) { kind in
            HStack(spacing: 12) {
                KitMark(kind: kind, size: 26)
                Text(kind.title).font(AppType.rowStrong).foregroundStyle(AppTheme.ink)
            }
        }
    }
    .padding(28)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(AppBackground())
}
