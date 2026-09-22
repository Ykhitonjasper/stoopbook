import SwiftUI

@MainActor
struct ReadingsScreen: View {
    private let dependencies: AppDependencies
    @Bindable private var store: StoopBookStore
    @State private var viewModel: ReadingsViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        store = dependencies.store
        _viewModel = State(initialValue: ReadingsViewModel(dependencies: dependencies))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScreenScaffold {
            ScreenHeader(title: "Visit book", subtitle: viewModel.ledgerLine(round: store.selectedRound))

            if viewModel.viewState.showsPlaceholder {
                emptyState
            } else {
                chipRow(viewModel: viewModel)

                SegmentedPicker(
                    title: "Book",
                    options: viewModel.paneOptions,
                    selection: $viewModel.paneID
                )

                switch viewModel.paneID {
                case "circuits":
                    circuitsPane(viewModel: viewModel)
                case "pairs":
                    pairsPane(viewModel: viewModel)
                default:
                    visitsPane(viewModel: viewModel)
                }

                TextAction(title: "Export \(store.selectedRound.name)", systemImage: "square.and.arrow.up") {
                    viewModel.openExport()
                }
            }
        }
        .navigationTitle("Visits")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $viewModel.opened) { presented in
            destination(for: presented.route)
        }
        .sensoryFeedback(.selection, trigger: viewModel.paneID)
        .sensoryFeedback(.selection, trigger: viewModel.kindFilterID)
        .sensoryFeedback(.success, trigger: viewModel.packBuildCount)
        .task {
            viewModel.refresh()
        }
    }

    private func chipRow(viewModel: ReadingsViewModel) -> some View {
        TabStrip(
            items: viewModel.kindFilters,
            title: { $0.title },
            isSelected: { viewModel.kindFilterID == $0.id },
            onSelect: { viewModel.selectKindFilter($0.id) }
        )
    }

    // MARK: - Visits

    @ViewBuilder
    private func visitsPane(viewModel: ReadingsViewModel) -> some View {
        let readings = viewModel.filteredReadings

        SectionLabel(
            title: viewModel.kindFilterCaption,
            detail: "\(readings.count)"
        )

        if readings.isEmpty {
            EmptyStateCard(
                title: "Nothing in this kit",
                message: "No saved readout matches \(viewModel.kindFilterCaption). The full book is one tap away.",
                actionTitle: "Show every kit"
            ) {
                viewModel.selectKindFilter(KindFilter.all.id)
            }
        } else {
            SectionCard {
                VStack(spacing: 0) {
                    ForEach(Array(readings.enumerated()), id: \.element.id) { index, reading in
                        if index > 0 { IndexRule() }

                        IndexRow(
                            title: viewModel.readingTitle(reading),
                            detail: reading.readout,
                            trailing: viewModel.trailingCaption(for: reading)
                        ) {
                            viewModel.openReading(reading.id)
                        }
                    }
                }
            }

            if let pair = viewModel.northLoopPair {
                SectionLabel(title: "Compare", detail: pair.label)
                SectionCard {
                    IndexRow(
                        title: viewModel.firstReadingTitle(pair),
                        detail: viewModel.pairSubtitle(pair),
                        trailing: "2 readouts"
                    ) {
                        viewModel.openCompare(pair.id)
                    }
                }
            }
        }
    }

    // MARK: - Circuits

    @ViewBuilder
    private func circuitsPane(viewModel: ReadingsViewModel) -> some View {
        if let run = store.activeRun ?? viewModel.activeRun {
            let houses = viewModel.street(for: run)
            SectionLabel(title: "Live circuit", detail: viewModel.dayCaption(run.startedDayOffset))
            SectionCard(title: viewModel.roundName(for: run), footnote: viewModel.circuitFootnote(run: run)) {
                HouseStreet(houses: houses)
                IndexRule()
                DetailRow(label: "Walked", value: viewModel.completedCaption(run), isProminent: true)
                DetailRow(label: "Circuit", value: run.summary)
            }
        } else {
            EmptyStateCard(
                title: "No live circuit",
                message: "The morning round is not marked active, so nothing new can be saved onto today's visit.",
                actionTitle: "Open the rounds"
            ) {
                viewModel.openRoundsTab()
            }
        }

        SectionLabel(title: "Past visits", detail: "\(viewModel.pastRuns.count)")

        SectionCard {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.pastRuns.enumerated()), id: \.element.id) { index, run in
                    if index > 0 { IndexRule() }

                    IndexRow(
                        title: viewModel.roundName(for: run),
                        detail: viewModel.runSubtitle(run),
                        trailing: viewModel.dayCaption(run.startedDayOffset)
                    ) {
                        viewModel.openRun(run)
                    }
                }
            }
        }
    }

    // MARK: - Pairs

    @ViewBuilder
    private func pairsPane(viewModel: ReadingsViewModel) -> some View {
        SectionLabel(title: "Seeded pairs", detail: "\(viewModel.comparePairs.count)")

        SectionCard {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.comparePairs.enumerated()), id: \.element.id) { index, pair in
                    if index > 0 { IndexRule() }

                    IndexRow(
                        title: pair.label,
                        detail: viewModel.pairSubtitle(pair),
                        trailing: viewModel.pairDeltaValue(pair)
                    ) {
                        viewModel.openCompare(pair.id)
                    }
                }
            }
        }

        if let pair = viewModel.northLoopPair {
            ResultCard(
                title: "Tuesday vs Thursday",
                value: viewModel.pairDeltaValue(pair),
                unit: "days",
                lines: viewModel.pairLines(pair),
                note: "Second reading minus first, on the same households."
            )
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
            EmptyStateCard(
                title: "No visits yet",
                message: "Run cadence on \(store.selectedRound.name) and save it. It lands here on the day it was taken.",
                actionTitle: "Check cadence"
            ) {
                viewModel.openRoundsTab()
            }

            SectionCard(title: "On this phone") {
                LedgerRow(label: "Round", value: store.selectedRound.name)
                LedgerRow(label: "Stoops", value: "\(store.selectedRound.stopIds.count)")
                LedgerRow(label: "Budget", value: "\(store.selectedRound.morningBudgetMinutes) min")
                LedgerRow(label: "Last saved", value: store.lastSavedReadingID ?? "none")
            }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .readingDetail(let readingID):
            ReadingDetailScreen(readingID: readingID, dependencies: dependencies)
        case .comparePair(let pairID):
            CompareReadingsScreen(pairID: pairID, dependencies: dependencies)
        case .exportPack(let roundID):
            ExportReadingsScreen(roundID: roundID, dependencies: dependencies)
        case .stopDetail(let stopID):
            VisitStopDetailView(stopID: stopID, dependencies: dependencies)
        case .kit(let kind):
            KitRunnerScreen(kitKind: kind, dependencies: dependencies)
        case .roundBuilder(let roundID):
            RoundBuilderScreen(roundID: roundID, dependencies: dependencies)
        case .saveDraft(let draft):
            ReadingSaveScreen(draft: draft, dependencies: dependencies)
        }
    }
}

private struct KindFilter: Identifiable, Hashable {
    let id: String
    let title: String

    static let all = KindFilter(id: "all", title: "All")
}

private struct PresentedReadingsRoute: Identifiable, Hashable {
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
private final class ReadingsViewModel {
    let dependencies: AppDependencies
    var paneID = "visits"
    var kindFilterID = KindFilter.all.id
    var opened: PresentedReadingsRoute?
    var pendingRoute: AppRoute?
    var packBuildCount = 0

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var store: StoopBookStore { dependencies.store }

    var paneOptions: [SegmentOption] {
        [
            SegmentOption("Visits", id: "visits"),
            SegmentOption("Circuits", id: "circuits"),
            SegmentOption("Pairs", id: "pairs")
        ]
    }

    var kindFilters: [KindFilter] {
        [KindFilter.all] + VisitKitKind.allCases.map { KindFilter(id: $0.id, title: $0.title) }
    }

    var kindFilterCaption: String {
        if kindFilterID == KindFilter.all.id {
            return "Saved readouts"
        }
        return VisitKitKind.allCases.first { $0.id == kindFilterID }?.title ?? "Kit"
    }

    var readings: [KitReading] {
        var seen = Set<String>()
        var ordered: [KitReading] = []
        for reading in store.extraReadings + dependencies.readingRepository.listedReadings() {
            if seen.insert(reading.id).inserted {
                ordered.append(reading)
            }
        }
        return ordered.sorted { lhs, rhs in
            if lhs.capturedDayOffset != rhs.capturedDayOffset {
                return lhs.capturedDayOffset < rhs.capturedDayOffset
            }
            return lhs.id < rhs.id
        }
    }

    var filteredReadings: [KitReading] {
        if kindFilterID == KindFilter.all.id {
            return readings
        }
        return readings.filter { $0.kind.id == kindFilterID }
    }

    var runs: [PatrolRun] {
        dependencies.runRepository.listedRuns()
    }

    var activeRun: PatrolRun? {
        runs.first(where: { $0.isActive })
    }

    var pastRuns: [PatrolRun] {
        runs.filter { $0.isActive == false }
            .sorted { lhs, rhs in
                if lhs.startedDayOffset != rhs.startedDayOffset {
                    return lhs.startedDayOffset < rhs.startedDayOffset
                }
                return lhs.id < rhs.id
            }
    }

    var comparePairs: [ComparePair] {
        StoopBookSeed.comparePairs
    }

    var northLoopPair: ComparePair? {
        comparePairs.first { $0.label == "Tuesday vs Thursday North Loop" } ?? comparePairs.first
    }

    var viewState: ViewState {
        if readings.isEmpty && runs.isEmpty {
            return .empty
        }
        return .loaded
    }

    func ledgerLine(round: VisitRound) -> String {
        let overdue = dependencies.store.resolvedStops(round.stopIds.compactMap { dependencies.stopRepository.stop(id: $0) })
            .filter { dependencies.readingEngine.cadenceState(for: $0) == .overdue }
            .count
        let live = store.activeRun == nil ? "no live circuit" : "circuit active"
        return "\(readings.count) readouts · \(pastRuns.count) past visits · \(round.stopIds.count) stoops · \(overdue) overdue · \(live)"
    }

    func refresh() {
        if paneID.isEmpty {
            paneID = "visits"
        }
    }

    func selectKindFilter(_ identifier: String) {
        kindFilterID = identifier
        paneID = "visits"
    }

    func openReading(_ readingID: String) {
        let route = AppRoute.readingDetail(readingID)
        pendingRoute = route
        opened = PresentedReadingsRoute(route: route)
    }

    func openCompare(_ pairID: String) {
        let route = AppRoute.comparePair(pairID)
        pendingRoute = route
        opened = PresentedReadingsRoute(route: route)
    }

    func openExport() {
        let roundID = dependencies.roundRepository.round(id: "round-01")?.id ?? store.selectedRound.id
        pendingRoute = .exportPack(roundID)
        opened = PresentedReadingsRoute(route: .exportPack(roundID))
        packBuildCount += 1
    }

    func openRoundsTab() {
        store.selectedTab = .kits
        pendingRoute = .kit(.cadence)
    }

    func openRun(_ run: PatrolRun) {
        if let reading = readings.first(where: { $0.runId == run.id }) {
            openReading(reading.id)
            return
        }
        if let pair = northLoopPair, run.roundId == "round-01" {
            openCompare(pair.id)
        }
    }

    func readingTitle(_ reading: KitReading) -> String {
        "\(reading.kind.title) · \(nicknames(for: reading.stopIds))"
    }

    /// The walk drawn as the street it is: one house per stop, in walk order, its
    /// cadence state on the roof and the days beside it.
    func street(for run: PatrolRun) -> [StreetHouse] {
        let round = roundForRun(run)
        let order = round?.stopIds ?? run.completedStopIds
        let done = Set(run.completedStopIds)
        return order.compactMap { stopID -> StreetHouse? in
            guard let raw = dependencies.stopRepository.stop(id: stopID) else { return nil }
            let stop = dependencies.store.resolvedStop(raw)
            let state = dependencies.readingEngine.cadenceState(for: stop)
            return StreetHouse(
                id: stop.id,
                roofTone: done.contains(stop.id) ? AppTheme.brass : state.tone,
                dwellFraction: RowhouseMark.dwellFraction(dwellMinutes: stop.dwellMinutes),
                caption: RowhouseMark.dayCaption(state: state, lastVisitDayOffset: stop.lastVisitDayOffset, cadenceDays: stop.cadenceDays),
                captionTone: done.contains(stop.id) ? AppTheme.brass : state.tone
            )
        }
    }

    func circuitFootnote(run: PatrolRun) -> String {
        let percent = Int((dependencies.patrolEngine.progressRatio(run: run, round: roundForRun(run) ?? store.selectedRound) * 100).rounded())
        return "\(run.completedStopIds.count) of \(stopCount(for: run)) stoops walked · \(percent)% · brass roofs are the ones already done"
    }

    func firstReadingTitle(_ pair: ComparePair) -> String {
        pair.label
    }

    func trailingCaption(for reading: KitReading) -> String {
        let circuit = run(for: reading.runId)?.summary ?? "an earlier circuit"
        return "\(dayCaption(reading.capturedDayOffset)) · \(circuit)"
    }

    func runSubtitle(_ run: PatrolRun) -> String {
        let readoutCount = readings.filter { $0.runId == run.id }.count
        return "\(roundName(for: run)) · \(run.completedStopIds.count) stoops done · \(readoutCount) readouts"
    }

    func pairSubtitle(_ pair: ComparePair) -> String {
        let first = reading(id: pair.firstReadingID)?.note ?? pair.firstReadingID
        let second = reading(id: pair.secondReadingID)?.note ?? pair.secondReadingID
        return "\(first) · \(second)"
    }

    func pairDeltaValue(_ pair: ComparePair) -> String {
        guard let first = reading(id: pair.firstReadingID), let second = reading(id: pair.secondReadingID) else {
            return "none"
        }
        return signed(second.primaryValue - first.primaryValue)
    }

    func pairLines(_ pair: ComparePair) -> [ResultLine] {
        let first = reading(id: pair.firstReadingID)
        let second = reading(id: pair.secondReadingID)
        return [
            ResultLine(label: "First", value: first?.readout ?? pair.firstReadingID),
            ResultLine(label: "Second", value: second?.readout ?? pair.secondReadingID)
        ]
    }

    func progressPercent(run: PatrolRun, round: VisitRound) -> String {
        let ratio = dependencies.patrolEngine.progressRatio(run: run, round: roundForRun(run) ?? round)
        return "\(Int((ratio * 100).rounded()))"
    }

    func stopCount(for run: PatrolRun) -> Int {
        if let round = roundForRun(run) {
            return round.stopIds.count
        }
        return max(run.completedStopIds.count, 1)
    }

    func completedCaption(_ run: PatrolRun) -> String {
        "\(run.completedStopIds.count) of \(stopCount(for: run))"
    }

    func roundName(for run: PatrolRun) -> String {
        roundForRun(run)?.name ?? run.roundId
    }

    func dayCaption(_ offset: Int) -> String {
        if offset == 0 { return "today" }
        if offset == 1 { return "1 day ago" }
        return "\(offset) days ago"
    }

    private func reading(id: String) -> KitReading? {
        if let extra = store.extraReadings.first(where: { $0.id == id }) {
            return extra
        }
        return dependencies.readingRepository.reading(id: id)
    }

    private func run(for runID: String) -> PatrolRun? {
        if store.activeRun?.id == runID {
            return store.activeRun
        }
        return dependencies.runRepository.run(id: runID)
    }

    private func roundForRun(_ run: PatrolRun) -> VisitRound? {
        dependencies.roundRepository.round(id: run.roundId)
    }

    private func nicknames(for stopIDs: [String]) -> String {
        let names = stopIDs.compactMap { dependencies.stopRepository.stop(id: $0)?.nickname }
        if names.isEmpty { return "no household" }
        if names.count == 1 { return names[0] }
        return "\(names.count) households"
    }

    private func signed(_ value: Double) -> String {
        let rounded = value.rounded()
        if value == rounded {
            let intValue = Int(rounded)
            if intValue > 0 { return "+\(intValue)" }
            return "\(intValue)"
        }
        if value > 0 {
            return String(format: "+%.1f", value)
        }
        return String(format: "%.1f", value)
    }
}

#Preview {
    NavigationStack {
        ReadingsScreen(dependencies: .preview())
    }
}
