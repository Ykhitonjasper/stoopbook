import SwiftUI

@MainActor
@Observable
private final class RoundBuilderViewModel {
    let dependencies: AppDependencies
    var roundID: String
    var viewState: ViewState
    var workingRound: VisitRound?
    var draftStopIDs: [String]
    var validationMessage: String?
    var applyCount = 0
    var moveCount = 0
    var layoutID: String
    var budgetScratch: String
    var pendingRoute: AppRoute?
    let book = MorningBook()

    init(roundID: String, dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.roundID = roundID
        viewState = .empty
        workingRound = nil
        draftStopIDs = []
        layoutID = "order"
        budgetScratch = "\(dependencies.store.selectedRound.morningBudgetMinutes)"
        pendingRoute = nil
        reload()
    }

    var store: StoopBookStore { dependencies.store }
    var patrolEngine: PatrolEngine { dependencies.patrolEngine }

    var layoutOptions: [SegmentOption] {
        [
            SegmentOption("Order", id: "order"),
            SegmentOption("Load", id: "load"),
            SegmentOption("Orders", id: "orders")
        ]
    }

    var checkpoints: [VisitStop] {
        draftStopIDs.compactMap { dependencies.stopRepository.stop(id: $0) }
    }

    var listedStops: [VisitStop] {
        dependencies.stopRepository.listedStops()
    }

    var roundName: String {
        workingRound?.name ?? "Unknown round"
    }

    var budgetMinutes: Int {
        workingRound?.morningBudgetMinutes ?? store.selectedRound.morningBudgetMinutes
    }

    var loadMinutes: Int {
        guard let round = workingDraftRound else { return 0 }
        return patrolEngine.loadMinutes(round: round, stops: listedStops)
    }

    var dwellMinutes: Int {
        checkpoints.reduce(0) { $0 + $1.dwellMinutes }
    }

    var travelMinutes: Int {
        max(0, loadMinutes - dwellMinutes)
    }

    var slackMinutes: Int {
        budgetMinutes - loadMinutes
    }

    var workingDraftRound: VisitRound? {
        guard let round = workingRound else { return nil }
        return VisitRound(
            id: round.id,
            name: round.name,
            stopIds: draftStopIDs,
            morningBudgetMinutes: round.morningBudgetMinutes,
            isDefault: round.isDefault
        )
    }

    var isNorthLoop: Bool {
        workingRound?.id == "round-01" || workingRound?.name == "North Loop"
    }

    var orderMatchesStore: Bool {
        store.selectedRound.stopIds == draftStopIDs
    }

    var headerSubtitle: String {
        if viewState == .empty {
            return "That identifier is not on the book. Open North Loop to keep the eight-stop morning budget."
        }
        return "Reorder the morning checkpoints. The budget stays \(budgetMinutes) minutes."
    }

    var loadCaption: String {
        if slackMinutes < 0 {
            return "\(abs(slackMinutes)) minutes over the morning budget"
        }
        return "\(slackMinutes) minutes of slack on \(roundName)"
    }

    func reload() {
        if let round = dependencies.roundRepository.round(id: roundID) {
            workingRound = round
            viewState = round.stopIds.isEmpty ? .empty : .loaded
            if store.selectedRound.id == round.id, store.draftStopIDs.isEmpty == false {
                draftStopIDs = store.draftStopIDs
            } else {
                draftStopIDs = round.stopIds
            }
            store.draftStopIDs = draftStopIDs
            budgetScratch = "\(round.morningBudgetMinutes)"
            validationMessage = nil
            if checkpoints.count < 8, isNorthLoop == false, round.id == "round-01" {
                validationMessage = "North Loop should list eight households."
            }
            return
        }
        workingRound = nil
        draftStopIDs = []
        viewState = .empty
    }

    func openNorthLoop() {
        let northID = store.selectedRound.id == "round-01"
            ? store.selectedRound.id
            : (dependencies.roundRepository.round(id: "round-01")?.id ?? store.selectedRound.id)
        if let north = dependencies.roundRepository.round(id: northID) ?? dependencies.roundRepository.round(id: "round-01") {
            store.selectRound(north)
            roundID = north.id
            pendingRoute = .roundBuilder(north.id)
            reload()
        }
    }

    func moveStop(id: String, by offset: Int) {
        guard let index = draftStopIDs.firstIndex(of: id) else { return }
        let target = index + offset
        guard draftStopIDs.indices.contains(target) else { return }
        draftStopIDs.swapAt(index, target)
        store.draftStopIDs = draftStopIDs
        moveCount += 1
        validationMessage = nil
    }

    func canMove(_ stopID: String, by offset: Int) -> Bool {
        guard let index = draftStopIDs.firstIndex(of: stopID) else { return false }
        return draftStopIDs.indices.contains(index + offset)
    }

    func applyOrder() {
        guard let copied = workingDraftRound else {
            validationMessage = "This identifier is not a seeded round."
            viewState = .empty
            return
        }
        if draftStopIDs.count < 2 {
            validationMessage = "Keep at least two checkpoints on the morning round."
            return
        }
        store.selectRound(copied)
        workingRound = copied
        applyCount += 1
        pendingRoute = .roundBuilder(copied.id)
        validationMessage = nil
    }

    func resetOrder() {
        guard let round = dependencies.roundRepository.round(id: roundID) else {
            viewState = .empty
            return
        }
        draftStopIDs = round.stopIds
        store.draftStopIDs = draftStopIDs
        validationMessage = nil
    }

    func nickname(for stopID: String) -> String {
        dependencies.stopRepository.stop(id: stopID)?.nickname ?? stopID
    }

    // MARK: Lawful orders

    /// The three orders a dispatcher is allowed to mean, costed on the same pool:
    /// load, how many overdue stay on the morning, and who moves to Saturday.
    var proposals: [RoundProposal] {
        guard let round = workingDraftRound else { return [] }
        return book.proposals(round: round, stops: listedStops)
    }

    func applyProposal(_ proposal: RoundProposal) {
        draftStopIDs = proposal.legs.map { $0.stop.id }
        store.draftStopIDs = draftStopIDs
        moveCount += 1
        validationMessage = nil
    }

    func proposalCaption(_ proposal: RoundProposal) -> String {
        let budget = budgetMinutes
        let slack = budget - proposal.loadMinutes
        var parts = ["\(proposal.loadMinutes) min load"]
        if slack < 0 {
            parts.append("\(abs(slack)) over")
        } else {
            parts.append("\(slack) slack")
        }
        parts.append("\(proposal.overdueKept) overdue kept")
        if proposal.overflow.isEmpty {
            parts.append("nothing to Saturday")
        } else {
            parts.append("\(proposal.overflow.count) to Saturday")
        }
        return parts.joined(separator: " · ")
    }

    func indexTitle(for stopID: String) -> String {
        guard let index = draftStopIDs.firstIndex(of: stopID) else { return "-" }
        return "\(index + 1)"
    }

    func hopMinutes(before stop: VisitStop) -> Int? {
        guard let index = draftStopIDs.firstIndex(of: stop.id), index > 0 else { return nil }
        let previousID = draftStopIDs[index - 1]
        guard let previous = dependencies.stopRepository.stop(id: previousID) else { return nil }
        let bin = dependencies.readingEngine.pinTravel(from: previous, to: stop)
        return patrolEngine.planningMinutes(for: bin)
    }

    func hopBinTitle(before stop: VisitStop) -> String? {
        guard let index = draftStopIDs.firstIndex(of: stop.id), index > 0 else { return nil }
        let previousID = draftStopIDs[index - 1]
        guard let previous = dependencies.stopRepository.stop(id: previousID) else { return nil }
        return dependencies.readingEngine.pinTravel(from: previous, to: stop).title
    }

    func hopCaption(for stop: VisitStop) -> String {
        if let hop = hopMinutes(before: stop), let bin = hopBinTitle(before: stop) {
            return "Hop from previous: \(bin) · \(hop) min"
        }
        return "First pin on the circuit"
    }

    func loadLineValue(for stop: VisitStop) -> String {
        if let hop = hopMinutes(before: stop) {
            return "\(hop) min hop + \(stop.dwellMinutes) min dwell"
        }
        return "\(stop.dwellMinutes) min dwell"
    }

    func clockHour(_ hour: Int) -> String {
        let clamped = max(0, min(23, hour))
        let period = clamped >= 12 ? "PM" : "AM"
        let hour12 = clamped % 12
        let shown = hour12 == 0 ? 12 : hour12
        return "\(shown):00 \(period)"
    }
}

@MainActor
struct RoundBuilderScreen: View {
    @State private var viewModel: RoundBuilderViewModel

    init(roundID: String, dependencies: AppDependencies) {
        _viewModel = State(initialValue: RoundBuilderViewModel(roundID: roundID, dependencies: dependencies))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ScreenScaffold {
            ScreenHeader(
                title: viewModel.viewState == .empty ? "Round missing" : viewModel.roundName,
                subtitle: viewModel.headerSubtitle
            )

            if viewModel.viewState == .empty {
                emptyState
            } else {
                loadedBody
            }
        }
        .navigationTitle("Round builder")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: viewModel.moveCount)
        .sensoryFeedback(.success, trigger: viewModel.applyCount)
        .task {
            viewModel.reload()
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
            EmptyStateCard(
                title: "Round not on the book",
                message: "That circuit is not in the seeded rounds. North Loop carries the eight-stop budget and dwell times.",
                systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                actionTitle: "Open North Loop"
            ) {
                viewModel.openNorthLoop()
            }

            SectionCard(
                title: "Why this is empty",
                footnote: "The builder edits a named round from the seed, and never invents a household."
            ) {
                DetailRow(label: "Asked for", value: "A named round from the seed")
                DetailRow(label: "Selected round", value: viewModel.store.selectedRound.name)
                DetailRow(label: "Checkpoints on selection", value: "\(viewModel.store.selectedRound.stopIds.count)")
            }
        }
    }

    @ViewBuilder
    private var loadedBody: some View {
        @Bindable var viewModel = viewModel
        FieldReadout(
            label: "Round load",
            value: "\(viewModel.loadMinutes)",
            unit: "min",
            context: "\(viewModel.checkpoints.count) checkpoints on \(viewModel.roundName)",
            note: viewModel.loadCaption
        )

        SectionCard(title: "Morning load") {
            LedgerRow(label: "Checkpoints", value: "\(viewModel.checkpoints.count)")
            LedgerRow(label: "Budget", value: "\(viewModel.budgetMinutes) min")
            LedgerRow(label: "Dwell", value: "\(viewModel.dwellMinutes) min")
            LedgerRow(label: "Travel bins", value: "\(viewModel.travelMinutes) min")
            LedgerRow(
                label: "Slack",
                value: "\(viewModel.slackMinutes) min",
                tone: viewModel.slackMinutes < 0 ? AppTheme.rust : AppTheme.sage
            )

            NumberField(
                title: "Budget reminder",
                value: $viewModel.budgetScratch,
                unit: "min",
                prompt: "240",
                help: "Scratch comparison only. Applying an order keeps the seeded budget."
            )
        }

        SectionCard {
            SegmentedPicker(
                title: "View",
                options: viewModel.layoutOptions,
                selection: $viewModel.layoutID
            )
        }

        if viewModel.layoutID == "load" {
            loadBreakdown
        } else if viewModel.layoutID == "orders" {
            lawfulOrders
        } else {
            checkpointList
        }

        if let message = viewModel.validationMessage {
            InlineError(message: message)
        }

        CTAButton(
            title: viewModel.orderMatchesStore ? "Order already on the round" : "Apply this order",
            systemImage: "checkmark.circle",
            hint: "Writes the checkpoint list onto the selected round.",
            isEnabled: viewModel.checkpoints.count >= 2
        ) {
            viewModel.applyOrder()
        }

        TextAction(title: "Reset the seeded order", systemImage: "arrow.counterclockwise") {
            viewModel.resetOrder()
        }

        SectionCard(title: "Order on the round") {
            DetailRow(
                label: "Applied order",
                value: viewModel.store.selectedRound.stopIds.map { viewModel.nickname(for: $0) }.joined(separator: " → "),
                isProminent: true
            )
            LedgerRow(label: "Stops", value: "\(viewModel.store.selectedRound.stopIds.count)")
            LedgerRow(label: "Budget", value: "\(viewModel.store.selectedRound.morningBudgetMinutes) min")
            LedgerRow(label: "Draft matches", value: viewModel.orderMatchesStore ? "yes" : "no")
        }
    }

    private var checkpointList: some View {
        VStack(alignment: .leading, spacing: AppMetrics.contentSpacing) {
            SectionLabel(title: "Checkpoints", detail: "\(viewModel.checkpoints.count)")

            SectionCard {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.checkpoints.enumerated()), id: \.element.id) { index, stop in
                        if index > 0 { IndexRule() }
                        checkpointRow(stop)
                    }
                }
            }
        }
    }

    private func checkpointRow(_ stop: VisitStop) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 12) {
                Text(viewModel.indexTitle(for: stop.id))
                    .font(AppType.figure(21))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 22, alignment: .leading)
                    .accessibilityLabel("Stop \(viewModel.indexTitle(for: stop.id))")

                VStack(alignment: .leading, spacing: 4) {
                    Text(stop.nickname)
                        .font(AppType.rowStrong)
                        .foregroundStyle(AppTheme.ink)

                    Text("\(stop.floor) · \(stop.entryNote)")
                        .font(AppType.caption)
                        .foregroundStyle(AppTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(spacing: 6) {
                    moveButton(symbol: "chevron.up", label: "Move \(stop.nickname) earlier", enabled: viewModel.canMove(stop.id, by: -1)) {
                        viewModel.moveStop(id: stop.id, by: -1)
                    }

                    moveButton(symbol: "chevron.down", label: "Move \(stop.nickname) later", enabled: viewModel.canMove(stop.id, by: 1)) {
                        viewModel.moveStop(id: stop.id, by: 1)
                    }
                }
            }

            LedgerRow(
                label: "Window",
                value: "\(viewModel.clockHour(stop.windowStartHour))–\(viewModel.clockHour(stop.windowEndHour)) · \(stop.dwellMinutes) min"
            )
            LedgerRow(label: "Hop in", value: viewModel.hopCaption(for: stop))
            DetailRow(label: "Parking", value: stop.parkingNote)
            DetailRow(label: "Pet", value: stop.petNote)
        }
        .padding(.vertical, 12)
    }

    private func moveButton(
        symbol: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(enabled ? AppTheme.ink : AppTheme.inkFaint)
                .frame(width: 30, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppTheme.surfaceLow.opacity(enabled ? 0.9 : 0.4))
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private var lawfulOrders: some View {
        VStack(alignment: .leading, spacing: AppMetrics.contentSpacing) {
            SectionLabel(title: "Lawful orders", detail: "\(viewModel.proposals.count)")

            ForEach(viewModel.proposals) { proposal in
                SectionCard(title: proposal.strategy.title, footnote: proposal.strategy.note) {
                    ForEach(proposal.legs) { leg in
                        LedgerRow(
                            label: "\(leg.index + 1). \(leg.stop.nickname)",
                            value: viewModel.book.clock(leg.arrivalMinutes),
                            tone: leg.arrivesLate ? AppTheme.rust : AppTheme.data
                        )
                    }

                    IndexRule()
                        .padding(.vertical, 4)

                    LedgerRow(
                        label: "Load",
                        value: "\(proposal.loadMinutes) min of \(viewModel.budgetMinutes)",
                        tone: proposal.loadMinutes > viewModel.budgetMinutes ? AppTheme.rust : AppTheme.sage
                    )
                    LedgerRow(label: "Overdue kept", value: "\(proposal.overdueKept)")
                    DetailRow(
                        label: proposal.overflow.isEmpty ? "Saturday list" : "To Saturday",
                        value: proposal.overflow.isEmpty ? "Nothing left over" : proposal.overflowNames,
                        isProminent: !proposal.overflow.isEmpty
                    )

                    TextAction(title: "Lay this order on the builder") {
                        viewModel.applyProposal(proposal)
                    }
                }
            }
        }
    }

    private var loadBreakdown: some View {
        SectionCard(title: "Hop sheet") {
            ForEach(viewModel.checkpoints) { stop in
                LedgerRow(
                    label: "\(viewModel.indexTitle(for: stop.id)) \(stop.nickname)",
                    value: viewModel.loadLineValue(for: stop),
                    tone: viewModel.hopMinutes(before: stop) == nil ? AppTheme.ink : AppTheme.data
                )
            }

            IndexRule()
                .padding(.vertical, 4)

            LedgerRow(label: "Dwell", value: "\(viewModel.dwellMinutes) min")
            LedgerRow(label: "Travel bins", value: "\(viewModel.travelMinutes) min")
            LedgerRow(
                label: "Slack",
                value: "\(viewModel.slackMinutes) min",
                tone: viewModel.slackMinutes < 0 ? AppTheme.rust : AppTheme.sage
            )
            LedgerRow(label: "Budget", value: "\(viewModel.budgetMinutes) min")
        }
    }
}

#Preview {
    RoundBuilderScreen(roundID: "round-01", dependencies: AppDependencies.preview())
}
