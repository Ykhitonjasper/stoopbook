import SwiftUI

/// The signature of this app: the morning round drawn as the street it is walked on.
/// One rowhouse per stoop, in visit order, standing on a single brass thread.
/// Roof height carries dwell minutes, the number over each roof carries days since
/// the last visit, and the stop you are on is the one house drawn in solid ink.
struct StreetLine: View {
    let stops: [VisitStop]
    let focusedStopID: String?
    let state: (VisitStop) -> CadenceState
    /// The last closed visit at this door, drawn as a small flag under the house
    /// number: a bell for no answer, a lock for blocked, a turn for skipped.
    var outcome: (VisitStop) -> VisitOutcome? = { _ in nil }
    /// Set when the household card opens out of the house that was tapped.
    var zoomNamespace: Namespace.ID?
    var onSelect: (VisitStop) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var thread: CGFloat = 1

    /// One caption row above the roofs, one number row under the sidewalk.
    private static let annotationHeight: CGFloat = 14
    private static let numberRowHeight: CGFloat = 24
    /// A bay is drawn at a street's width, not at whatever the column happens to
    /// be, so a round of six houses is not six mansions. Wider columns turn into
    /// the gap between neighbours.
    private static let maxHouseWidth: CGFloat = 46
    private static let partyWall: CGFloat = 6

    /// Tall enough for the tallest house any round can draw, so no roof is ever cut.
    static var lineHeight: CGFloat {
        annotationHeight + RowhouseMark.maxHeight(width: maxHouseWidth) + numberRowHeight
    }

    var body: some View {
        GeometryReader { proxy in
            let columnWidth = max(1, proxy.size.width / CGFloat(max(stops.count, 1)))
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                        column(for: stop, index: index, width: columnWidth)
                    }
                }
                // The thread runs along the sidewalk, behind every stoop, so the
                // route reads as the walk it is rather than a wire threaded
                // through the buildings.
                .background(alignment: .bottom) {
                    ThreadRail()
                        .trim(from: 0, to: thread)
                        .stroke(
                            AppTheme.brass,
                            style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: proxy.size.width + 12, height: 1.4)
                        .offset(x: -6)
                        .opacity(stops.count > 1 ? 1 : 0)
                }

                sidewalk(width: proxy.size.width)

                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                        VStack(spacing: 1) {
                            Text("\(index + 1)")
                                .font(AppType.micro)
                                .foregroundStyle(stop.id == focusedStopID ? AppTheme.ink : AppTheme.inkSoft)
                            if let mark = outcome(stop) {
                                Image(systemName: mark.glyph)
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(AppTheme.rust)
                                    .accessibilityLabel("\(mark.title)")
                            }
                        }
                        .frame(width: columnWidth)
                        .padding(.top, 6)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .frame(height: Self.lineHeight)
        .task {
            guard !reduceMotion else { return }
            thread = 0
            try? await Task.sleep(nanoseconds: 80_000_000)
            withAnimation(AppMotion.thread) { thread = 1 }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Morning line, \(stops.count) stoops in visit order")
    }

    // MARK: - Pieces

    private func column(for stop: VisitStop, index: Int, width: CGFloat) -> some View {
        let stopState = state(stop)
        let focused = stop.id == focusedStopID
        let houseWidth = min(max(width - Self.partyWall, 18), Self.maxHouseWidth)
        let houseHeight = RowhouseMark.height(width: houseWidth, dwellFraction: dwellFraction(for: stop))

        return Button {
            onSelect(stop)
        } label: {
            VStack(spacing: 2) {
                Text(caption(for: stop, state: stopState))
                    .font(AppType.micro)
                    .foregroundStyle(stopState.tone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(height: Self.annotationHeight, alignment: .bottom)

                RowhouseMark(
                    width: houseWidth,
                    height: houseHeight,
                    focused: focused,
                    roofTone: stopState.tone
                )
            }
            .frame(width: width, alignment: .bottom)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .zoomSource(stop.id, in: zoomNamespace)
        .accessibilityLabel(accessibilityLabel(for: stop, index: index, state: stopState))
        .accessibilityAddTraits(focused ? [.isButton, .isSelected] : .isButton)
    }

    private func sidewalk(width: CGFloat) -> some View {
        Capsule()
            .fill(AppTheme.ink.opacity(0.26))
            .frame(width: width + 12, height: 1.6)
            .offset(x: -6)
            .padding(.top, 0.6)
    }

    // MARK: - Meaning

    /// Dwell against the range the bar is read in: twenty minutes to seventy.
    private func dwellFraction(for stop: VisitStop) -> CGFloat {
        let dwell = min(max(stop.dwellMinutes, 20), 70)
        return CGFloat(dwell - 20) / 50
    }

    /// The size of the gap in days, coloured by which way it points.
    private func caption(for stop: VisitStop, state: CadenceState) -> String {
        switch state {
        case .overdue:
            return "\(max(0, stop.lastVisitDayOffset - stop.cadenceDays))d"
        case .dueToday:
            return "0d"
        case .ahead:
            return "\(max(0, stop.cadenceDays - stop.lastVisitDayOffset))d"
        }
    }

    private func accessibilityLabel(for stop: VisitStop, index: Int, state: CadenceState) -> String {
        var label = "Stop \(index + 1), \(stop.nickname). \(state.title), visited \(stop.lastVisitDayOffset) days ago on a \(stop.cadenceDays) day cadence. Window \(stop.windowStartHour) to \(stop.windowEndHour)."
        if let mark = outcome(stop) {
            label += " Last visit \(mark.title.lowercased())."
        }
        return label
    }
}

private struct ThreadRail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// The house mark: three steps up to a door. Drawn, never a glyph in a tile.
struct StoopMark: View {
    var size: CGFloat = 22
    var tone: Color = AppTheme.ink

    var body: some View {
        Canvas { context, canvasSize in
            let step = canvasSize.width / 6
            var path = Path()
            path.move(to: CGPoint(x: 0, y: canvasSize.height))
            path.addLine(to: CGPoint(x: step * 2, y: canvasSize.height))
            path.addLine(to: CGPoint(x: step * 2, y: canvasSize.height - step))
            path.addLine(to: CGPoint(x: step * 4, y: canvasSize.height - step))
            path.addLine(to: CGPoint(x: step * 4, y: canvasSize.height - step * 2))
            path.addLine(to: CGPoint(x: step * 6, y: canvasSize.height - step * 2))
            path.addLine(to: CGPoint(x: step * 6, y: canvasSize.height - step * 4))
            context.stroke(
                path,
                with: .color(tone),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
            )

            let door = CGRect(
                x: step * 4.4,
                y: canvasSize.height - step * 4,
                width: step * 1.2,
                height: step * 1.6
            )
            context.fill(Path(door), with: .color(tone))
        }
        .frame(width: size, height: size * 0.72)
        .accessibilityHidden(true)
    }
}

#Preview {
    let stops = Array(StoopBookSeed.stops.prefix(8))
    return VStack(alignment: .leading, spacing: 24) {
        StoopMark(size: 30)
        StreetLine(
            stops: stops,
            focusedStopID: "visit-03",
            state: { $0.lastVisitDayOffset > $0.cadenceDays ? .overdue : ($0.lastVisitDayOffset == $0.cadenceDays ? .dueToday : .ahead) },
            onSelect: { _ in }
        )
        .padding(.horizontal, 20)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .padding(.vertical, 40)
    .background(AppBackground())
}
