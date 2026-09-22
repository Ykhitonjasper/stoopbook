import SwiftUI

@MainActor
struct ReadingDetailScreen: View {
    private let dependencies: AppDependencies
    @Bindable private var store: StoopBookStore
    @State private var viewModel: ReadingDetailViewModel

    init(readingID: String, dependencies: AppDependencies) {
        self.dependencies = dependencies
        store = dependencies.store
        _viewModel = State(initialValue: ReadingDetailViewModel(readingID: readingID, dependencies: dependencies))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScreenScaffold {
            ScreenHeader(subtitle: viewModel.headerSubtitle)

            if viewModel.viewState.showsPlaceholder {
                emptyState
            } else {
                loadedBody(viewModel: viewModel)
            }
        }
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $viewModel.opened) { presented in
            destination(for: presented.route)
        }
        .sensoryFeedback(.selection, trigger: viewModel.selectedStopID)
        .sensoryFeedback(.success, trigger: viewModel.openCount)
        .task {
            viewModel.refresh()
        }
    }

    @ViewBuilder
    private func loadedBody(viewModel: ReadingDetailViewModel) -> some View {
        if let reading = viewModel.reading {
            FieldReadout(
                label: reading.kind.title,
                value: viewModel.primaryDisplay,
                unit: viewModel.unit(for: reading.kind),
                context: reading.readout,
                note: viewModel.readoutNote(lastSavedID: store.lastSavedReadingID)
            )
            .accessibilityIdentifier("smoke.readingDetail.savedReadout")

            SectionCard(title: "Entry") {
                LedgerRow(label: "Kit", value: reading.kind.title)
                LedgerRow(label: "Captured", value: viewModel.dayCaption(reading.capturedDayOffset))
                LedgerRow(label: "Circuit", value: viewModel.runTitle)
                LedgerRow(label: "Households", value: "\(viewModel.attachedStops.count)")
                DetailRow(label: "Received", value: viewModel.runTitle)
                DetailRow(label: "Note", value: viewModel.justSavedBanner(lastSavedID: store.lastSavedReadingID))
            }

            SectionLabel(title: "Households on it", detail: "\(viewModel.attachedStops.count)")

            SectionCard {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.attachedStops.enumerated()), id: \.element.id) { index, stop in
                        if index > 0 { IndexRule() }

                        VStack(alignment: .leading, spacing: 7) {
                            IndexRow(
                                title: stop.nickname,
                                detail: viewModel.windowLabel(for: stop),
                                trailing: viewModel.cadenceTitle(for: stop),
                                accentTone: viewModel.cadenceState(for: stop).tone
                            ) {
                                viewModel.selectStop(stop.id)
                            }

                            LedgerRow(
                                label: "Cadence",
                                value: "\(stop.lastVisitDayOffset)d of \(stop.cadenceDays)d",
                                tone: viewModel.cadenceState(for: stop).tone
                            )
                            LedgerRow(label: "Dwell", value: "\(stop.dwellMinutes) min")
                            DetailRow(label: "Entry", value: "\(stop.floor) · \(stop.entryNote)")
                            DetailRow(label: "Pet", value: stop.petNote)
                            DetailRow(label: "Parking", value: stop.parkingNote)
                        }
                        .padding(.bottom, 4)
                    }
                }
            }

            if viewModel.travelLegs.isEmpty {
                SectionCard(title: "Travel") {
                    DetailRow(label: "Legs", value: "None. One household is one stop.", isProminent: true)
                    DetailRow(
                        label: "Stored pin",
                        value: viewModel.attachedStops.first.map { viewModel.pinCaption($0) } ?? "No pin"
                    )
                }
            } else {
                SectionCard(title: "Travel between households") {
                    ForEach(viewModel.travelLegs) { leg in
                        LedgerRow(label: leg.title, value: "\(leg.minutes) min")
                        DetailRow(label: "Bin", value: leg.binTitle, isProminent: true)
                        DetailRow(label: "Stored span", value: leg.metresCaption)
                    }
                }
            }

            if let pair = viewModel.matchingPair {
                SectionCard {
                    IndexRow(
                        title: pair.label,
                        detail: "This readout is one half of the pair.",
                        trailing: "compare"
                    ) {
                        viewModel.openCompare(pair.id)
                    }
                }
            }

            CTAButton(
                title: viewModel.mapCTATitle,
                systemImage: "mappin.and.ellipse",
                hint: "Opens the linked stoop on the visit map."
            ) {
                viewModel.openLinkedStoop()
            }
            .accessibilityIdentifier("smoke.readingDetail.showSavedReadout")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
            EmptyStateCard(
                title: "Readout not on this phone",
                message: "That readout is not in the visit book. The Tuesday North Loop cadence line is a saved one.",
                systemImage: "list.bullet.rectangle",
                actionTitle: "Open Tuesday cadence"
            ) {
                viewModel.showSeededReadout()
            }

            SectionCard(title: "Asked for") {
                LedgerRow(label: "Reading", value: viewModel.readingID, tone: AppTheme.ink)
                LedgerRow(label: "Last saved", value: store.lastSavedReadingID ?? "none")
                LedgerRow(label: "Focused", value: store.focusedStopID ?? "none")
                LedgerRow(label: "Round", value: store.selectedRound.name)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .comparePair(let pairID):
            CompareReadingsScreen(pairID: pairID, dependencies: dependencies)
        case .readingDetail(let readingID):
            ReadingDetailScreen(readingID: readingID, dependencies: dependencies)
        case .kit, .saveDraft, .stopDetail, .exportPack, .roundBuilder:
            EmptyView()
        }
    }
}

private struct TravelLeg: Identifiable, Hashable {
    let id: String
    let title: String
    let binTitle: String
    let minutes: Int
    let metresCaption: String
}

private struct PresentedDetailRoute: Identifiable, Hashable {
    let route: AppRoute

    var id: String {
        switch route {
        case .kit(let kind):
            return "kit-\(kind.rawValue)"
        case .saveDraft(let draft):
            return "saveDraft-\(draft.id)"
        case .readingDetail(let value):
            return "readingDetail-\(value)"
        case .comparePair(let value):
            return "compare-\(value)"
        case .stopDetail(let value):
            return "stop-\(value)"
        case .exportPack(let value):
            return "export-\(value)"
        case .roundBuilder(let value):
            return "roundBuilder-\(value)"
        }
    }
}

@MainActor
@Observable
private final class ReadingDetailViewModel {
    let dependencies: AppDependencies
    var readingID: String
    var selectedStopID: String
    var opened: PresentedDetailRoute?
    var pendingRoute: AppRoute?
    var openCount = 0

    init(readingID: String, dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.readingID = readingID
        selectedStopID = dependencies.store.focusedStopID ?? "visit-01"
        refreshSelection()
    }

    var store: StoopBookStore { dependencies.store }

    var reading: KitReading? {
        if let extra = store.extraReadings.first(where: { $0.id == readingID }) {
            return extra
        }
        return dependencies.readingRepository.reading(id: readingID)
    }

    var viewState: ViewState {
        reading == nil ? .empty : .loaded
    }

    var attachedStops: [VisitStop] {
        guard let reading else { return [] }
        return reading.stopIds.compactMap { dependencies.stopRepository.stop(id: $0) }
    }

    var primaryDisplay: String {
        guard let reading else { return "none" }
        return formatted(reading.primaryValue)
    }

    var runTitle: String {
        guard let reading else { return "No run" }
        if let run = resolvedRun(for: reading.runId) {
            return run.summary
        }
        return "an earlier circuit"
    }

    var headerSubtitle: String {
        if let reading {
            return reading.readout
        }
        return "The visit book does not have \(readingID)."
    }

    var navigationTitle: String {
        reading?.kind.title ?? "Visit"
    }

    var mapCTATitle: String {
        if let stop = linkedStop {
            return "Open \(stop.nickname)"
        }
        return "Open River Stoop 4B"
    }

    var linkedStop: VisitStop? {
        if let match = attachedStops.first(where: { $0.id == "visit-01" }) {
            return match
        }
        if let selected = attachedStops.first(where: { $0.id == selectedStopID }) {
            return selected
        }
        return attachedStops.first ?? dependencies.stopRepository.stop(id: "visit-01")
    }

    var matchingPair: ComparePair? {
        StoopBookSeed.comparePairs.first { pair in
            pair.firstReadingID == readingID || pair.secondReadingID == readingID
        }
    }

    var travelLegs: [TravelLeg] {
        guard attachedStops.count > 1 else { return [] }
        var legs: [TravelLeg] = []
        for index in 0..<(attachedStops.count - 1) {
            let from = attachedStops[index]
            let to = attachedStops[index + 1]
            let bin = dependencies.readingEngine.pinTravel(from: from, to: to)
            let metres = dependencies.readingEngine.haversineMetres(
                originLat: from.lat,
                originLon: from.lon,
                targetLat: to.lat,
                targetLon: to.lon
            )
            let minutes = dependencies.patrolEngine.planningMinutes(for: bin)
            legs.append(
                TravelLeg(
                    id: "\(from.id).\(to.id)",
                    title: "\(from.nickname) → \(to.nickname)",
                    binTitle: bin.title,
                    minutes: minutes,
                    metresCaption: metresCaption(metres)
                )
            )
        }
        return legs
    }

    func refresh() {
        refreshSelection()
    }

    func showSeededReadout() {
        readingID = "reading-01"
        refreshSelection()
    }

    func selectStop(_ stopID: String) {
        selectedStopID = stopID
        store.focusStop(stopID)
    }

    func openLinkedStoop() {
        let stopID = linkedStop?.id ?? "visit-01"
        store.focusStop(stopID)
        store.selectedTab = .maps
        pendingRoute = .stopDetail(stopID)
        openCount += 1
    }

    func openCompare(_ pairID: String) {
        let route = AppRoute.comparePair(pairID)
        pendingRoute = route
        opened = PresentedDetailRoute(route: route)
        openCount += 1
    }

    func readoutNote(lastSavedID: String?) -> String {
        guard let reading else { return "" }
        if lastSavedID == reading.id {
            return "Just saved onto \(runTitle)."
        }
        let count = reading.stopIds.count
        return "\(count == 1 ? "1 household" : "\(count) households") · \(runTitle)"
    }

    func justSavedBanner(lastSavedID: String?) -> String {
        guard let reading else { return "" }
        if lastSavedID == reading.id {
            return "Stored on the active circuit."
        }
        return reading.note
    }

    func cadenceTitle(for stop: VisitStop) -> String {
        dependencies.readingEngine.cadenceState(for: dependencies.store.resolvedStop(stop)).title
    }

    func cadenceState(for stop: VisitStop) -> CadenceState {
        dependencies.readingEngine.cadenceState(for: stop)
    }

    func cadenceLine(for stop: VisitStop) -> String {
        let state = dependencies.readingEngine.cadenceState(for: stop)
        return "\(state.title) · last visit \(stop.lastVisitDayOffset)d · every \(stop.cadenceDays)d"
    }

    func isOverdue(_ stop: VisitStop) -> Bool {
        dependencies.readingEngine.cadenceState(for: stop) == .overdue
    }

    func windowLabel(for stop: VisitStop) -> String {
        "\(clockHour(stop.windowStartHour))–\(clockHour(stop.windowEndHour)) · \(stop.dwellMinutes) min dwell"
    }

    func pinCaption(_ stop: VisitStop) -> String {
        "\(formatCoord(stop.lat)), \(formatCoord(stop.lon))"
    }

    func dayCaption(_ offset: Int) -> String {
        if offset == 0 { return "Today" }
        if offset == 1 { return "1 day ago" }
        return "\(offset) days ago"
    }

    func unit(for kind: VisitKitKind) -> String? {
        switch kind {
        case .cadence: return "overdue"
        case .windowFit: return nil
        case .pinTravel: return "min"
        case .cluster: return "stoops"
        case .accessNotes: return nil
        case .roundLoad: return "min"
        case .skipCost: return "days"
        }
    }

    private func refreshSelection() {
        if let first = reading?.stopIds.first {
            if reading?.stopIds.contains(selectedStopID) == false {
                selectedStopID = first
            }
        }
    }

    /// The circuit a run belongs to, named the way the book names rounds.
    func circuitTitle(for runID: String) -> String {
        guard let run = resolvedRun(for: runID),
              let round = dependencies.roundRepository.round(id: run.roundId) else {
            return "an earlier circuit"
        }
        return round.name
    }

    private func resolvedRun(for runID: String) -> PatrolRun? {
        if store.activeRun?.id == runID {
            return store.activeRun
        }
        return dependencies.runRepository.run(id: runID)
    }

    private func formatted(_ value: Double) -> String {
        let rounded = value.rounded()
        if value == rounded {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", value)
    }

    private func metresCaption(_ metres: Double) -> String {
        let whole = Int(metres.rounded())
        return "\(whole) m stored"
    }

    private func formatCoord(_ value: Double) -> String {
        let tenths = (value * 10_000).rounded() / 10_000
        return "\(tenths)"
    }

    private func clockHour(_ hour: Int) -> String {
        let clamped = max(0, min(23, hour))
        let period = clamped >= 12 ? "PM" : "AM"
        let hour12 = clamped % 12
        let shown = hour12 == 0 ? 12 : hour12
        return "\(shown):00 \(period)"
    }
}

#Preview {
    NavigationStack {
        ReadingDetailScreen(readingID: "reading-01", dependencies: .preview())
    }
}
