import SwiftUI

@MainActor
struct VisitStopDetailView: View {
    private let dependencies: AppDependencies
    @Bindable private var store: StoopBookStore
    @State private var viewModel: VisitStopDetailViewModel

    init(stopID: String, dependencies: AppDependencies) {
        self.dependencies = dependencies
        store = dependencies.store
        _viewModel = State(initialValue: VisitStopDetailViewModel(stopID: stopID, dependencies: dependencies))
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
        .sheet(item: $viewModel.presentedExport) { item in
            NavigationStack {
                ExportReadingsScreen(roundID: item.id, dependencies: dependencies)
            }
        }
        .sensoryFeedback(.success, trigger: viewModel.openCount)
        .task {
            viewModel.syncFocus()
        }
    }

    @ViewBuilder
    private func loadedBody(viewModel: VisitStopDetailViewModel) -> some View {            if let stop = viewModel.stop {
                let resolved = viewModel.store.resolvedStop(stop)
                FieldReadout(
                    label: resolved.nickname,
                    value: viewModel.cadenceTitle(for: stop),
                    unit: nil,
                    context: viewModel.windowLabel(for: stop),
                    note: viewModel.accessLine(for: stop)
                )

            SectionCard(title: "Household card") {
                LedgerRow(
                    label: "Cadence",
                    value: "\(stop.lastVisitDayOffset)d of \(stop.cadenceDays)d",
                    tone: viewModel.cadenceState(for: stop).tone
                )
                LedgerRow(label: "Marker", value: viewModel.cadenceTitle(for: stop), tone: viewModel.cadenceState(for: stop).tone)
                LedgerRow(label: "Window", value: viewModel.windowLabel(for: stop))
                LedgerRow(label: "Dwell", value: "\(stop.dwellMinutes) min")
                LedgerRow(label: "Block", value: viewModel.placeName(for: stop))
                DetailRow(label: "Entry", value: stop.entryNote)
                DetailRow(label: "Floor", value: stop.floor)
                DetailRow(label: "Pet", value: stop.petNote)
                DetailRow(label: "Parking", value: stop.parkingNote)
                DetailRow(label: "Access notes", value: viewModel.accessTitle(for: stop), isProminent: true)
            }

            ScreenNote(text: viewModel.blockNote(for: stop))

            SectionCard(title: "Close the visit") {
                HStack(spacing: 8) {
                    ForEach(VisitOutcome.allCases) { outcome in
                        outcomeButton(outcome, stop: stop)
                    }
                }

                if let last = viewModel.lastOutcome(for: stop) {
                    Text("Last closed \(last.outcome.title.lowercased()) — \(last.outcome.caption). \(last.outcome == .seen ? "The cadence clock restarted that day." : "The cadence clock keeps running.")")
                        .font(AppType.caption)
                        .foregroundStyle(AppTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Seen restarts the cadence clock today. No answer, blocked, and skipped leave the clock running and flag the house on the book.")
                        .font(AppType.caption)
                        .foregroundStyle(AppTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if viewModel.roundMembership.isEmpty {
                EmptyStateCard(
                    title: "Not on a morning round",
                    message: "No named round lists this household right now.",
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                    actionTitle: "Export North Loop"
                ) {
                    viewModel.openNorthLoopPack()
                }
            } else {
                SectionCard(title: "Morning rounds") {
                    ForEach(viewModel.roundMembership) { round in
                        LedgerRow(
                            label: round.name,
                            value: "\(round.stopIds.count) stoops · \(round.morningBudgetMinutes) min",
                            tone: round.isDefault ? AppTheme.ink : AppTheme.data
                        )
                    }
                }
            }

            if let saved = viewModel.linkedReading(lastSavedID: store.lastSavedReadingID) {
                SectionCard(title: "Last readout on this household") {
                    LedgerRow(label: "Kit", value: saved.kind.title)
                    LedgerRow(label: "Captured", value: viewModel.dayCaption(saved.capturedDayOffset))
                    DetailRow(label: "What it said", value: saved.readout, isProminent: true)
                }
            }

            CTAButton(
                title: "Export North Loop",
                systemImage: "square.and.arrow.up",
                hint: "Opens the North Loop text pack from this stoop."
            ) {
                viewModel.openNorthLoopPack()
            }
        }
    }

    private func outcomeButton(_ outcome: VisitOutcome, stop: VisitStop) -> some View {
        let isLatest = viewModel.lastOutcome(for: stop)?.outcome == outcome
        return Button {
            viewModel.closeVisit(outcome, stop: stop)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: outcome.glyph)
                    .font(.system(size: 13, weight: .semibold))
                Text(outcome.title)
                    .font(AppType.micro)
            }
            .foregroundStyle(isLatest ? AppTheme.paper : AppTheme.ink)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isLatest ? AppTheme.ink : AppTheme.surfaceLow)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(outcome.title) \(stop.nickname)")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
            EmptyStateCard(
                title: "Stoop not on this phone",
                message: "That household is not in the visit book.",
                systemImage: "house",
                actionTitle: "Open River Stoop 4B"
            ) {
                viewModel.showRiverStoop()
            }

            SectionCard(title: "Asked for") {
                LedgerRow(label: "Stoop", value: viewModel.stopID, tone: AppTheme.ink)
                LedgerRow(label: "Focused", value: store.focusedStopID ?? "none")
                LedgerRow(label: "Round", value: store.selectedRound.name)
            }
        }
    }
}

private struct PresentedDetailExport: Identifiable, Hashable {
    let id: String
}

@MainActor
@Observable
private final class VisitStopDetailViewModel {
    let dependencies: AppDependencies
    var stopID: String
    var presentedExport: PresentedDetailExport?
    var openCount = 0

    init(stopID: String, dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.stopID = stopID
    }

    var store: StoopBookStore { dependencies.store }

    var stop: VisitStop? {
        dependencies.stopRepository.stop(id: stopID)
    }

    var viewState: ViewState {
        stop == nil ? .empty : .loaded
    }

    var headerSubtitle: String {
        if let stop {
            return "\(placeName(for: stop)) · \(windowLabel(for: stop))"
        }
        return "The visit book does not have \(stopID)."
    }

    var navigationTitle: String {
        stop?.nickname ?? "Stoop"
    }

    var roundMembership: [VisitRound] {
        dependencies.roundRepository.listedRounds().filter { $0.stopIds.contains(stopID) }
    }

    func syncFocus() {
        store.focusStop(stopID)
    }

    func closeVisit(_ outcome: VisitOutcome, stop: VisitStop) {
        store.recordOutcome(outcome, stopID: stop.id)
    }

    func lastOutcome(for stop: VisitStop) -> VisitOutcomeRecord? {
        store.outcomes(for: stop.id).max { $0.dayOffset < $1.dayOffset }
    }

    /// The card's cadence readout stands on the resolved book: a recorded seen
    /// moves the clock, every other outcome leaves it.
    func resolvedStop() -> VisitStop? {
        guard let stop else { return nil }
        return store.resolvedStop(stop)
    }

    func showRiverStoop() {
        stopID = "visit-01"
        store.focusStop(stopID)
        openCount += 1
    }

    func openNorthLoopPack() {
        store.focusStop(stopID)
        presentedExport = PresentedDetailExport(id: "round-01")
        openCount += 1
    }

    func cadenceTitle(for stop: VisitStop) -> String {
        dependencies.readingEngine.cadenceState(for: store.resolvedStop(stop)).title
    }

    func cadenceLine(for stop: VisitStop) -> String {
        let resolved = store.resolvedStop(stop)
        let state = dependencies.readingEngine.cadenceState(for: resolved)
        return "\(state.title) · last visit \(resolved.lastVisitDayOffset)d · every \(resolved.cadenceDays)d"
    }

    func isOverdue(_ stop: VisitStop) -> Bool {
        dependencies.readingEngine.cadenceState(for: store.resolvedStop(stop)) == .overdue
    }

    func cadenceState(for stop: VisitStop) -> CadenceState {
        dependencies.readingEngine.cadenceState(for: store.resolvedStop(stop))
    }

    func windowLabel(for stop: VisitStop) -> String {
        "\(clockHour(stop.windowStartHour))–\(clockHour(stop.windowEndHour)) · \(stop.dwellMinutes) min dwell"
    }

    func placeName(for stop: VisitStop) -> String {
        dependencies.placeRepository.place(id: stop.neighbourhoodId)?.name ?? stop.neighbourhoodId
    }

    func blockNote(for stop: VisitStop) -> String {
        dependencies.placeRepository.place(id: stop.neighbourhoodId)?.blockNote ?? "Stored block"
    }

    func accessTitle(for stop: VisitStop) -> String {
        dependencies.readingEngine.accessNotesReady(for: stop) ? "Ready" : "Incomplete"
    }

    func accessLine(for stop: VisitStop) -> String {
        "\(stop.entryNote) · \(stop.petNote) · \(stop.parkingNote)"
    }

    func dayCaption(_ offset: Int) -> String {
        if offset == 0 { return "today" }
        if offset == 1 { return "1 day ago" }
        return "\(offset) days ago"
    }

    func linkedReading(lastSavedID: String?) -> KitReading? {
        if let lastSavedID {
            if let extra = store.extraReadings.first(where: { $0.id == lastSavedID }), extra.stopIds.contains(stopID) {
                return extra
            }
            if let stored = dependencies.readingRepository.reading(id: lastSavedID), stored.stopIds.contains(stopID) {
                return stored
            }
        }
        return dependencies.readingRepository.listedReadings().first { $0.stopIds.contains(stopID) }
    }

    func primaryDisplay(_ reading: KitReading) -> String {
        let rounded = reading.primaryValue.rounded()
        if reading.primaryValue == rounded {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", reading.primaryValue)
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
        return "\(shown):00 \(period)"
    }
}

#Preview {
    NavigationStack {
        VisitStopDetailView(stopID: "visit-01", dependencies: .preview())
    }
}
