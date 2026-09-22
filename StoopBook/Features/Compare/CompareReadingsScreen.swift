import SwiftUI

@MainActor
struct CompareReadingsScreen: View {
    private let dependencies: AppDependencies
    @Bindable private var store: StoopBookStore
    @State private var viewModel: CompareReadingsViewModel

    init(pairID: String, dependencies: AppDependencies) {
        self.dependencies = dependencies
        store = dependencies.store
        _viewModel = State(initialValue: CompareReadingsViewModel(pairID: pairID, dependencies: dependencies))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScreenScaffold {
            ScreenHeader(
                title: viewModel.headerTitle,
                subtitle: viewModel.headerSubtitle + (viewModel.lastSavedCaption(lastSavedID: store.lastSavedReadingID).map { " · \($0)" } ?? "")
            )

            if viewModel.viewState.showsPlaceholder {
                emptyState
            } else {
                loadedBody(viewModel: viewModel)
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $viewModel.opened) { presented in
            destination(for: presented.route)
        }
        .sensoryFeedback(.selection, trigger: viewModel.pairID)
        .sensoryFeedback(.selection, trigger: viewModel.layoutID)
        .sensoryFeedback(.success, trigger: viewModel.exportCount)
        .task {
            viewModel.refresh()
        }
    }

    @ViewBuilder
    private func loadedBody(viewModel: CompareReadingsViewModel) -> some View {
        TabStrip(
            items: viewModel.pairs,
            title: { viewModel.chipTitle(for: $0) },
            isSelected: { viewModel.pairID == $0.id },
            onSelect: { viewModel.choosePair($0) }
        )

        FieldReadout(
            label: "Signed delta",
            value: viewModel.signedDelta,
            unit: viewModel.deltaUnit,
            context: viewModel.summary,
            note: viewModel.deltaNote
        )

        SegmentedPicker(
            title: "Layout",
            options: viewModel.layoutOptions,
            selection: $viewModel.layoutID,
            help: "Delta shows the signed change. Households lists nicknames. Circuits lists the two morning runs."
        )

        SectionCard(title: "The pair") {
            pairLine(reading: viewModel.firstReading, caption: viewModel.firstCaption, figure: viewModel.firstPrimary)
            IndexRule()
            pairLine(reading: viewModel.secondReading, caption: viewModel.secondCaption, figure: viewModel.secondPrimary)
        }

        if viewModel.kindMatchCaption == "Mixed kits" {
            ScreenNote(text: "Mixed kits. The signed delta still compares the two primary figures the readouts were stored with.")
        }

        switch viewModel.layoutID {
        case "households":
            householdsPane(viewModel: viewModel)
        case "circuits":
            circuitsPane(viewModel: viewModel)
        default:
            deltaPane(viewModel: viewModel)
        }

        CTAButton(
            title: "Export North Loop",
            systemImage: "square.and.arrow.up",
            hint: "Opens the round-01 text pack from this compare."
        ) {
            viewModel.openExport()
        }

    }

    /// One readout of the pair as a line, not a ledger row: the kit's mark, what
    /// it said, and the figure it was stored with.
    private func pairLine(reading: KitReading?, caption: String, figure: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let reading {
                KitMark(kind: reading.kind, size: 18, tone: AppTheme.ink)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(reading?.readout ?? "Missing readout")
                    .font(AppType.rowStrong)
                    .foregroundStyle(AppTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(caption)
                    .font(AppType.micro)
                    .foregroundStyle(AppTheme.inkSoft)
            }
            Spacer(minLength: 10)
            Text(figure)
                .font(AppType.data)
                .foregroundStyle(AppTheme.ink)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func deltaPane(viewModel: CompareReadingsViewModel) -> some View {
        if let message = viewModel.validationMessage {
            InlineError(message: message)
        }

        ResultCard(
            title: viewModel.firstRunTitle,
            value: viewModel.firstPrimary,
            unit: viewModel.firstUnit,
            lines: viewModel.firstLines,
            note: viewModel.firstReading?.readout
        )

        ResultCard(
            title: viewModel.secondRunTitle,
            value: viewModel.secondPrimary,
            unit: viewModel.secondUnit,
            lines: viewModel.secondLines,
            note: viewModel.secondReading?.readout
        )

        SectionCard(title: "Signed deltas") {
            ForEach(viewModel.deltaRows) { row in
                LedgerRow(label: row.label, value: row.deltaText, tone: AppTheme.ink)
                DetailRow(label: "First to second", value: "\(row.firstValue) then \(row.secondValue)")
            }
        }

        ScreenNote(text: "Second reading minus the first, on the figures stored with each readout.")
    }

    @ViewBuilder
    private func householdsPane(viewModel: CompareReadingsViewModel) -> some View {
        SectionCard(title: "First readout") {
            DetailRow(label: "Said", value: viewModel.firstReading?.readout ?? "missing", isProminent: true)
            if viewModel.firstStops.isEmpty {
                DetailRow(label: "Households", value: "None attached")
            } else {
                ForEach(Array(viewModel.firstStops.enumerated()), id: \.element.id) { index, stop in
                    HouseholdLine(index: index + 1, stop: stop, state: viewModel.cadenceState(for: stop))
                    if index < viewModel.firstStops.count - 1 { IndexRule() }
                }
            }
        }

        SectionCard(title: "Second readout") {
            DetailRow(label: "Said", value: viewModel.secondReading?.readout ?? "missing", isProminent: true)
            if viewModel.secondStops.isEmpty {
                DetailRow(label: "Households", value: "None attached")
            } else {
                ForEach(Array(viewModel.secondStops.enumerated()), id: \.element.id) { index, stop in
                    HouseholdLine(index: index + 1, stop: stop, state: viewModel.cadenceState(for: stop))
                    if index < viewModel.secondStops.count - 1 { IndexRule() }
                }
            }
        }

        if viewModel.sharedStops.isEmpty == false {
            SectionCard(title: "On both readouts") {
                ForEach(Array(viewModel.sharedStops.enumerated()), id: \.element.id) { index, stop in
                    HouseholdLine(index: index + 1, stop: stop, state: viewModel.cadenceState(for: stop))
                    if index < viewModel.sharedStops.count - 1 { IndexRule() }
                }
            }
        }

        if let first = viewModel.firstReading {
            NavigationRow(
                title: first.readout,
                subtitle: viewModel.firstCaption,
                systemImage: "1.circle",
                trailingText: first.kind.title,
                hint: "Opens the first saved readout."
            ) {
                viewModel.openReading(first.id)
            }
        }

        if let second = viewModel.secondReading {
            NavigationRow(
                title: second.readout,
                subtitle: viewModel.secondCaption,
                systemImage: "2.circle",
                trailingText: second.kind.title,
                hint: "Opens the second saved readout."
            ) {
                viewModel.openReading(second.id)
            }
        }
    }

    @ViewBuilder
    private func circuitsPane(viewModel: CompareReadingsViewModel) -> some View {
        SectionCard(title: viewModel.firstRunTitle, footnote: "Morning of \(viewModel.firstRoundName)") {
            HouseStreet(houses: viewModel.street(for: viewModel.firstRun, fallback: viewModel.firstStops))
            IndexRule()
            DetailRow(label: "Walked", value: viewModel.completedCaption(viewModel.firstRun, roundName: viewModel.firstRoundName), isProminent: true)
            DetailRow(label: "Load", value: viewModel.firstLoadCaption)
        }

        SectionCard(title: viewModel.secondRunTitle, footnote: "Morning of \(viewModel.secondRoundName)") {
            HouseStreet(houses: viewModel.street(for: viewModel.secondRun, fallback: viewModel.secondStops))
            IndexRule()
            DetailRow(label: "Walked", value: viewModel.completedCaption(viewModel.secondRun, roundName: viewModel.secondRoundName), isProminent: true)
            DetailRow(label: "Load", value: viewModel.secondLoadCaption)
        }

        SectionCard(title: "Circuit delta") {
            pairLineCaption(label: "Stoops done", value: viewModel.completedDelta)
            pairLineCaption(label: "First morning", value: viewModel.firstRoundName)
            pairLineCaption(label: "Second morning", value: viewModel.secondRoundName)
        }

        if let first = viewModel.firstReading {
            NavigationRow(
                title: first.kind.title,
                subtitle: first.readout,
                systemImage: "clock",
                trailingText: viewModel.firstPrimary,
                hint: "Opens the first readout."
            ) {
                viewModel.openReading(first.id)
            }
        }

        if let second = viewModel.secondReading {
            NavigationRow(
                title: second.kind.title,
                subtitle: second.readout,
                systemImage: "clock",
                trailingText: viewModel.secondPrimary,
                hint: "Opens the second readout."
            ) {
                viewModel.openReading(second.id)
            }
        }
    }

    /// A quiet measured line inside a section: same prose voice as DetailRow, kept
    /// for the few places a delta table is genuinely the honest form.
    private func pairLineCaption(label: String, value: String) -> some View {
        DetailRow(label: label, value: value)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
            EmptyStateCard(
                title: "Pair not on the book",
                message: "That pair is not in the book. Tuesday vs Thursday North Loop has both cadence lines on it.",
                systemImage: "arrow.left.arrow.right",
                actionTitle: "Open Tuesday vs Thursday"
            ) {
                viewModel.openTuesdayPair()
            }

            SectionCard(title: "Pairs in the book") {
                ForEach(StoopBookSeed.comparePairs) { pair in
                    IndexRow(
                        title: pair.label,
                        detail: viewModel.pairSubtitle(pair),
                        trailing: viewModel.pairDeltaValue(pair)
                    ) {
                        viewModel.openTuesdayPair()
                    }
                }
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
        case .kit, .saveDraft, .stopDetail, .roundBuilder:
            EmptyView()
        }
    }
}

private struct CompareDeltaRow: Identifiable, Hashable {
    let id: String
    let label: String
    let firstValue: String
    let secondValue: String
    let deltaText: String
}

private struct PresentedCompareRoute: Identifiable, Hashable {
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
private final class CompareReadingsViewModel {
    let dependencies: AppDependencies
    var pairID: String
    var layoutID = "delta"
    var opened: PresentedCompareRoute?
    var pendingRoute: AppRoute?
    var packText = ""
    var didBuildPack = false
    var exportCount = 0
    var validationMessage: String?

    init(pairID: String, dependencies: AppDependencies) {
        self.dependencies = dependencies
        if pairID.isEmpty {
            self.pairID = StoopBookSeed.comparePairs.first?.id ?? "pair-01"
        } else {
            self.pairID = pairID
        }
    }

    var store: StoopBookStore { dependencies.store }

    var layoutOptions: [SegmentOption] {
        [
            SegmentOption("Delta", id: "delta"),
            SegmentOption("Households", id: "households"),
            SegmentOption("Circuits", id: "circuits")
        ]
    }

    var pairs: [ComparePair] {
        StoopBookSeed.comparePairs
    }

    var activePair: ComparePair? {
        pairs.first { $0.id == pairID }
    }

    var firstReading: KitReading? {
        guard let pair = activePair else { return nil }
        return resolveReading(pair.firstReadingID)
    }

    var secondReading: KitReading? {
        guard let pair = activePair else { return nil }
        return resolveReading(pair.secondReadingID)
    }

    var viewState: ViewState {
        if activePair == nil || firstReading == nil || secondReading == nil {
            return .empty
        }
        return .loaded
    }

    var headerTitle: String {
        activePair?.label ?? "Compare missing"
    }

    var headerSubtitle: String {
        if let first = firstReading, let second = secondReading {
            return "\(first.kind.title), \(dayCaption(first.capturedDayOffset)) versus \(dayCaption(second.capturedDayOffset)) · \(summary)"
        }
        return "Pick a pair to put both readouts on one line."
    }

    var firstStops: [VisitStop] {
        guard let firstReading else { return [] }
        return store.resolvedStops(firstReading.stopIds.compactMap { dependencies.stopRepository.stop(id: $0) })
    }

    var secondStops: [VisitStop] {
        guard let secondReading else { return [] }
        return store.resolvedStops(secondReading.stopIds.compactMap { dependencies.stopRepository.stop(id: $0) })
    }

    var sharedStops: [VisitStop] {
        let secondIDs = Set(secondStops.map(\.id))
        return firstStops.filter { secondIDs.contains($0.id) }
    }

    var firstRun: PatrolRun? {
        guard let firstReading else { return nil }
        return resolveRun(firstReading.runId)
    }

    var secondRun: PatrolRun? {
        guard let secondReading else { return nil }
        return resolveRun(secondReading.runId)
    }

    var firstRunTitle: String {
        firstRun?.summary ?? "First visit"
    }

    var secondRunTitle: String {
        secondRun?.summary ?? "Second visit"
    }

    var firstRoundName: String {
        if let roundID = firstRun?.roundId, let round = dependencies.roundRepository.round(id: roundID) {
            return round.name
        }
        return store.selectedRound.name
    }

    var secondRoundName: String {
        if let roundID = secondRun?.roundId, let round = dependencies.roundRepository.round(id: roundID) {
            return round.name
        }
        return store.selectedRound.name
    }

    var firstCompletedStops: [VisitStop] {
        guard let firstRun else { return firstStops }
        return firstRun.completedStopIds.compactMap { dependencies.stopRepository.stop(id: $0) }
    }

    var secondCompletedStops: [VisitStop] {
        guard let secondRun else { return secondStops }
        return secondRun.completedStopIds.compactMap { dependencies.stopRepository.stop(id: $0) }
    }

    var firstPrimary: String {
        guard let firstReading else { return "none" }
        return formatted(firstReading.primaryValue)
    }

    var secondPrimary: String {
        guard let secondReading else { return "none" }
        return formatted(secondReading.primaryValue)
    }

    var signedDelta: String {
        guard let firstReading, let secondReading else { return "none" }
        return signed(secondReading.primaryValue - firstReading.primaryValue)
    }

    var deltaUnit: String? {
        firstReading?.kind == .cadence || secondReading?.kind == .cadence ? "days" : unit(for: firstReading?.kind)
    }

    var summary: String {
        guard let firstReading, let secondReading else { return "Pair is missing a readout." }
        return dependencies.readingEngine.compareSummary(first: firstReading, second: secondReading)
    }

    /// The header may mention the newest stored readout by its note, never by a key.
    func lastSavedCaption(lastSavedID: String?) -> String? {
        guard let lastSavedID,
              let reading = dependencies.readingRepository.reading(id: lastSavedID)
                  ?? store.extraReadings.first(where: { $0.id == lastSavedID }) else {
            return nil
        }
        return "Last saved: \(reading.note)"
    }

    var deltaNote: String {
        if let pair = activePair, pair.label == "Tuesday vs Thursday North Loop" {
            return "Tuesday cadence versus Thursday cadence on North Loop."
        }
        return summary
    }

    var firstCaption: String {
        firstReading?.note ?? "First"
    }

    var secondCaption: String {
        secondReading?.note ?? "Second"
    }

    var firstUnit: String? {
        unit(for: firstReading?.kind)
    }

    var secondUnit: String? {
        unit(for: secondReading?.kind)
    }

    var kindCaption: String {
        if let first = firstReading, let second = secondReading, first.kind == second.kind {
            return first.kind.title
        }
        if let first = firstReading, let second = secondReading {
            return "\(shortTitle(first.kind)) / \(shortTitle(second.kind))"
        }
        return "Kit"
    }

    var kindMatchCaption: String {
        if let first = firstReading, let second = secondReading, first.kind == second.kind {
            return "Same kit"
        }
        return "Mixed kits"
    }

    var firstLines: [ResultLine] {
        guard let firstReading else { return [] }
        return [
            ResultLine(label: "Readout", value: firstReading.readout),
            ResultLine(label: "Note", value: firstReading.note),
            ResultLine(label: "Households", value: nicknameSummary(firstStops)),
            ResultLine(label: "Captured", value: dayCaption(firstReading.capturedDayOffset))
        ]
    }

    var secondLines: [ResultLine] {
        guard let secondReading else { return [] }
        return [
            ResultLine(label: "Readout", value: secondReading.readout),
            ResultLine(label: "Note", value: secondReading.note),
            ResultLine(label: "Households", value: nicknameSummary(secondStops)),
            ResultLine(label: "Captured", value: dayCaption(secondReading.capturedDayOffset))
        ]
    }

    var deltaRows: [CompareDeltaRow] {
        let firstValue = firstReading?.primaryValue ?? 0
        let secondValue = secondReading?.primaryValue ?? 0
        let firstStopsCount = Double(firstStops.count)
        let secondStopsCount = Double(secondStops.count)
        let firstDay = Double(firstReading?.capturedDayOffset ?? 0)
        let secondDay = Double(secondReading?.capturedDayOffset ?? 0)
        let firstDone = Double(firstRun?.completedStopIds.count ?? 0)
        let secondDone = Double(secondRun?.completedStopIds.count ?? 0)
        return [
            CompareDeltaRow(
                id: "primary",
                label: "Primary figure",
                firstValue: formatted(firstValue),
                secondValue: formatted(secondValue),
                deltaText: signed(secondValue - firstValue)
            ),
            CompareDeltaRow(
                id: "households",
                label: "Attached households",
                firstValue: "\(firstStops.count)",
                secondValue: "\(secondStops.count)",
                deltaText: signed(secondStopsCount - firstStopsCount)
            ),
            CompareDeltaRow(
                id: "day",
                label: "Captured offset",
                firstValue: dayCaption(Int(firstDay)),
                secondValue: dayCaption(Int(secondDay)),
                deltaText: signed(secondDay - firstDay)
            ),
            CompareDeltaRow(
                id: "completed",
                label: "Completed stoops",
                firstValue: "\(Int(firstDone))",
                secondValue: "\(Int(secondDone))",
                deltaText: signed(secondDone - firstDone)
            )
        ]
    }

    var completedDelta: String {
        let firstDone = Double(firstRun?.completedStopIds.count ?? firstStops.count)
        let secondDone = Double(secondRun?.completedStopIds.count ?? secondStops.count)
        return signed(secondDone - firstDone)
    }

    var firstLoadCaption: String {
        loadCaption(run: firstRun, roundName: firstRoundName)
    }

    var secondLoadCaption: String {
        loadCaption(run: secondRun, roundName: secondRoundName)
    }

    /// The morning drawn as the street it is, for the circuit layouts: one house
    /// per stop of the run's round, brass where the walk already went.
    func street(for run: PatrolRun?, fallback stops: [VisitStop]) -> [StreetHouse] {
        let order: [VisitStop]
        if let run, let round = dependencies.roundRepository.round(id: run.roundId) {
            order = round.stopIds.compactMap { dependencies.stopRepository.stop(id: $0) }
        } else {
            order = stops
        }
        let done = Set(run?.completedStopIds ?? [])
        return order.map { stop in
            let state = cadenceState(for: stop)
            let walked = done.contains(stop.id)
            return StreetHouse(
                id: stop.id,
                roofTone: walked ? AppTheme.brass : state.tone,
                dwellFraction: RowhouseMark.dwellFraction(dwellMinutes: stop.dwellMinutes),
                caption: RowhouseMark.dayCaption(state: state, lastVisitDayOffset: stop.lastVisitDayOffset, cadenceDays: stop.cadenceDays),
                captionTone: walked ? AppTheme.brass : state.tone
            )
        }
    }

    func cadenceState(for stop: VisitStop) -> CadenceState {
        dependencies.readingEngine.cadenceState(for: stop)
    }

    func refresh() {
        if activePair == nil {
            validationMessage = "Unknown pair. Open Tuesday vs Thursday North Loop."
        } else if firstReading == nil || secondReading == nil {
            validationMessage = "One of the paired readouts is missing from the visit book."
        } else {
            validationMessage = nil
        }
        _ = summary
    }

    func choosePair(_ pair: ComparePair) {
        pairID = pair.id
        pendingRoute = .comparePair(pair.id)
        didBuildPack = false
        refresh()
    }

    func openTuesdayPair() {
        if let pair = pairs.first(where: { $0.label == "Tuesday vs Thursday North Loop" }) ?? pairs.first {
            choosePair(pair)
        }
    }

    func openReading(_ readingID: String) {
        let route = AppRoute.readingDetail(readingID)
        pendingRoute = route
        opened = PresentedCompareRoute(route: route)
    }

    func openExport() {
        let round = dependencies.roundRepository.round(id: "round-01") ?? store.selectedRound
        let stops = round.stopIds.compactMap { dependencies.stopRepository.stop(id: $0) }
        var linked: [KitReading] = []
        if let firstReading { linked.append(firstReading) }
        if let secondReading { linked.append(secondReading) }
        packText = dependencies.readingEngine.exportPackText(round: round, stops: stops, readings: linked)
        pendingRoute = .exportPack("round-01")
        opened = PresentedCompareRoute(route: .exportPack("round-01"))
        didBuildPack = true
        exportCount += 1
    }

    func chipTitle(for pair: ComparePair) -> String {
        if pair.label == "Tuesday vs Thursday North Loop" {
            return "Tue / Thu"
        }
        return pair.label
    }

    func cadenceLine(for stop: VisitStop) -> String {
        let state = dependencies.readingEngine.cadenceState(for: stop)
        return "\(state.title) · last \(stop.lastVisitDayOffset)d · every \(stop.cadenceDays)d"
    }

    /// What a pair is made of, in words a field book would use.
    func pairSubtitle(_ pair: ComparePair) -> String {
        let first = resolveReading(pair.firstReadingID)?.note ?? "first visit"
        let second = resolveReading(pair.secondReadingID)?.note ?? "second visit"
        return "\(first) · \(second)"
    }

    /// The signed gap between the pair's two stored figures.
    func pairDeltaValue(_ pair: ComparePair) -> String {
        guard let first = resolveReading(pair.firstReadingID), let second = resolveReading(pair.secondReadingID) else {
            return "none"
        }
        return signed(second.primaryValue - first.primaryValue)
    }

    func windowLabel(for stop: VisitStop) -> String {
        "\(clockHour(stop.windowStartHour))–\(clockHour(stop.windowEndHour)) · \(stop.dwellMinutes) min"
    }

    func pinCaption(_ stop: VisitStop) -> String {
        "\(formatCoord(stop.lat)), \(formatCoord(stop.lon))"
    }

    func dayCaption(_ offset: Int) -> String {
        if offset == 0 { return "Today" }
        if offset == 1 { return "1 day ago" }
        return "\(offset) days ago"
    }

    func completedCaption(_ run: PatrolRun?, roundName: String) -> String {
        guard let run else { return "No circuit on \(roundName)" }
        let total = dependencies.roundRepository.round(id: run.roundId)?.stopIds.count ?? run.completedStopIds.count
        return "\(run.completedStopIds.count) of \(total)"
    }

    private func loadCaption(run: PatrolRun?, roundName: String) -> String {
        guard let run, let round = dependencies.roundRepository.round(id: run.roundId) else {
            return roundName
        }
        let stops = round.stopIds.compactMap { dependencies.stopRepository.stop(id: $0) }
        let minutes = dependencies.patrolEngine.loadMinutes(round: round, stops: stops)
        return "\(minutes) min on \(round.name)"
    }

    private func resolveReading(_ identifier: String) -> KitReading? {
        if let extra = store.extraReadings.first(where: { $0.id == identifier }) {
            return extra
        }
        return dependencies.readingRepository.reading(id: identifier)
    }

    private func resolveRun(_ identifier: String) -> PatrolRun? {
        if store.activeRun?.id == identifier {
            return store.activeRun
        }
        return dependencies.runRepository.run(id: identifier)
    }

    private func nicknameSummary(_ stops: [VisitStop]) -> String {
        let names = stops.map(\.nickname)
        if names.isEmpty { return "None" }
        return names.joined(separator: ", ")
    }

    private func unit(for kind: VisitKitKind?) -> String? {
        guard let kind else { return nil }
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

    private func shortTitle(_ kind: VisitKitKind) -> String {
        switch kind {
        case .cadence: return "Cadence"
        case .windowFit: return "Window"
        case .pinTravel: return "Pins"
        case .cluster: return "Cluster"
        case .accessNotes: return "Notes"
        case .roundLoad: return "Load"
        case .skipCost: return "Skip"
        }
    }

    private func formatted(_ value: Double) -> String {
        let rounded = value.rounded()
        if value == rounded {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", value)
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
        CompareReadingsScreen(pairID: "pair-01", dependencies: .preview())
    }
}
