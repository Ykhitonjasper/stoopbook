import SwiftUI

/// One rowhouse bay, measured the way an elevation drawing is measured.
///
/// Every part has a fixed size in design units off a forty-unit bay — a stone
/// base, a five-riser stoop with cheeks and rails, a raised doorway under a
/// transom and a hood, three window bays on two floors, a bracketed cornice — so
/// a house reads as a building instead of a stretched box. What a household has
/// been given shows in the band above the cornice line: the storey-and-parapet
/// region that differs from house to house on a real street.
///
/// Vertical measurements run up from the sidewalk, in design units.
struct FacadePlan {
    /// Design width of the bay. Every measurement below is in units of this.
    static let designWidth: CGFloat = 40
    static let corniceDepth: CGFloat = 4.2
    /// Top of the wall, above the second-floor lintels by a frieze course.
    static let wallTop: CGFloat = 55.2
    /// Everything always drawn: sidewalk to the top of the cornice.
    static let fixedHeight: CGFloat = wallTop + corniceDepth
    /// The tallest band a household is given above the cornice line. Wide enough
    /// that a street shows real variation in roofline: the shorter houses are a
    /// storey and a parapet, the longer ones carry a half-storey window up there.
    static let bandLimit: CGFloat = 22

    static let minRatio = fixedHeight / designWidth
    static let maxRatio = (fixedHeight + bandLimit) / designWidth

    static let parlorLevel: CGFloat = 13
    static let secondLevel: CGFloat = 34
    /// A window: sill above its floor, glass, then a lintel over the head.
    static let sillRise: CGFloat = 1.4
    static let sillDepth: CGFloat = 1.6
    static let glassHeight: CGFloat = 14.2
    static let lintelDepth: CGFloat = 2.2
    /// Doorway heads line up with the window heads.
    static let doorwayTop: CGFloat = parlorLevel + sillRise + sillDepth + glassHeight
    /// The leaf stops short of the head, leaving the transom light over it.
    static let doorLeafTop: CGFloat = doorwayTop - 2.5
    static let doorWidth: CGFloat = 9

    let width: CGFloat
    let height: CGFloat

    /// Points per design unit.
    var unit: CGFloat { width / Self.designWidth }
    /// The band above the cornice line, in design units.
    var band: CGFloat { max(0, (height - Self.fixedHeight * unit) / unit) }
    var corniceBottom: CGFloat { Self.wallTop + band }
    var corniceTop: CGFloat { corniceBottom + Self.corniceDepth }
    var bandCenter: CGFloat { (Self.wallTop + corniceBottom) / 2 }
    /// A house given room above its cornice line gets a half-storey window there.
    var hasAtticWindow: Bool { band >= 11 }

    func windowTop(level: CGFloat) -> CGFloat {
        level + Self.sillRise + Self.sillDepth + Self.glassHeight
    }
}

/// The rowhouse mark. Drawn, never assembled from a glyph, and never the same
/// silhouette twice on a street: height is the household's dwell, the cornice
/// carries its cadence state, and the house a person is on takes ink from the
/// sidewalk up, every mark it crosses turning to paper as the ink passes.
struct RowhouseMark: View {
    let width: CGFloat
    let height: CGFloat
    var focused = false
    var roofTone: Color = AppTheme.ink

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Nil until the mark has decided: the house renders complete on its first
    /// frame instead of waiting for an animation to give it its ink.
    @State private var settle: CGFloat?

    static func height(width: CGFloat, dwellFraction: CGFloat) -> CGFloat {
        let t = min(max(dwellFraction, 0), 1)
        let ratio = FacadePlan.minRatio + (FacadePlan.maxRatio - FacadePlan.minRatio) * t
        return width * ratio
    }

    static func maxHeight(width: CGFloat) -> CGFloat { width * FacadePlan.maxRatio }

    /// Dwell against the range the street reads it in: twenty minutes to seventy.
    static func dwellFraction(dwellMinutes: Int) -> CGFloat {
        let dwell = min(max(dwellMinutes, 20), 70)
        return CGFloat(dwell - 20) / 50
    }

    /// The gap in days the street writes beside a roof, signed by which way it points.
    static func dayCaption(state: CadenceState, lastVisitDayOffset: Int, cadenceDays: Int) -> String {
        switch state {
        case .overdue: return "\(max(0, lastVisitDayOffset - cadenceDays))d over"
        case .dueToday: return "today"
        case .ahead: return "\(max(0, cadenceDays - lastVisitDayOffset))d left"
        }
    }

    var body: some View {
        let inkRise = settle ?? (focused ? 1 : 0)
        Canvas { context, size in
            draw(inkRise: inkRise, size: size, context: context)
        }
        .frame(width: width, height: height)
        .onAppear {
            settle = focused ? 1 : 0
        }
        .onChange(of: focused) { _, isFocused in
            guard !reduceMotion else {
                settle = isFocused ? 1 : 0
                return
            }
            withAnimation(AppMotion.fill) {
                settle = isFocused ? 1 : 0
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Drawing

    private func draw(inkRise: CGFloat, size: CGSize, context: GraphicsContext) {
        let plan = FacadePlan(width: size.width, height: size.height)
        let scale = displayScale
        /// Pen weights are whole device pixels, so a hairline stays a line rather
        /// than a grey smear at any display scale.
        func pen(_ pixels: CGFloat) -> CGFloat { pixels / scale }
        let hair = pen(1)
        let edge = pen(2)
        let wall = pen(3)

        /// Snapped to the device grid, so drawn edges land on pixels.
        func px(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }
        /// Points in design units, for the hairline weights that do not scale with
        /// the bay: a course line is a course line on every house on the street.
        func thin(_ points: CGFloat) -> CGFloat { points / plan.unit }

        /// A box in design units: x across from the party wall, y up from the sidewalk.
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            let u = plan.unit
            let left = px(x * u)
            let right = px((x + w) * u)
            let top = px(size.height - (y + h) * u)
            let bottom = px(size.height - y * u)
            return CGRect(x: left, y: top, width: max(0, right - left), height: max(0, bottom - top))
        }

        let body = box(1, 0, 38, plan.corniceBottom)
        let inkLine = px(body.maxY - body.height * inkRise)

        /// Ink laid over a shape, never past the line it has risen to.
        func inked(_ path: Path) {
            var layer = context
            layer.clip(to: Path(CGRect(x: 0, y: inkLine, width: size.width, height: size.height - inkLine + 1)))
            layer.fill(path, with: .color(AppTheme.ink))
        }

        /// A wall or a solid mass: its own light tone until it is the house in
        /// hand, ink once it is, without losing the marks drawn over it.
        func mass(_ path: Path, tone: Color, inksWithWall: Bool = true) {
            context.fill(path, with: .color(tone))
            guard inksWithWall, focused, inkRise > 0 else { return }
            inked(path)
        }
        func mass(_ rect: CGRect, tone: Color, inksWithWall: Bool = true) {
            mass(Path(rect), tone: tone, inksWithWall: inksWithWall)
        }

        /// A mark on the wall: ink, or paper once ink has risen under it.
        func mark(_ rect: CGRect, ink inkOpacity: CGFloat, paper paperOpacity: CGFloat) -> Color {
            if focused, inkRise > 0, rect.midY > inkLine {
                return AppTheme.paper.opacity(paperOpacity)
            }
            return AppTheme.ink.opacity(inkOpacity)
        }
        /// A measured band: sills, lintels, hood, risers, sash bars.
        func band(_ rect: CGRect, ink inkOpacity: CGFloat, paper paperOpacity: CGFloat = 0.85) {
            context.fill(Path(rect), with: .color(mark(rect, ink: inkOpacity, paper: paperOpacity)))
        }
        /// A drawn edge, built from filled bands so corners close and nothing
        /// spills past the box it belongs to.
        func ruled(_ rect: CGRect, thickness: CGFloat, ink inkOpacity: CGFloat, paper paperOpacity: CGFloat = 0.92) {
            let t = max(thickness, 1 / scale)
            let bands = [
                CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: t),
                CGRect(x: rect.minX, y: rect.maxY - t, width: rect.width, height: t),
                CGRect(x: rect.minX, y: rect.minY + t, width: t, height: rect.height - 2 * t),
                CGRect(x: rect.maxX - t, y: rect.minY + t, width: t, height: rect.height - 2 * t)
            ]
            for piece in bands where piece.width > 0 && piece.height > 0 {
                band(piece, ink: inkOpacity, paper: paperOpacity)
            }
        }

        // MARK: Masonry
        mass(body, tone: AppTheme.surface)
        ruled(body, thickness: wall, ink: 0.66)

        // Stone base at grade, with its plinth course.
        let base = box(0.5, 0, 39, 5.2)
        mass(base, tone: AppTheme.surfaceLow)
        band(box(0.5, 5.05, 39, thin(hair)), ink: 0.42)
        band(box(0.5, 1.1, 39, thin(hair)), ink: 0.28)

        // MARK: Window bays on both floors, the doorway taking the first bay below
        let bayCenters: [CGFloat] = [6.667, 20, 33.333]
        let glassWidth: CGFloat = 7.6

        func window(level: CGFloat, center: CGFloat) {
            let sill = level + FacadePlan.sillRise
            let glass = box(center - glassWidth / 2, sill + FacadePlan.sillDepth,
                            glassWidth, FacadePlan.glassHeight)
            band(box(center - glassWidth / 2 - 0.75, sill, glassWidth + 1.5, FacadePlan.sillDepth), ink: 0.42)
            mass(glass, tone: AppTheme.surfaceLow)
            ruled(glass, thickness: edge, ink: 0.6)
            // The sash: a meeting rail across the middle, a bar in each light.
            let railY = sill + FacadePlan.sillDepth + FacadePlan.glassHeight / 2
            band(box(center - glassWidth / 2, railY - thin(hair) / 2, glassWidth, thin(hair)), ink: 0.5)
            band(box(center - 0.3, sill + FacadePlan.sillDepth, 0.6, FacadePlan.glassHeight), ink: 0.34)
            band(box(center - glassWidth / 2 - 0.55, sill + FacadePlan.sillDepth, 0.55, FacadePlan.glassHeight), ink: 0.26)
            band(box(center + glassWidth / 2, sill + FacadePlan.sillDepth, 0.55, FacadePlan.glassHeight), ink: 0.26)
            band(box(center - glassWidth / 2 - 1.1, plan.windowTop(level: level),
                     glassWidth + 2.2, FacadePlan.lintelDepth), ink: 0.46)
        }

        for level in [FacadePlan.parlorLevel, FacadePlan.secondLevel] {
            for center in bayCenters {
                if level == FacadePlan.parlorLevel, center == bayCenters[0] { continue }
                window(level: level, center: center)
            }
        }

        // MARK: Doorway: a panelled door, its transom light, and the hood over both
        let doorCenter = bayCenters[0]
        let doorTop = FacadePlan.doorLeafTop
        let doorway = box(doorCenter - FacadePlan.doorWidth / 2, FacadePlan.parlorLevel,
                          FacadePlan.doorWidth, FacadePlan.doorwayTop - FacadePlan.parlorLevel)
        mass(doorway, tone: AppTheme.surfaceLow)
        ruled(doorway, thickness: edge, ink: 0.72)

        // Two sunk panels on the leaf, and the handle beside them.
        let leafBottom = FacadePlan.parlorLevel + 0.9
        let leafHeight = doorTop - leafBottom - 0.6
        band(box(doorCenter - 2.3, leafBottom + leafHeight * 0.55, 4.6, leafHeight * 0.38), ink: 0.22)
        band(box(doorCenter - 2.3, leafBottom, 4.6, leafHeight * 0.45), ink: 0.3)
        band(box(doorCenter + 3.1, leafBottom + leafHeight * 0.52, 0.85, 0.85), ink: 0.6)
        // The transom bar, then the light over it with two mullions.
        band(box(doorCenter - 4, doorTop - 0.35, 8, 0.7), ink: 0.5)
        for mullion in [-2.5, 1.6] {
            band(box(doorCenter + mullion, doorTop + 0.4, 0.6, FacadePlan.doorwayTop - doorTop - 0.8),
                 ink: 0.34)
        }

        let hood = box(doorCenter - FacadePlan.doorWidth / 2 - 1.1, FacadePlan.doorwayTop,
                       FacadePlan.doorWidth + 2.2, 2.4)
        band(hood, ink: 0.46)

        // MARK: Attic window, when the household was given the room above the cornice
        if plan.hasAtticWindow {
            let glass = box(20 - 2.2, plan.bandCenter - 2.6, 4.4, 5.2)
            mass(glass, tone: AppTheme.surfaceLow)
            ruled(glass, thickness: edge, ink: 0.6)
            band(box(20 - 0.3, plan.bandCenter - 2.6, 0.6, 5.2), ink: 0.34)
            band(box(20 - 3, plan.bandCenter + 2.6, 6, 1.1), ink: 0.42)
            band(box(20 - 3, plan.bandCenter - 3.7, 6, 1.1), ink: 0.42)
        }

        // MARK: Cornice: fascia, painted band, coping, brackets
        // The cornice keeps its cadence tone even on the house in hand: the ink
        // says which house this is, the paint still says how it is doing.
        let cornice = box(0, plan.corniceBottom, 40, FacadePlan.corniceDepth)
        mass(cornice, tone: roofTone, inksWithWall: false)
        band(box(0, plan.corniceTop - 0.9, 40, 0.9), ink: 0.5, paper: 0.6)
        band(box(0, plan.corniceBottom, 40, thin(hair)), ink: 0.3)
        for center in [1.6, 6.667, 20, 33.333, 38.4] {
            band(box(center - 0.55, plan.corniceBottom - 2.6, 1.1, 2.6), ink: 0.44)
        }

        // MARK: Stoop: five risers, cheeks, nosings, rails and newels
        let stoopPath = Path { path in
            let u = plan.unit
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: px(x * u), y: px(size.height - y * u))
            }
            path.move(to: point(0.8, 0))
            path.addLine(to: point(14.2, 0))
            path.addLine(to: point(12.9, FacadePlan.parlorLevel))
            path.addLine(to: point(2.1, FacadePlan.parlorLevel))
            path.closeSubpath()
        }
        mass(stoopPath, tone: AppTheme.surfaceLow)
        context.stroke(
            stoopPath,
            with: .color(mark(stoopPath.boundingRect, ink: 0.58, paper: 0.92)),
            lineWidth: edge
        )

        for step in 1...4 {
            let y = CGFloat(step) * 2.6
            let left = 0.8 + 0.1 * y
            let right = 14.2 - 0.1 * y
            band(box(left - 0.35, y - 0.4, right - left + 0.7, 0.4), ink: 0.42)
            band(box(left - 0.1, y + 0.75, right - left + 0.2, 0.35), ink: 0.2)
        }

        // Held on both sides, the way a stoop is.
        for side in [-1, 1] as [CGFloat] {
            let outer: CGFloat = side < 0 ? 1.5 : 13.5
            let inner: CGFloat = side < 0 ? 2.9 : 12.1
            var rail = Path()
            rail.move(to: CGPoint(x: px(outer * plan.unit), y: px(size.height - 1.6 * plan.unit)))
            rail.addLine(to: CGPoint(x: px(inner * plan.unit), y: px(size.height - 13.8 * plan.unit)))
            context.stroke(
                rail,
                with: .color(mark(rail.boundingRect, ink: 0.7, paper: 0.95)),
                style: StrokeStyle(lineWidth: edge, lineCap: .round)
            )
            band(box(side < 0 ? 2.4 : 11.6, 10.6, 1, 3.2), ink: 0.74)
        }
    }
}

/// One household of a walk, drawn the way the street line draws a house: the
/// elevation mark, its cadence roof, and the number of days beside it. The small
/// counterpoint to `StreetLine` — one house at index size, wherever the book needs
/// a household to stand on the page instead of a line of ledger text.
struct HouseholdLine: View {
    let index: Int
    let stop: VisitStop
    let state: CadenceState
    /// The last closed visit at this door, when it ended without a made visit.
    var outcome: VisitOutcome?

    var body: some View {
        HStack(alignment: .bottom, spacing: 9) {
            RowhouseMark(
                width: 34,
                height: RowhouseMark.height(width: 34, dwellFraction: fraction),
                roofTone: state.tone
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.nickname)
                    .font(AppType.rowStrong)
                    .foregroundStyle(AppTheme.ink)
                HStack(spacing: 5) {
                    Text("\(index). \(stop.floor) floor")
                        .font(AppType.micro)
                        .foregroundStyle(AppTheme.inkSoft)
                    if let outcome {
                        Label(outcome.title, systemImage: outcome.glyph)
                            .font(AppType.micro)
                            .foregroundStyle(AppTheme.rust)
                    }
                }
            }

            Spacer(minLength: 10)

            Text(RowhouseMark.dayCaption(state: state, lastVisitDayOffset: stop.lastVisitDayOffset, cadenceDays: stop.cadenceDays))
                .font(AppType.micro)
                .foregroundStyle(state.tone)
        }
        .accessibilityElement(children: .combine)
    }

    private var fraction: CGFloat {
        let dwell = min(max(stop.dwellMinutes, 20), 70)
        return CGFloat(dwell - 20) / 50
    }
}

/// One house of a walk, in the shape the book stores it in.
struct StreetHouse: Identifiable {
    let id: String
    let roofTone: Color
    let dwellFraction: CGFloat
    let caption: String
    let captionTone: Color
}

/// A walk drawn as the street it is: the same elevation marks as the morning
/// line, at index size, flowing onto as many rows as the walk needs. Cadence sits
/// on the roofs, days over each one, the brass route thread along the sidewalk.
/// Where a book lists circuits, this is what a circuit looks like.
struct HouseStreet: View {
    let houses: [StreetHouse]
    var showsSidewalk = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var thread: CGFloat = 1

    static let houseWidth: CGFloat = 46
    static let houseGap: CGFloat = 2
    static var houseHeight: CGFloat { RowhouseMark.maxHeight(width: houseWidth) }
    private static let rowSpacing: CGFloat = 5
    private static let captionHeight: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            let column = min(Self.houseWidth + Self.houseGap, proxy.size.width / CGFloat(max(houses.count, 1)))
            let perRow = max(1, Int(proxy.size.width / column))
            let rows = stride(from: 0, to: houses.count, by: perRow).map { offset in
                Array(houses[offset..<min(offset + perRow, houses.count)])
            }

            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(row) { house in
                            VStack(spacing: 2) {
                                Text(house.caption)
                                    .font(AppType.micro)
                                    .foregroundStyle(house.captionTone)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(height: Self.captionHeight, alignment: .bottom)
                                RowhouseMark(
                                    width: Self.houseWidth,
                                    height: RowhouseMark.height(width: Self.houseWidth, dwellFraction: house.dwellFraction),
                                    roofTone: house.roofTone
                                )
                            }
                            .frame(width: column, alignment: .center)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            .background(alignment: .bottom) {
                if showsSidewalk, houses.count > 1 {
                    Capsule()
                        .trim(from: 0, to: thread)
                        .fill(AppTheme.brass)
                        .frame(width: proxy.size.width, height: 1.4)
                }
            }
        }
        .frame(height: Self.height(houseCount: houses.count))
        .task {
            guard !reduceMotion else { return }
            thread = 0
            try? await Task.sleep(nanoseconds: 80_000_000)
            withAnimation(AppMotion.thread) { thread = 1 }
        }
        .accessibilityHidden(true)
    }

    static func height(houseCount: Int) -> CGFloat {
        guard houseCount > 0 else { return houseHeight }
        let perRow = 6
        let rows = Int(ceil(Double(houseCount) / Double(perRow)))
        return CGFloat(rows) * (captionHeight + houseHeight) + CGFloat(rows - 1) * rowSpacing + (houseCount > 1 ? 3 : 0)
    }
}

#Preview {
    // One house at the range a household can be given, plus the one in hand.
    HStack(alignment: .bottom, spacing: 14) {
        ForEach(Array(stride(from: 0.0, through: 1.0, by: 0.25)), id: \.self) { fraction in
            RowhouseMark(
                width: 40,
                height: RowhouseMark.height(width: 40, dwellFraction: fraction),
                focused: fraction == 0.5,
                roofTone: fraction > 0.5 ? AppTheme.rust : AppTheme.sage
            )
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .padding(.bottom, 60)
    .background(AppBackground())
}
