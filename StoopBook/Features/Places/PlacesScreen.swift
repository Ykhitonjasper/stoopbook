import SwiftUI

@MainActor
struct PlacesScreen: View {
    private let dependencies: AppDependencies
    @Bindable private var store: StoopBookStore
    @State private var viewModel: PlacesViewModel
    @Namespace private var zoom

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        store = dependencies.store
        _viewModel = State(initialValue: PlacesViewModel(dependencies: dependencies))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScreenScaffold(scrolls: false) {
            if viewModel.viewState.showsPlaceholder {
                ScrollView {
                    emptyState
                }
            } else {
                VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
                    // The sheet is fixed: masthead, lenses, and the stage itself
                    // stand still, so a live map view is a neighbour of the scroll
                    // and never its child — the tile clipping that kills a map
                    // inside a scrolling card cannot happen here.
                    masthead(viewModel: viewModel)

                    chipRow(viewModel: viewModel)

                    if store.mapTilesReachable {
                        SegmentedPicker(
                            title: "Sheet",
                            options: MapMode.allCases.map { SegmentOption($0.title, id: $0.rawValue) },
                            selection: $store.mapModeID,
                            help: "Map draws Apple's basemap. Plot draws the stored pins on this app's own sheet."
                        )
                    }

                    sheetStage(viewModel: viewModel)

                    ScrollView {
                        VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
                            if let saved = viewModel.savedReading(lastSavedID: store.lastSavedReadingID) {
                                FieldReadout(
                                    label: saved.kind.title,
                                    value: viewModel.primaryDisplay(saved),
                                    unit: viewModel.unit(for: saved.kind),
                                    context: saved.readout,
                                    note: viewModel.savedNote(saved, focusedID: store.focusedStopID)
                                )
                                .accessibilityIdentifier("smoke.places.savedReadout")
                            }

                            CTAButton(
                                title: "Copy the round pack",
                                systemImage: "doc.text",
                                hint: "Focuses River Stoop 4B and opens the text pack for \(store.selectedRound.name)."
                            ) {
                                viewModel.openRiverStoop()
                            }
                            .accessibilityIdentifier("smoke.places.openRiverStoop")

                            if let focused = viewModel.focusedStop {
                                focusCard(for: focused, viewModel: viewModel)
                            }

                            SectionLabel(title: "Stoop index", detail: "\(viewModel.filteredStops.count)")

                            SectionCard {
                                VStack(spacing: 0) {
                                    ForEach(Array(viewModel.filteredStops.enumerated()), id: \.element.id) { index, stop in
                                        if index > 0 { IndexRule() }

                                        IndexRow(
                                            title: stop.nickname,
                                            detail: "\(viewModel.placeName(for: stop)) · \(viewModel.windowLabel(for: stop))",
                                            trailing: viewModel.cadenceTitle(for: stop),
                                            accentTone: viewModel.cadenceState(for: stop).tone
                                        ) {
                                            viewModel.openStop(stop.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle("Stoops")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $viewModel.opened) { presented in
            destination(for: presented.route)
        }
        .sheet(item: $viewModel.presentedExport) { item in
            NavigationStack {
                ExportReadingsScreen(roundID: item.id, dependencies: dependencies)
            }
        }
        .sensoryFeedback(.selection, trigger: viewModel.placeFilterID)
        .sensoryFeedback(.selection, trigger: store.focusedStopID)
        .sensoryFeedback(.success, trigger: viewModel.openCount)
        .task {
            viewModel.syncFromStore()
            await viewModel.checkMapAvailability()
        }
        .onChange(of: store.focusedStopID) { _, _ in
            viewModel.syncFromStore()
        }
    }

    /// The navigation bar carries the screen's name, so the masthead names the
    /// subject instead: the round this sheet belongs to.
    private func masthead(viewModel: PlacesViewModel) -> some View {
        ScreenHeader(
            title: store.selectedRound.name,
            subtitle: viewModel.ledgerLine(round: store.selectedRound)
        )
    }

    private func chipRow(viewModel: PlacesViewModel) -> some View {
        TabStrip(
            items: viewModel.placeFilters,
            title: { $0.title },
            isSelected: { viewModel.placeFilterID == $0.id },
            onSelect: { viewModel.selectPlaceFilter($0.id) }
        )
    }

    /// The round sheet: a real basemap when one can be drawn, and this app's own
    /// plot when it cannot. Both carry the same marks and resolve taps by distance,
    /// so the screen never falls back to a blank tile grid without saying so.
    private func sheetStage(viewModel: PlacesViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppMetrics.contentSpacing) {
            SectionLabel(title: "Round sheet", detail: "\(viewModel.filteredStops.count) stoops")

            Group {
                if showsMap {
                    RoundMap(
                        stops: viewModel.filteredStops,
                        route: viewModel.routeStops,
                        focusedStopID: viewModel.focusedStop?.id,
                        state: { viewModel.cadenceState(for: $0) },
                        onSelect: { viewModel.focusStop($0.id) }
                    )
                    .transition(.opacity)
                } else {
                    RoutePlot(
                        stops: viewModel.filteredStops,
                        route: viewModel.routeStops,
                        focusedStopID: viewModel.focusedStop?.id,
                        state: { viewModel.cadenceState(for: $0) },
                        zoomNamespace: zoom,
                        onSelect: { viewModel.focusStop($0.id) }
                    )
                    .transition(.opacity)
                }
            }
            .animation(AppMotion.settle, value: showsMap)
            .frame(height: 248)
            .cardSurface(padding: 0)
            .accessibilityLabel("Stored stoop pins on \(store.selectedRound.name)")

            if !store.mapTilesReachable {
                ScreenNote(text: "Map tiles are unreachable on this network, so the sheet is drawn from the pins stored on this phone.")
            }
        }
    }

    private var showsMap: Bool {
        store.mapTilesReachable && store.mapMode == .map
    }

    private func focusCard(for stop: VisitStop, viewModel: PlacesViewModel) -> some View {
        let state = viewModel.cadenceState(for: stop)
        return SectionCard(title: stop.nickname) {
            HouseholdLine(index: 1, stop: stop, state: state, outcome: viewModel.outcomeMark(for: stop))

            IndexRule()

            DetailRow(label: "Window", value: viewModel.windowLabel(for: stop))
            DetailRow(label: "Block", value: viewModel.placeName(for: stop))
            DetailRow(label: "Entry", value: stop.entryNote)
            DetailRow(label: "Parking", value: stop.parkingNote)
            DetailRow(label: "Access", value: viewModel.accessTitle(for: stop), isProminent: true)

            TextAction(title: "Open the household card") {
                viewModel.openStop(stop.id)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
            EmptyStateCard(
                title: "No stoops on this phone",
                message: "No stored pins yet. Pick a round and its households come with it.",
                actionTitle: "Open the rounds"
            ) {
                viewModel.openRoundsTab()
            }

            SectionCard(title: "On this phone") {
                LedgerRow(label: "Round", value: store.selectedRound.name)
                LedgerRow(label: "Focused", value: store.focusedStopID ?? "none")
                LedgerRow(label: "Last saved", value: store.lastSavedReadingID ?? "none")
            }
        }
        .padding(.horizontal, AppMetrics.screenPadding)
        .padding(.bottom, AppMetrics.screenPadding * 2)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .stopDetail(let stopID):
            VisitStopDetailView(stopID: stopID, dependencies: dependencies)
                .zoomOpen(stopID, in: zoom)
        case .exportPack(let roundID):
            ExportReadingsScreen(roundID: roundID, dependencies: dependencies)
        case .readingDetail(let readingID):
            ReadingDetailScreen(readingID: readingID, dependencies: dependencies)
        case .comparePair(let pairID):
            CompareReadingsScreen(pairID: pairID, dependencies: dependencies)
        case .kit(let kind):
            KitRunnerScreen(kitKind: kind, dependencies: dependencies)
        case .roundBuilder(let roundID):
            RoundBuilderScreen(roundID: roundID, dependencies: dependencies)
        case .saveDraft(let draft):
            ReadingSaveScreen(draft: draft, dependencies: dependencies)
        }
    }
}

private struct PlaceFilter: Identifiable, Hashable {
    let id: String
    let title: String

    static let round = PlaceFilter(id: "round", title: "This round")
    static let all = PlaceFilter(id: "all", title: "All")
}

private struct PresentedPlacesRoute: Identifiable, Hashable {
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

private struct PresentedExport: Identifiable, Hashable {
    let id: String
}

@MainActor
@Observable
private final class PlacesViewModel {
    let dependencies: AppDependencies
    var placeFilterID = PlaceFilter.round.id
    var opened: PresentedPlacesRoute?
    var presentedExport: PresentedExport?
    var openCount = 0

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var store: StoopBookStore { dependencies.store }

    var stops: [VisitStop] {
        dependencies.store.resolvedStops(dependencies.stopRepository.listedStops())
    }

    var places: [NeighbourhoodPlace] {
        dependencies.placeRepository.listedPlaces()
    }

    var placeFilters: [PlaceFilter] {
        [PlaceFilter.round, PlaceFilter.all] + places.map { PlaceFilter(id: $0.id, title: $0.name) }
    }

    var filteredStops: [VisitStop] {
        let base: [VisitStop]
        if placeFilterID == PlaceFilter.round.id {
            let ids = Set(store.selectedRound.stopIds)
            base = stops.filter { ids.contains($0.id) }
        } else if placeFilterID == PlaceFilter.all.id {
            base = stops
        } else {
            base = stops.filter { $0.neighbourhoodId == placeFilterID }
        }
        return base.sorted { lhs, rhs in
            if lhs.nickname == "River Stoop 4B" { return true }
            if rhs.nickname == "River Stoop 4B" { return false }
            return lhs.nickname < rhs.nickname
        }
    }

    /// Walk order for the thread and the pin numbers: the selected round's stops that
    /// are on the sheet. Pins from other blocks still plot, but stay unnumbered,
    /// because they are not on tonight's walk.
    var routeStops: [VisitStop] {
        let onSheet = Set(filteredStops.map(\.id))
        return store.selectedRound.stopIds
            .filter { onSheet.contains($0) }
            .compactMap { dependencies.stopRepository.stop(id: $0) }
    }

    var focusedStop: VisitStop? {
        if let focusedID = store.focusedStopID, let match = stops.first(where: { $0.id == focusedID }) {
            return match
        }
        return riverStop
    }

    var riverStop: VisitStop? {
        dependencies.stopRepository.stop(id: "visit-01") ?? stops.first { $0.nickname == "River Stoop 4B" }
    }

    var viewState: ViewState {
        stops.isEmpty ? .empty : .loaded
    }

    func ledgerLine(round: VisitRound) -> String {
        let overdue = filteredStops.filter { dependencies.readingEngine.cadenceState(for: $0) == .overdue }.count
        return "\(filteredStops.count) pins · \(places.count) blocks · \(overdue) overdue"
    }

    func syncFromStore() {
        if store.focusedStopID == nil, let river = riverStop {
            store.focusStop(river.id)
        }
    }

    /// Apple's basemap needs a network. When there is none, MapKit paints a blank
    /// placeholder instead of failing, so the screen asks first and draws the plot.
    func checkMapAvailability() async {
        let reachable = await MapServiceProbe.tilesReachable()
        store.mapTilesReachable = reachable
        withAnimation(AppMotion.settle) {
            store.applyDefaultMapMode(reachableTiles: reachable)
        }
    }

    func selectPlaceFilter(_ identifier: String) {
        withAnimation(AppMotion.quick) {
            placeFilterID = identifier
        }
    }

    func focusStop(_ stopID: String) {
        store.focusStop(stopID)
    }

    func openStop(_ stopID: String) {
        focusStop(stopID)
        opened = PresentedPlacesRoute(route: .stopDetail(stopID))
        openCount += 1
    }

    func openRiverStoop() {
        store.focusStop("visit-01")
        opened = nil
        presentedExport = PresentedExport(id: "round-01")
        openCount += 1
    }

    func openRoundsTab() {
        store.selectedTab = .kits
    }

    /// The flag beside a household: only unfinished visits raise one.
    func outcomeMark(for stop: VisitStop) -> VisitOutcome? {
        let last = dependencies.store.outcomes(for: stop.id).max { $0.dayOffset < $1.dayOffset }
        return last?.outcome == .seen ? nil : last?.outcome
    }

    func cadenceState(for stop: VisitStop) -> CadenceState {
        dependencies.readingEngine.cadenceState(for: stop)
    }

    func cadenceTitle(for stop: VisitStop) -> String {
        cadenceState(for: stop).title
    }

    func windowLabel(for stop: VisitStop) -> String {
        "\(clockHour(stop.windowStartHour))–\(clockHour(stop.windowEndHour)) · \(stop.dwellMinutes) min dwell"
    }

    func placeName(for stop: VisitStop) -> String {
        dependencies.placeRepository.place(id: stop.neighbourhoodId)?.name ?? stop.neighbourhoodId
    }

    func accessTitle(for stop: VisitStop) -> String {
        dependencies.readingEngine.accessNotesReady(for: stop) ? "ready" : "incomplete"
    }

    func savedReading(lastSavedID: String?) -> KitReading? {
        guard let lastSavedID else { return nil }
        if let extra = store.extraReadings.first(where: { $0.id == lastSavedID }) {
            return extra
        }
        return dependencies.readingRepository.reading(id: lastSavedID)
    }

    func primaryDisplay(_ reading: KitReading) -> String {
        let rounded = reading.primaryValue.rounded()
        if reading.primaryValue == rounded {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", reading.primaryValue)
    }

    func savedNote(_ reading: KitReading, focusedID: String?) -> String {
        let names = reading.stopIds.compactMap { dependencies.stopRepository.stop(id: $0)?.nickname }
        let where_ = names.isEmpty ? "no household attached" : names.joined(separator: " · ")
        if let focusedID, reading.stopIds.contains(focusedID) {
            return "Saved on \(where_), and it is the stoop you have focused."
        }
        return "Saved on \(where_)."
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

    private func clockHour(_ hour: Int) -> String {
        let clamped = max(0, min(23, hour))
        let period = clamped >= 12 ? "PM" : "AM"
        let hour12 = clamped % 12
        let shown = hour12 == 0 ? 12 : hour12
        return "\(shown)\(period)"
    }
}

#Preview {
    NavigationStack {
        PlacesScreen(dependencies: .preview())
    }
}
