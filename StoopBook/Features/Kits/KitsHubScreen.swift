import SwiftUI

@MainActor
struct KitsHubScreen: View {
    private let dependencies: AppDependencies
    @Bindable private var store: StoopBookStore
    @State private var viewModel: KitsHubViewModel
    @Namespace private var zoom

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        store = dependencies.store
        _viewModel = State(initialValue: KitsHubViewModel(dependencies: dependencies))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScreenScaffold {
            masthead

            morningClock

            StreetLine(
                stops: viewModel.stops(in: store.selectedRound),
                focusedStopID: viewModel.lineFocusID,
                state: { viewModel.cadenceState(for: $0) },
                outcome: { viewModel.outcomeMark(for: $0) },
                zoomNamespace: zoom,
                onSelect: { viewModel.focus($0.id) }
            )

            lensRail

            if let focused = viewModel.focusedStop {
                focusCard(for: focused)
            }

            CTAButton(
                title: viewModel.primaryActionTitle,
                systemImage: "square.and.arrow.down",
                hint: "Saves this \(viewModel.lens.title.lowercased()) readout onto \(store.selectedRound.name)"
            ) {
                viewModel.openPrimaryDraft()
            }
            .accessibilityIdentifier("smoke.kitRunner.computeCadence")

            Text(viewModel.lensNote)
                .font(AppType.caption)
                .foregroundStyle(AppTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            lensBody(viewModel: viewModel)
                // One lens replaces another in place. Both are fully legible; the
                // page just does not snap.
                .animation(AppMotion.page, value: viewModel.lens)

            roundsIndex
            kitsIndex
        }
        .navigationTitle("Rounds")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $viewModel.opened) { presented in
            destination(for: presented.route)
        }
        .onChange(of: store.selectedTab) { _, tab in
            if tab != .kits {
                viewModel.opened = nil
            }
        }
        .sensoryFeedback(.selection, trigger: viewModel.lens)
        .sensoryFeedback(.selection, trigger: store.selectedRound.id)
        .sensoryFeedback(.selection, trigger: store.focusedStopID)
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 7) {
            StoopMark(size: 30)
                .padding(.bottom, 2)

            Text(store.selectedRound.name)
                .font(AppType.masthead)
                .foregroundStyle(AppTheme.ink)

            Text(viewModel.ledgerLine(round: store.selectedRound))
                .font(AppType.meta)
                .foregroundStyle(AppTheme.data)
                .fixedSize(horizontal: false, vertical: true)

            // The same survey baseline the other mastheads carry, so the home screen
            // opens the same way every other screen does.
            ZStack(alignment: .leading) {
                DrawnRule(tone: AppTheme.ink.opacity(0.15), duration: 0.55)
                DrawnRule(tone: AppTheme.brass, height: 1.6, duration: 0.42, delay: 0.14, width: 26)
            }
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - The morning on a clock

    /// The round walked on a clock rail: arrival, dwell, hop, and the latest
    /// exit that keeps every later window. The same bins as the load ledger,
    /// spread across hours instead of summed into one number.
    private var morningClock: some View {
        let legs = viewModel.morningLegs
        guard !legs.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            SectionCard(title: "The morning", footnote: viewModel.morningClockFootnote) {
                VStack(spacing: 0) {
                    ForEach(Array(legs.enumerated()), id: \.element.id) { index, leg in
                        if index > 0 {
                            IndexRule()
                        }
                        clockRow(leg)
                    }
                }

                IndexRule()
                    .padding(.vertical, 4)

                TextAction(title: "Order the morning", systemImage: "slider.horizontal.3") {
                    viewModel.openRoundBuilder()
                }
                .accessibilityIdentifier("smoke.hub.orderMorning")
            }
        )
    }

    private func clockRow(_ leg: MorningLeg) -> some View {
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(viewModel.book.clock(leg.arrivalMinutes))
                .font(AppType.figure(15))
                .foregroundStyle(leg.arrivesLate ? AppTheme.rust : AppTheme.ink)
                .monospacedDigit()
                .frame(width: 74, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(leg.stop.nickname)
                    .font(AppType.rowStrong)
                    .foregroundStyle(AppTheme.ink)
                HStack(spacing: 6) {
                    if let hop = leg.hopMinutes, let title = leg.hopTitle {
                        Text("\(title.lowercased()) \(hop) min")
                            .font(AppType.micro)
                            .foregroundStyle(AppTheme.data)
                    }
                    Text("dwell \(leg.dwellMinutes)")
                        .font(AppType.micro)
                        .foregroundStyle(AppTheme.data)
                    if leg.arrivesLate {
                        Text("after window")
                            .font(AppType.micro)
                            .foregroundStyle(AppTheme.rust)
                    }
                }
            }

            Spacer(minLength: 8)

            if let leaveBy = leg.leaveByMinutes {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("out by")
                        .font(AppType.micro)
                        .foregroundStyle(AppTheme.inkSoft)
                    Text(viewModel.book.clock(leaveBy))
                        .font(AppType.figure(13))
                        .foregroundStyle(AppTheme.data)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(leg.stop.nickname) at \(viewModel.book.clock(leg.arrivalMinutes)), dwell \(leg.dwellMinutes) minutes\(leg.leaveByMinutes.map { ", out by \(viewModel.book.clock($0))" } ?? "")")
    }

    // MARK: - Lenses

    private var lensRail: some View {
        TabStrip(
            items: HubLens.allCases,
            title: { $0.title },
            isSelected: { viewModel.lens == $0 },
            onSelect: { viewModel.selectLens($0) },
            spacing: 20
        )
    }

    // MARK: - The stop you are on

    private func focusCard(for stop: VisitStop) -> some View {
        SectionCard(title: stop.nickname) {
            LedgerRow(
                label: "Cadence",
                value: viewModel.cadenceValue(for: stop),
                tone: viewModel.cadenceState(for: stop).tone
            )
            LedgerRow(label: "Window", value: viewModel.windowLabel(for: stop))
            LedgerRow(label: "Dwell", value: "\(stop.dwellMinutes) min")
            LedgerRow(label: "Block", value: viewModel.placeName(for: stop))

            DetailRow(label: "Entry", value: stop.entryNote)
            DetailRow(label: "Pet", value: stop.petNote)
            DetailRow(label: "Parking", value: stop.parkingNote)

            IndexRule()
                .padding(.vertical, 4)

            // Close the visit: the four ends a door can have. Seen restarts the
            // cadence clock today; the others leave the debt standing and flag
            // the house on the book.
            HStack(spacing: 8) {
                outcomeButton(VisitOutcome.seen, stop: stop)
                outcomeButton(VisitOutcome.noAnswer, stop: stop)
                outcomeButton(VisitOutcome.blocked, stop: stop)
                outcomeButton(VisitOutcome.skipped, stop: stop)
            }

            if let last = viewModel.lastOutcome(for: stop) {
                Text("Closed \(last.outcome.title.lowercased()) — \(last.outcome.caption)")
                    .font(AppType.micro)
                    .foregroundStyle(AppTheme.data)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextAction(title: "Open the household card") {
                viewModel.openStop(stop.id)
            }
        }
    }

    private func outcomeButton(_ outcome: VisitOutcome, stop: VisitStop) -> some View {
        let isLatest = viewModel.lastOutcome(for: stop)?.outcome == outcome
        return Button {
            viewModel.closeVisit(outcome, stop: stop)
        } label: {
            Label(outcome.title, systemImage: outcome.glyph)
                .font(AppType.micro)
                .foregroundStyle(isLatest ? AppTheme.paper : AppTheme.ink)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isLatest ? AppTheme.ink : AppTheme.surfaceLow)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(outcome.title) \(stop.nickname)")
    }

    // MARK: - Lens bodies

    @ViewBuilder
    private func lensBody(viewModel: KitsHubViewModel) -> some View {
        switch viewModel.lens {
        case .cadence:
            cadenceLedger
        case .windows:
            clashLedger
        case .blocks:
            blockLedger
        case .load:
            loadLedger
        }
    }

    @ViewBuilder
    private var cadenceLedger: some View {
        let overdue = viewModel.overdueStops(in: store.selectedRound)
        let dueToday = viewModel.dueTodayStops(in: store.selectedRound)
        let ahead = viewModel.aheadStops(in: store.selectedRound)

        if overdue.isEmpty && dueToday.isEmpty {
            EmptyStateCard(
                title: "Nobody overdue",
                message: "Every household on \(store.selectedRound.name) is inside its interval. The line still shows the days each one has left.",
                actionTitle: "Open the cadence kit"
            ) {
                viewModel.openKit(.cadence)
            }
        }

        if !overdue.isEmpty {
            ledger(title: "Past cadence", detail: "\(overdue.count)", tone: AppTheme.rust) {
                ForEach(overdue) { stop in
                    LedgerRow(
                        label: stop.nickname,
                        value: "\(viewModel.daysPastCadence(stop))d over",
                        tone: AppTheme.rust
                    )
                }
            }
        }

        if !dueToday.isEmpty {
            ledger(title: "Due today", detail: "\(dueToday.count)", tone: AppTheme.accent) {
                ForEach(dueToday) { stop in
                    LedgerRow(label: stop.nickname, value: "due", tone: AppTheme.accent)
                }
            }
        }

        if !ahead.isEmpty {
            ledger(title: "Inside cadence", detail: "\(ahead.count)", tone: AppTheme.sage) {
                ForEach(ahead) { stop in
                    LedgerRow(
                        label: stop.nickname,
                        value: "\(max(0, stop.cadenceDays - stop.lastVisitDayOffset))d left",
                        tone: AppTheme.sage
                    )
                }
            }
        }
    }

    private var clashLedger: some View {
        let pairs = viewModel.clashPairs(in: store.selectedRound)
        return Group {
            if pairs.isEmpty {
                EmptyStateCard(
                    title: "No window clash",
                    message: "The windows on \(store.selectedRound.name) stay clear once the travel bins are added.",
                    actionTitle: "Open window fit"
                ) {
                    viewModel.openKit(.windowFit)
                }
            } else {
                ledger(title: "Windows that collide", detail: "\(pairs.count)", tone: AppTheme.rust) {
                    ForEach(pairs) { pair in
                        LedgerRow(
                            label: pair.first.nickname,
                            value: viewModel.windowLabel(for: pair.first),
                            tone: AppTheme.rust
                        )
                        LedgerRow(label: pair.second.nickname, value: viewModel.windowLabel(for: pair.second))
                        DetailRow(label: "Hop", value: pair.binTitle, isProminent: true)
                    }
                }
            }
        }
    }

    private var blockLedger: some View {
        let groups = viewModel.clusters(in: store.selectedRound).filter { $0.nicknames.count > 1 }
        return Group {
            if groups.isEmpty {
                EmptyStateCard(
                    title: "No shared blocks",
                    message: "No two stoops on \(store.selectedRound.name) land inside the planning radius. The kit takes a different one.",
                    actionTitle: "Open the cluster kit"
                ) {
                    viewModel.openKit(.cluster)
                }
            } else {
                ledger(title: "Same block", detail: "\(groups.count)", tone: AppTheme.ink) {
                    ForEach(groups) { group in
                        LedgerRow(label: group.title, value: "\(group.nicknames.count) stoops")
                        DetailRow(label: "Households", value: group.nicknames.joined(separator: " · "))
                    }
                }
            }
        }
    }

    private var loadLedger: some View {
        let minutes = viewModel.loadMinutes(for: store.selectedRound)
        let dwell = viewModel.stops(in: store.selectedRound).reduce(0) { $0 + $1.dwellMinutes }
        let budget = store.selectedRound.morningBudgetMinutes
        let slack = budget - minutes

        return ledger(title: "Round load", detail: "\(minutes) min", tone: slack < 0 ? AppTheme.rust : AppTheme.sage) {
            LedgerRow(label: "Dwell", value: "\(dwell) min")
            LedgerRow(label: "Travel bins", value: "\(max(0, minutes - dwell)) min")
            LedgerRow(label: "Budget", value: "\(budget) min")
            LedgerRow(
                label: slack < 0 ? "Over budget" : "Slack",
                value: "\(abs(slack)) min",
                tone: slack < 0 ? AppTheme.rust : AppTheme.sage
            )
            if let run = store.activeRun {
                LedgerRow(label: "Circuit", value: viewModel.progressCaption(run: run, round: store.selectedRound))
            }
        }
    }

    private func ledger<Content: View>(
        title: String,
        detail: String,
        tone: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        SectionCard {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(AppType.title)
                    .foregroundStyle(tone)

                Spacer(minLength: 0)

                Text(detail)
                    .font(AppType.meta)
                    .foregroundStyle(AppTheme.data)
            }
            .padding(.bottom, 2)

            content()
        }
    }

    // MARK: - Rounds and kits

    private var roundsIndex: some View {
        VStack(alignment: .leading, spacing: AppMetrics.contentSpacing) {
            SectionLabel(title: "Rounds", detail: "\(viewModel.rounds.count)")

            SectionCard {
                VStack(spacing: 2) {
                    ForEach(viewModel.rounds) { round in
                        roundRow(round)
                    }
                }
            }
        }
    }

    private func roundRow(_ round: VisitRound) -> some View {
        let isSelected = round.id == store.selectedRound.id

        return Button {
            withAnimation(AppMotion.quick) {
                viewModel.selectRound(round)
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(round.name)
                    .font(AppType.rowStrong)
                    .foregroundStyle(isSelected ? AppTheme.paper : AppTheme.ink)

                Spacer(minLength: 8)

                Text(viewModel.roundCaption(round))
                    .font(AppType.micro)
                    .foregroundStyle(isSelected ? AppTheme.paper.opacity(0.78) : AppTheme.data)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.ink)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(round.name), \(viewModel.roundCaption(round))")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var kitsIndex: some View {
        VStack(alignment: .leading, spacing: AppMetrics.contentSpacing) {
            SectionLabel(title: "Kits", detail: "\(viewModel.kits.count)")

            SectionCard {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.kits.enumerated()), id: \.element.id) { index, kit in
                        if index > 0 {
                            Capsule()
                                .fill(AppTheme.edge)
                                .frame(height: 1)
                        }

                        KitRow(
                            kind: kit.kind,
                            title: kit.title,
                            summary: kit.summary,
                            trailing: kit.kind.usesRadius ? "radius" : "typed"
                        ) {
                            viewModel.openKit(kit.kind)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .kit(let kind):
            KitRunnerScreen(kitKind: kind, dependencies: dependencies)
        case .roundBuilder(let roundID):
            RoundBuilderScreen(roundID: roundID, dependencies: dependencies)
        case .saveDraft(let draft):
            ReadingSaveScreen(draft: draft, dependencies: dependencies)
        case .readingDetail(let readingID):
            ReadingDetailScreen(readingID: readingID, dependencies: dependencies)
        case .stopDetail(let stopID):
            VisitStopDetailView(stopID: stopID, dependencies: dependencies)
                .zoomOpen(stopID, in: zoom)
        case .comparePair(let pairID):
            CompareReadingsScreen(pairID: pairID, dependencies: dependencies)
        case .exportPack(let roundID):
            ExportReadingsScreen(roundID: roundID, dependencies: dependencies)
        }
    }
}

private enum HubLens: String, CaseIterable, Identifiable {
    case cadence
    case windows
    case blocks
    case load

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cadence: return "Cadence"
        case .windows: return "Windows"
        case .blocks: return "Blocks"
        case .load: return "Load"
        }
    }

    var kit: VisitKitKind {
        switch self {
        case .cadence: return .cadence
        case .windows: return .windowFit
        case .blocks: return .cluster
        case .load: return .roundLoad
        }
    }

    var note: String {
        switch self {
        case .cadence: return "Last visit day against each agreed interval. Overdue households are the ones worth a call."
        case .windows: return "Two consecutive stoops whose typed windows collide once the pin-to-pin planning bin is added."
        case .blocks: return "Households that share a block, taken from stored pins and a metre radius."
        case .load: return "Dwell plus binned travel against the morning budget."
        }
    }
}

private struct HubClashPair: Identifiable {
    let first: VisitStop
    let second: VisitStop
    let binTitle: String

    var id: String { "\(first.id).\(second.id)" }
}

private struct HubClusterGroup: Identifiable {
    let id: String
    let nicknames: [String]

    var title: String { nicknames.first ?? "Cluster" }
}

private struct PresentedHubRoute: Identifiable, Hashable {
    let route: AppRoute

    var id: String {
        switch route {
        case .kit(let kind):
            return "kit-\(kind.rawValue)"
        case .roundBuilder(let roundID):
            return "roundBuilder-\(roundID)"
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
        }
    }
}

@MainActor
@Observable
private final class KitsHubViewModel {
    var lens: HubLens = .cadence
    var opened: PresentedHubRoute?
    var selectedKind: VisitKitKind = .cadence

    private let store: StoopBookStore
    private let stopRepository: any VisitStopRepository
    private let roundRepository: any VisitRoundRepository
    private let placeRepository: any NeighbourhoodPlaceRepository
    private let readingEngine: ReadingEngine
    private let patrolEngine: PatrolEngine

    private let sameBlockMetres = 250.0

    init(dependencies: AppDependencies) {
        store = dependencies.store
        stopRepository = dependencies.stopRepository
        roundRepository = dependencies.roundRepository
        placeRepository = dependencies.placeRepository
        readingEngine = dependencies.readingEngine
        patrolEngine = dependencies.patrolEngine
    }

    var kits: [VisitKit] { StoopBookSeed.kits }
    var rounds: [VisitRound] { roundRepository.listedRounds() }

    var focusedStop: VisitStop? {
        guard let id = store.focusedStopID else { return nil }
        guard let raw = stopRepository.stop(id: id) else { return nil }
        return store.resolvedStop(raw)
    }

    /// The house the line draws in ink. Nothing is in hand on a first open, and a
    /// line with every house alike reads as a diagram rather than a morning, so the
    /// round's first household stands in until a person picks another one.
    var lineFocusID: String? {
        let round = stops(in: store.selectedRound)
        if let id = store.focusedStopID, round.contains(where: { $0.id == id }) {
            return id
        }
        return round.first?.id
    }

    // MARK: The morning on a clock

    let book = MorningBook()

    var morningLegs: [MorningLeg] {
        book.timeline(round: store.selectedRound, stops: stops(in: store.selectedRound))
    }

    var morningClockFootnote: String {
        let minutes = loadMinutes(for: store.selectedRound)
        let slack = store.selectedRound.morningBudgetMinutes - minutes
        let leaves = book.clock(MorningBook().dayStartMinutes)
        if slack < 0 {
            return "\(leaves) · \(abs(slack)) min over budget · \(morningLegs.last.map { book.clock($0.departureMinutes) } ?? "-") finish"
        }
        return "\(leaves) · \(slack) min of slack · \(morningLegs.last.map { book.clock($0.departureMinutes) } ?? "-") finish"
    }

    // MARK: Closing visits

    func closeVisit(_ outcome: VisitOutcome, stop: VisitStop) {
        store.recordOutcome(outcome, stopID: stop.id)
    }

    /// The builder is where an order is chosen, so the clock leads there.
    func openRoundBuilder() {
        opened = PresentedHubRoute(route: .roundBuilder(store.selectedRound.id))
    }

    func lastOutcome(for stop: VisitStop) -> VisitOutcomeRecord? {
        store.outcomes(for: stop.id).max { $0.dayOffset < $1.dayOffset }
    }

    /// The flag under a house on the line: only unfinished visits raise one.
    func outcomeMark(for stop: VisitStop) -> VisitOutcome? {
        lastOutcome(for: stop)?.outcome == .seen ? nil : lastOutcome(for: stop)?.outcome
    }

    // MARK: Copy

    var primaryActionTitle: String {
        switch lens {
        case .cadence: return "Save the cadence readout"
        case .windows: return "Save the window check"
        case .blocks: return "Save the block grouping"
        case .load: return "Save the round load"
        }
    }

    var lensNote: String { lens.note }

    func ledgerLine(round: VisitRound) -> String {
        let overdue = overdueStops(in: round).count
        let done = store.activeRun.map { patrolEngine.progressRatio(run: $0, round: roundForActiveRun(fallback: round)) } ?? 0
        let percent = Int((done * 100).rounded())
        return "\(round.stopIds.count) stoops · \(round.morningBudgetMinutes) min budget · \(overdue) overdue · \(loadMinutes(for: round)) min load · \(percent)% done"
    }

    func roundCaption(_ round: VisitRound) -> String {
        "\(round.stopIds.count) stops · \(overdueStops(in: round).count) overdue"
    }

    func progressCaption(run: PatrolRun, round: VisitRound) -> String {
        let percent = Int((patrolEngine.progressRatio(run: run, round: round) * 100).rounded())
        return "\(run.completedStopIds.count) of \(round.stopIds.count) · \(percent)%"
    }

    func daysPastCadence(_ stop: VisitStop) -> Int {
        max(0, stop.lastVisitDayOffset - stop.cadenceDays)
    }

    // MARK: Actions

    func focus(_ stopID: String) {
        store.focusStop(stopID)
    }

    func selectLens(_ lens: HubLens) {
        withAnimation(AppMotion.quick) {
            self.lens = lens
            selectedKind = lens.kit
        }
    }

    func selectRound(_ round: VisitRound) {
        store.selectRound(round)
    }

    func openKit(_ kind: VisitKitKind) {
        selectedKind = kind
        opened = PresentedHubRoute(route: .kit(kind))
    }

    /// The primary action saves the readout for the lens being read, so the page a
    /// person is looking at is the page that ends up on the visit.
    func openPrimaryDraft() {
        let round = store.selectedRound
        let runID = store.activeRun?.id ?? "run-08"
        let draft: ReadingDraft

        switch lens {
        case .cadence:
            let overdue = overdueStops(in: round)
            let due = dueTodayStops(in: round)
            let names = overdue.map(\.nickname)
            let readout = names.isEmpty
                ? "Nobody overdue on \(round.name). \(due.count) due today."
                : "\(names.joined(separator: ", ")) overdue on \(round.name)"
            draft = ReadingDraft(
                id: "draft-cadence-hub",
                kind: .cadence,
                readout: readout,
                stopIds: (overdue.isEmpty ? Array(stops(in: round).prefix(4)) : overdue).map(\.id),
                primaryValue: Double(overdue.count),
                note: "cadence",
                runId: runID
            )

        case .windows:
            let pairs = clashPairs(in: round)
            let readout = pairs.isEmpty
                ? "No window clash on \(round.name) after the travel bins"
                : "\(pairs.count) window clash on \(round.name) after the travel bins"
            draft = ReadingDraft(
                id: "draft-window-hub",
                kind: .windowFit,
                readout: readout,
                stopIds: pairs.flatMap { [$0.first.id, $0.second.id] },
                primaryValue: Double(pairs.count),
                note: "window fit",
                runId: runID
            )

        case .blocks:
            let groups = clusters(in: round).filter { $0.nicknames.count > 1 }
            let largest = groups.map { $0.nicknames.count }.max() ?? 0
            let readout = "\(round.name) shares \(groups.count) block groups, largest \(largest) stoops"
            draft = ReadingDraft(
                id: "draft-block-hub",
                kind: .cluster,
                readout: readout,
                stopIds: stops(in: round).map(\.id),
                primaryValue: Double(largest),
                note: "cluster",
                runId: runID
            )

        case .load:
            let minutes = loadMinutes(for: round)
            let slack = round.morningBudgetMinutes - minutes
            let readout = slack < 0
                ? "\(round.name) is \(abs(slack)) minutes over a \(round.morningBudgetMinutes)-minute budget"
                : "\(round.name) load sits \(slack) minutes under the morning budget"
            draft = ReadingDraft(
                id: "draft-load-hub",
                kind: .roundLoad,
                readout: readout,
                stopIds: round.stopIds,
                primaryValue: Double(minutes),
                note: "round load",
                runId: runID
            )
        }

        opened = PresentedHubRoute(route: .saveDraft(draft))
    }

    func openStop(_ stopID: String) {
        store.focusStop(stopID)
        opened = PresentedHubRoute(route: .stopDetail(stopID))
    }

    // MARK: Data

    func stops(in round: VisitRound) -> [VisitStop] {
        store.resolvedStops(round.stopIds.compactMap { stopRepository.stop(id: $0) })
    }

    func cadenceState(for stop: VisitStop) -> CadenceState {
        readingEngine.cadenceState(for: stop)
    }

    func cadenceValue(for stop: VisitStop) -> String {
        let state = readingEngine.cadenceState(for: stop)
        return "\(state.title) · last \(stop.lastVisitDayOffset)d · every \(stop.cadenceDays)d"
    }

    func overdueStops(in round: VisitRound) -> [VisitStop] {
        stops(in: round).filter { readingEngine.cadenceState(for: $0) == .overdue }
    }

    func dueTodayStops(in round: VisitRound) -> [VisitStop] {
        stops(in: round).filter { readingEngine.cadenceState(for: $0) == .dueToday }
    }

    func aheadStops(in round: VisitRound) -> [VisitStop] {
        stops(in: round).filter { readingEngine.cadenceState(for: $0) == .ahead }
    }

    func windowLabel(for stop: VisitStop) -> String {
        "\(clockHour(stop.windowStartHour))–\(clockHour(stop.windowEndHour))"
    }

    func placeName(for stop: VisitStop) -> String {
        placeRepository.place(id: stop.neighbourhoodId)?.name ?? stop.neighbourhoodId
    }

    func loadMinutes(for round: VisitRound) -> Int {
        patrolEngine.loadMinutes(round: round, stops: stops(in: round))
    }

    func clashPairs(in round: VisitRound) -> [HubClashPair] {
        let ordered = stops(in: round)
        guard ordered.count > 1 else { return [] }
        var pairs: [HubClashPair] = []
        for index in 0..<(ordered.count - 1) {
            let first = ordered[index]
            let second = ordered[index + 1]
            let bin = readingEngine.pinTravel(from: first, to: second)
            let minutes = patrolEngine.planningMinutes(for: bin)
            if readingEngine.windowClash(first: first, second: second, travelMinutes: minutes) {
                pairs.append(HubClashPair(first: first, second: second, binTitle: bin.title))
            }
        }
        return pairs
    }

    func clusters(in round: VisitRound) -> [HubClusterGroup] {
        let roundStops = stops(in: round)
        let groups = readingEngine.clusterStopIDs(roundStops, radiusMetres: sameBlockMetres)
        return groups.map { ids in
            let names = ids.compactMap { stopRepository.stop(id: $0)?.nickname }
            return HubClusterGroup(id: ids.joined(separator: "."), nicknames: names)
        }
    }

    // MARK: Helpers

    private func roundForActiveRun(fallback: VisitRound) -> VisitRound {
        guard let roundID = store.activeRun?.roundId else { return fallback }
        return roundRepository.round(id: roundID) ?? fallback
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
        KitsHubScreen(dependencies: .preview())
    }
}
