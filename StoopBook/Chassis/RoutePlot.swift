import SwiftUI

/// The round drawn as a field plot: the pins the app actually stores, laid on a
/// survey sheet and joined in visit order by a brass thread.
///
/// This is deliberately not a slippy map. Apple's tiles need a network, and a
/// round book that only works online is not a round book. A stored round has real
/// coordinates, so the honest picture is the survey itself: pins, order, distance,
/// and a scale bar — drawn here, on this app's paper, at any connectivity.
struct RoutePlot: View {
    /// Every pin on the sheet.
    let stops: [VisitStop]
    /// The pins in walk order: the thread runs through these, and they carry numbers.
    let route: [VisitStop]
    let focusedStopID: String?
    let state: (VisitStop) -> CadenceState
    /// Set when the household card opens out of the pin that was tapped.
    var zoomNamespace: Namespace.ID?
    var onSelect: (VisitStop) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var threadProgress: CGFloat = 1

    /// Room for the sheet frame, the scale bar and the focused label.
    private let inset: CGFloat = 34
    private let hitTarget: CGFloat = 44
    private let maxNumberedPins = 14

    var body: some View {
        GeometryReader { proxy in
            let frame = PlotFrame(stops: stops, size: proxy.size, inset: inset)
            ZStack(alignment: .topLeading) {
                // Order matters and is the whole drawing: the sheet goes down first,
                // the thread over it, then the pins and their numbers. A sheet filled
                // on top of the thread erases the walk it is there to record.
                Canvas { context, size in
                    base(&context, size: size, frame: frame)
                }
                .accessibilityHidden(true)

                RouteThread(points: frame.points(for: route))
                    .trim(from: 0, to: threadProgress)
                    .stroke(
                        AppTheme.brass,
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                    )
                    .opacity(route.count > 1 ? 1 : 0)
                    .frame(width: proxy.size.width, height: proxy.size.height)

                Canvas { context, size in
                    marks(&context, size: size, frame: frame)
                }
                .accessibilityHidden(true)

                ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                    // Kept as an element for VoiceOver and for the test tree, but the
                    // sheet resolves taps itself: two households in one building sit
                    // 8pt apart, and 44pt targets that overlap open the wrong door.
                    Button {
                        onSelect(stop)
                    } label: {
                        Color.clear
                            .frame(width: hitTarget, height: hitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(frame.point(for: stop))
                    .allowsHitTesting(false)
                    .zoomSource(stop.id, in: zoomNamespace)
                    .accessibilityLabel(label(for: stop, index: index))
                    .accessibilityAddTraits(stop.id == focusedStopID ? [.isButton, .isSelected] : .isButton)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { event in
                        guard let stop = frame.nearestStop(to: event.location, in: stops) else { return }
                        onSelect(stop)
                    }
            )
        }
        .task {
            guard !reduceMotion else { return }
            threadProgress = 0
            try? await Task.sleep(nanoseconds: 80_000_000)
            withAnimation(AppMotion.thread) { threadProgress = 1 }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Drawing

    private func base(_ context: inout GraphicsContext, size: CGSize, frame: PlotFrame) {
        guard !stops.isEmpty else { return }

        sheet(context: &context, size: size, frame: frame)
        scaleBar(context: &context, size: size, frame: frame)
    }

    private func marks(_ context: inout GraphicsContext, size: CGSize, frame: PlotFrame) {
        guard !stops.isEmpty else { return }

        markers(context: &context, size: size, frame: frame)
        focusedCallout(context: &context, size: size, frame: frame)
    }

    /// The surveyed sheet: a quiet lighter plane with registration corners, so the
    /// plot reads as a sheet on the card rather than a hole in it. No grid.
    private func sheet(context: inout GraphicsContext, size: CGSize, frame: PlotFrame) {
        let rect = frame.sheetRect(clampedTo: size)
        guard rect.width > 20, rect.height > 20 else { return }

        let sheet = Path(roundedRect: rect, cornerRadius: 6, style: .continuous)
        context.fill(sheet, with: .color(AppTheme.surfaceLow.opacity(0.85)))
        context.stroke(sheet, with: .color(AppTheme.ink.opacity(0.07)), lineWidth: 1)

        let tick: CGFloat = 13
        let tone = AppTheme.ink.opacity(0.24)
        for corner in corners(of: rect) {
            var mark = Path()
            mark.move(to: CGPoint(x: corner.point.x, y: corner.point.y + corner.ySign * tick))
            mark.addLine(to: corner.point)
            mark.addLine(to: CGPoint(x: corner.point.x + corner.xSign * tick, y: corner.point.y))
            context.stroke(
                mark,
                with: .color(tone),
                style: StrokeStyle(lineWidth: 1, lineCap: .square, lineJoin: .miter)
            )
        }
    }

    private func markers(context: inout GraphicsContext, size: CGSize, frame: PlotFrame) {
        let number = frame.numbering(for: route, numbered: route.count <= maxNumberedPins)

        // First pass: a paper halo under every pin, so pins that sit close together
        // stay two pins instead of merging into one blob.
        for stop in stops {
            let point = frame.point(for: stop)
            let halo = Path(ellipseIn: CGRect(x: point.x - 6.5, y: point.y - 6.5, width: 13, height: 13))
            context.fill(halo, with: .color(AppTheme.surface))
        }

        for stop in stops {
            let point = frame.point(for: stop)
            let tone = state(stop).tone
            let isFocused = stop.id == focusedStopID
            let radius: CGFloat = isFocused ? 4.5 : 3.8

            if isFocused {
                let ring = Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18))
                context.stroke(ring, with: .color(AppTheme.ink), lineWidth: 1.6)
            }

            let dot = Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
            context.fill(dot, with: .color(tone))

            guard let index = number[stop.id],
                  let marker = numberAnchor(at: point, frame: frame, in: size) else {
                continue
            }
            context.draw(
                Text("\(index)")
                    .font(AppType.micro)
                    .foregroundStyle(isFocused ? AppTheme.ink : AppTheme.inkSoft),
                at: marker,
                anchor: .center
            )
        }
    }

    /// The focused household is the only named point on the sheet: everywhere else a
    /// number is enough, because the index below the plot carries the names.
    private func focusedCallout(context: inout GraphicsContext, size: CGSize, frame: PlotFrame) {
        guard let focused = stops.first(where: { $0.id == focusedStopID }) else { return }

        let point = frame.point(for: focused)
        let text = context.resolve(
            Text(focused.nickname)
                .font(AppType.micro)
                .foregroundStyle(AppTheme.ink)
        )
        let measured = text.measure(in: CGSize(width: 260, height: 60))
        guard measured.width > 0 else { return }

        let gap: CGFloat = 11
        let placeLeft = point.x > size.width - inset * 2.6
        var originX = placeLeft ? point.x - gap - measured.width : point.x + gap
        originX = min(max(6, originX), size.width - measured.width - 6)
        var originY = point.y - 24
        originY = min(max(6, originY), size.height - measured.height - 6)

        var leader = Path()
        leader.move(to: CGPoint(x: point.x, y: point.y - 7))
        leader.addLine(to: CGPoint(x: placeLeft ? originX + measured.width + 4 : originX - 4, y: originY + measured.height / 2))
        context.stroke(
            leader,
            with: .color(AppTheme.ink.opacity(0.34)),
            style: StrokeStyle(lineWidth: 1, lineCap: .round)
        )
        context.draw(text, at: CGPoint(x: originX, y: originY), anchor: .topLeading)
    }

    /// Real metres, so the plot is a measurement and not a mood.
    private func scaleBar(context: inout GraphicsContext, size: CGSize, frame: PlotFrame) {
        guard let metres = frame.niceScaleMetres(), frame.metresPerPoint > 0 else { return }
        let width = CGFloat(Double(metres) / frame.metresPerPoint)
        guard width > 14, width < size.width - 40 else { return }

        let y = size.height - 13
        let start = CGPoint(x: 14, y: y)
        let end = CGPoint(x: 14 + width, y: y)

        var bar = Path()
        bar.move(to: CGPoint(x: start.x, y: y - 4))
        bar.addLine(to: CGPoint(x: start.x, y: y + 4))
        bar.move(to: start)
        bar.addLine(to: end)
        bar.move(to: CGPoint(x: end.x, y: y - 4))
        bar.addLine(to: CGPoint(x: end.x, y: y + 4))
        context.stroke(bar, with: .color(AppTheme.ink.opacity(0.5)), style: StrokeStyle(lineWidth: 1, lineCap: .square))

        context.draw(
            Text("\(metres) m").font(AppType.micro).foregroundStyle(AppTheme.inkSoft),
            at: CGPoint(x: end.x + 7, y: y),
            anchor: .leading
        )
    }

    // MARK: - Geometry helpers

    private func corners(of rect: CGRect) -> [(point: CGPoint, xSign: CGFloat, ySign: CGFloat)] {
        [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1)
        ]
    }

    /// Numbers sit on an eight-point compass around their pin, so a dense block stays
    /// legible instead of printing a ring of digits over itself.
    private func numberAnchor(at point: CGPoint, frame: PlotFrame, in size: CGSize) -> CGPoint? {
        let centre = frame.centre
        let dx = point.x - centre.x
        let dy = point.y - centre.y
        let angle: CGFloat
        if abs(dx) < 0.5 && abs(dy) < 0.5 {
            angle = 0
        } else {
            let raw = atan2(dy, dx)
            angle = (raw / (.pi / 4)).rounded() * (.pi / 4)
        }
        let distance: CGFloat = 11.5
        let candidate = CGPoint(x: point.x + cos(angle) * distance, y: point.y + sin(angle) * distance)
        guard candidate.x > 8, candidate.x < size.width - 8, candidate.y > 8, candidate.y < size.height - 6 else {
            return nil
        }
        return candidate
    }

    private func label(for stop: VisitStop, index: Int) -> String {
        let stopState = state(stop)
        let walk = route.firstIndex { $0.id == stop.id }
        let prefix = walk.map { "Stop \($0 + 1)," } ?? "Pin \(index + 1),"
        return "\(prefix) \(stop.nickname). \(stopState.title), visited \(stop.lastVisitDayOffset) days ago on a \(stop.cadenceDays) day cadence. Window \(stop.windowStartHour) to \(stop.windowEndHour)."
    }
}

private struct RouteThread: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

/// Equirectangular projection of stored coordinates into the sheet, aspect-true, so
/// the picture keeps the walk's real proportions instead of stretching to the card.
struct PlotFrame {
    let scale: CGFloat
    let originX: CGFloat
    let originY: CGFloat
    let cosLat: Double
    let metresPerPoint: Double
    let centre: CGPoint
    private let bounds: CGRect

    init(stops: [VisitStop], size: CGSize, inset: CGFloat) {
        let lats = stops.map(\.lat)
        let lons = stops.map(\.lon)
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0

        let cosLat = cos(((minLat + maxLat) / 2) * .pi / 180)
        // A single pin, or pins stacked on one street, still needs a scale: hold a
        // floor of ~45 m of span so one household does not explode to fill the sheet.
        let spanX = max((maxLon - minLon) * cosLat, 0.0004)
        let spanY = max(maxLat - minLat, 0.0004)

        let availableWidth = max(size.width - inset * 2, 1)
        let availableHeight = max(size.height - inset * 2, 1)
        let scale = min(availableWidth / spanX, availableHeight / spanY)

        self.scale = scale
        self.cosLat = cosLat
        originX = inset + (availableWidth - spanX * scale) / 2
        // Latitude grows upward, screen y grows down: maxLat sits on the top edge.
        originY = inset + (availableHeight - spanY * scale) / 2
        metresPerPoint = 111_320 / Double(scale)
        centre = CGPoint(x: originX + spanX * scale / 2, y: originY + spanY * scale / 2)
        bounds = CGRect(
            x: minLon,
            y: minLat,
            width: max(maxLon - minLon, 0),
            height: max(maxLat - minLat, 0)
        )
    }

    func point(for stop: VisitStop) -> CGPoint {
        CGPoint(
            x: originX + CGFloat((stop.lon - bounds.minX) * cosLat) * scale,
            y: originY + CGFloat(bounds.maxY - stop.lat) * scale
        )
    }

    /// The pin a tap meant. Nearest wins, not topmost in the view tree, and a tap
    /// on open sheet focuses nothing rather than guessing at a household.
    func nearestStop(to point: CGPoint, in stops: [VisitStop], within limit: CGFloat = 40) -> VisitStop? {
        var best: (stop: VisitStop, distance: CGFloat)?
        for stop in stops {
            let pin = self.point(for: stop)
            let distance = hypot(pin.x - point.x, pin.y - point.y)
            if best == nil || distance < best!.distance {
                best = (stop, distance)
            }
        }
        guard let best, best.distance <= limit else { return nil }
        return best.stop
    }

    func points(for stops: [VisitStop]) -> [CGPoint] {
        stops.map(point(for:))
    }

    /// The sheet hugs the pins, with room for the halo and the ring.
    func sheetRect(clampedTo size: CGSize) -> CGRect {
        let padded = CGRect(
            x: originX - 20,
            y: originY - 20,
            width: CGFloat(bounds.width * cosLat) * scale + 40,
            height: CGFloat(bounds.height) * scale + 40
        )
        let limit = CGRect(origin: .zero, size: size).insetBy(dx: 7, dy: 7)
        return padded.intersection(limit)
    }

    /// Walk-order number per stop, only where the sheet can carry digits.
    func numbering(for route: [VisitStop], numbered: Bool) -> [String: Int] {
        guard numbered else { return [:] }
        var result: [String: Int] = [:]
        for (index, stop) in route.enumerated() where result[stop.id] == nil {
            result[stop.id] = index + 1
        }
        return result
    }

    /// A round metre figure for the scale bar: 1, 2, 5 × 10ⁿ, as on a real drawing.
    func niceScaleMetres() -> Int? {
        guard metresPerPoint > 0 else { return nil }
        let candidates = [25, 50, 100, 200, 250, 500, 1000, 2000, 5000, 10_000]
        let chosen = candidates.last { Double($0) / metresPerPoint <= 104 }
        return chosen
    }
}

#Preview {
    let stops = StoopBookSeed.stops
    let round = StoopBookSeed.rounds[0]
    let route = round.stopIds.compactMap { id in stops.first { $0.id == id } }
    return VStack(alignment: .leading, spacing: AppMetrics.contentSpacing) {
        RoutePlot(
            stops: route,
            route: route,
            focusedStopID: "visit-01",
            state: { $0.lastVisitDayOffset > $0.cadenceDays ? .overdue : ($0.lastVisitDayOffset == $0.cadenceDays ? .dueToday : .ahead) },
            onSelect: { _ in }
        )
        .frame(height: 240)
        .cardSurface(padding: 0)
    }
    .padding(AppMetrics.screenPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(AppBackground())
}
