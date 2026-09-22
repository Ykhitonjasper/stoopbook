import SwiftUI

@MainActor
@Observable
private final class KitRunnerViewModel {
    let dependencies: AppDependencies
    var kitKind: VisitKitKind
    var kitKindID: String
    var familyID: String
    var radiusText: String
    var budgetText: String
    var travelMinutesText: String
    var travelSourceID: String
    var selectedBinID: String
    var radiusPresetID: String
    var firstStopID: String
    var secondStopID: String
    var droppedStopID: String
    var accessStopID: String
    var selectedCadenceIDs: [String]
    var presentedDraft: ReadingDraft?
    var currentDraft: ReadingDraft?
    var pendingRoute: AppRoute?
    var validationMessage: String?
    var didCompute = false
    var computeCount = 0
    var readoutLabel = "Readout"
    var readoutValue = "0"
    var readoutUnit: String?
    var readoutContext: String?
    var readoutNote: String?
    var secondaryLines: [ResultLine] = []
    var helperLines: [ResultLine] = []
    var clusterGroups: [ClusterGroup] = []
    var cadenceRows: [CadenceRow] = []
    private var draftSerial = 0

    struct CadenceRow: Identifiable, Hashable {
        let id: String
        let nickname: String
        let stateTitle: String
        let daysSince: String
        let window: String
    }

    struct ClusterGroup: Identifiable, Hashable {
        let id: String
        let stopIDs: [String]
        var count: Int { stopIDs.count }
    }

    init(kitKind: VisitKitKind, dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.kitKind = kitKind
        kitKindID = kitKind.id
        familyID = KitRunnerViewModel.familyID(for: kitKind)
        radiusText = "250"
        budgetText = "\(dependencies.store.selectedRound.morningBudgetMinutes)"
        travelMinutesText = "6"
        travelSourceID = "typed"
        selectedBinID = TravelBin.walkShort.id
        radiusPresetID = "250"
        let ids = KitRunnerViewModel.northLoopIDs(from: dependencies)
        firstStopID = ids.first ?? "visit-01"
        secondStopID = ids.count > 1 ? ids[1] : (ids.first ?? "visit-02")
        droppedStopID = ids.contains("visit-03") ? "visit-03" : (ids.last ?? "visit-03")
        accessStopID = ids.first ?? "visit-01"
        selectedCadenceIDs = ids
    }

    var store: StoopBookStore { dependencies.store }
    var readingEngine: ReadingEngine { dependencies.readingEngine }
    var patrolEngine: PatrolEngine { dependencies.patrolEngine }

    var kits: [VisitKit] { StoopBookSeed.kits }

    var activeKit: VisitKit? {
        kits.first { $0.kind == kitKind }
    }

    var familyOptions: [SegmentOption] {
        [
            SegmentOption("Schedule", id: "schedule"),
            SegmentOption("Pins", id: "pins"),
            SegmentOption("Circuit", id: "circuit")
        ]
    }

    var kitOptions: [SegmentOption] {
        kinds(in: familyID).map { kind in
            SegmentOption(shortTitle(for: kind), id: kind.id)
        }
    }

    var travelSourceOptions: [SegmentOption] {
        [
            SegmentOption("Typed", id: "typed"),
            SegmentOption("Bin", id: "bin")
        ]
    }

    var binOptions: [SegmentOption] {
        TravelBin.allCases.map { SegmentOption($0.title, id: $0.id) }
    }

    var radiusPresetOptions: [SegmentOption] {
        [
            SegmentOption("150 m", id: "150"),
            SegmentOption("250 m", id: "250"),
            SegmentOption("400 m", id: "400"),
            SegmentOption("Typed", id: "typed")
        ]
    }

    var northLoop: VisitRound {
        dependencies.roundRepository.round(id: "round-01") ?? store.selectedRound
    }

    var northLoopStops: [VisitStop] {
        northLoop.stopIds.compactMap { dependencies.stopRepository.stop(id: $0) }
    }

    var listedStops: [VisitStop] {
        dependencies.stopRepository.listedStops()
    }

    var selectedCadenceStops: [VisitStop] {
        selectedCadenceIDs.compactMap { dependencies.stopRepository.stop(id: $0) }
    }

    var firstStop: VisitStop? { dependencies.stopRepository.stop(id: firstStopID) }
    var secondStop: VisitStop? { dependencies.stopRepository.stop(id: secondStopID) }
    var droppedStop: VisitStop? { dependencies.stopRepository.stop(id: droppedStopID) }
    var accessStop: VisitStop? { dependencies.stopRepository.stop(id: accessStopID) }

    var computeTitle: String {
        switch kitKind {
        case .cadence: return "Compute cadence"
        case .windowFit: return "Check window fit"
        case .pinTravel: return "Bin pin travel"
        case .cluster: return "Group the cluster"
        case .accessNotes: return "Check access notes"
        case .roundLoad: return "Sum round load"
        case .skipCost: return "Price the skip"
        }
    }

    var canOpenDraft: Bool { currentDraft != nil }

    var radiusError: String? {
        guard kitKind.usesRadius, radiusPresetID == "typed" else { return nil }
        return parsedPositive(radiusText) == nil ? "Enter a radius greater than zero." : nil
    }

    var budgetError: String? {
        guard kitKind == .roundLoad else { return nil }
        return parsedInt(budgetText) == nil ? "Enter a morning budget in minutes." : nil
    }

    var travelError: String? {
        guard kitKind == .windowFit, travelSourceID == "typed" else { return nil }
        return parsedInt(travelMinutesText) == nil ? "Enter travel minutes as a whole number." : nil
    }

    var pairError: String? {
        guard kitKind == .windowFit || kitKind == .pinTravel else { return nil }
        if firstStopID == secondStopID {
            return "Pick two different households for this kit."
        }
        return nil
    }

    var cadenceError: String? {
        guard kitKind == .cadence else { return nil }
        return selectedCadenceStops.isEmpty ? "Select at least one North Loop household." : nil
    }

    var headerSubtitle: String {
        if let kit = activeKit {
            return kit.prompt
        }
        return "Typed inputs against the North Loop pins."
    }

    var activeRunCaption: String {
        if let run = store.activeRun {
            return run.summary
        }
        return "No active circuit on the book."
    }

    var progressCaption: String {
        guard let run = store.activeRun else { return "none" }
        let ratio = patrolEngine.progressRatio(run: run, round: store.selectedRound)
        let percent = Int((ratio * 100).rounded())
        return "\(run.completedStopIds.count) of \(store.selectedRound.stopIds.count) · \(percent)%"
    }

    func applyFamily(_ id: String) {
        familyID = id
        let kinds = kinds(in: id)
        if !kinds.contains(kitKind), let first = kinds.first {
            kitKind = first
            kitKindID = first.id
        }
        clearValidation()
    }

    func applyKit(_ id: String) {
        kitKindID = id
        if let kind = VisitKitKind(rawValue: id) {
            kitKind = kind
            familyID = KitRunnerViewModel.familyID(for: kind)
        }
        if kitKind.usesRadius, radiusPresetID != "typed" {
            radiusText = radiusPresetID
        }
        if kitKind == .roundLoad {
            budgetText = "\(store.selectedRound.morningBudgetMinutes)"
        }
        clearValidation()
    }

    func applyRadiusPreset(_ id: String) {
        radiusPresetID = id
        if id != "typed" {
            radiusText = id
        }
        clearValidation()
    }

    func toggleCadence(stopID: String) {
        if let index = selectedCadenceIDs.firstIndex(of: stopID) {
            selectedCadenceIDs.remove(at: index)
        } else {
            selectedCadenceIDs.append(stopID)
        }
        clearValidation()
    }

    func isCadenceSelected(_ stopID: String) -> Bool {
        selectedCadenceIDs.contains(stopID)
    }

    func selectFirst(_ stopID: String) {
        firstStopID = stopID
        if secondStopID == stopID, let other = northLoopStops.first(where: { $0.id != stopID }) {
            secondStopID = other.id
        }
        clearValidation()
    }

    func selectSecond(_ stopID: String) {
        secondStopID = stopID
        if firstStopID == stopID, let other = northLoopStops.first(where: { $0.id != stopID }) {
            firstStopID = other.id
        }
        clearValidation()
    }

    func computeSelectedKit() {
        switch kitKind {
        case .cadence:
            computeCadence()
        case .windowFit:
            computeWindowFit()
        case .pinTravel:
            computePinTravel()
        case .cluster:
            computeCluster()
        case .accessNotes:
            computeAccessNotes()
        case .roundLoad:
            computeRoundLoad()
        case .skipCost:
            computeSkipCost()
        }
    }

    func computeCadence() {
        let stops = selectedCadenceStops
        guard !stops.isEmpty else {
            validationMessage = "Select at least one North Loop household."
            return
        }
        let rows = stops.map { stop in
            let state = readingEngine.cadenceState(for: dependencies.store.resolvedStop(stop))
            return CadenceRow(
                id: stop.id,
                nickname: stop.nickname,
                stateTitle: state.title,
                daysSince: "\(stop.lastVisitDayOffset)d",
                window: "\(clockHour(stop.windowStartHour))–\(clockHour(stop.windowEndHour))"
            )
        }
        cadenceRows = rows
        let overdue = stops.map { dependencies.store.resolvedStop($0) }.filter { readingEngine.cadenceState(for: $0) == .overdue }
        let dueToday = stops.filter { readingEngine.cadenceState(for: $0) == .dueToday }
        let ahead = stops.filter { readingEngine.cadenceState(for: $0) == .ahead }
        let overdueNames = overdue.map(\.nickname)
        let readout: String
        if overdueNames.isEmpty {
            readout = "No North Loop household is overdue on a \(stops.count)-stop check."
        } else {
            readout = "\(overdueNames.joined(separator: ", ")) overdue on North Loop"
        }
        readoutLabel = "Cadence"
        readoutValue = "\(overdue.count)"
        readoutUnit = "overdue"
        readoutContext = "\(dueToday.count) due today · \(ahead.count) ahead"
        readoutNote = readout
        secondaryLines = [
            ResultLine(label: "Households checked", value: "\(stops.count)"),
            ResultLine(label: "Due today", value: "\(dueToday.count)"),
            ResultLine(label: "Ahead", value: "\(ahead.count)"),
            ResultLine(label: "Circuit", value: northLoop.name)
        ]
        helperLines = rows.prefix(4).map { row in
            ResultLine(label: row.nickname, value: row.stateTitle)
        }
        clusterGroups = []
        publishDraft(
            kind: .cadence,
            readout: readout,
            stopIds: stops.map(\.id),
            primaryValue: Double(overdue.count),
            note: "cadence",
            presentSave: true
        )
    }

    func computeWindowFit() {
        guard let first = firstStop, let second = secondStop else {
            validationMessage = "North Loop is missing one of the selected households."
            return
        }
        if first.id == second.id {
            validationMessage = "Pick two different households for this kit."
            return
        }
        let minutes: Int
        if travelSourceID == "bin", let bin = TravelBin(rawValue: selectedBinID) {
            minutes = patrolEngine.planningMinutes(for: bin)
        } else if let typed = parsedInt(travelMinutesText) {
            minutes = typed
        } else {
            validationMessage = "Enter travel minutes as a whole number."
            return
        }
        let clash = readingEngine.windowClash(first: first, second: second, travelMinutes: minutes)
        let readout = clash
            ? "\(first.nickname) and \(second.nickname) windows clash after a \(minutes)-minute hop"
            : "\(first.nickname) and \(second.nickname) windows stay clear after \(minutes) minutes"
        readoutLabel = "Window fit"
        readoutValue = clash ? "Clash" : "Clear"
        readoutUnit = nil
        readoutContext = "\(clockHour(first.windowStartHour))–\(clockHour(first.windowEndHour)) then \(clockHour(second.windowStartHour))–\(clockHour(second.windowEndHour))"
        readoutNote = readout
        secondaryLines = [
            ResultLine(label: "First dwell", value: "\(first.dwellMinutes) min"),
            ResultLine(label: "Second dwell", value: "\(second.dwellMinutes) min"),
            ResultLine(label: "Travel used", value: "\(minutes) min"),
            ResultLine(label: "Source", value: travelSourceID == "bin" ? (TravelBin(rawValue: selectedBinID)?.title ?? "Bin") : "Typed minutes")
        ]
        helperLines = [
            ResultLine(label: first.nickname, value: "\(clockHour(first.windowStartHour))–\(clockHour(first.windowEndHour))"),
            ResultLine(label: second.nickname, value: "\(clockHour(second.windowStartHour))–\(clockHour(second.windowEndHour))")
        ]
        cadenceRows = []
        clusterGroups = []
        publishDraft(
            kind: .windowFit,
            readout: readout,
            stopIds: [first.id, second.id],
            primaryValue: clash ? 1 : 0,
            note: "window fit",
            presentSave: true
        )
    }

    func computePinTravel() {
        guard let from = firstStop, let to = secondStop else {
            validationMessage = "North Loop is missing one of the selected pins."
            return
        }
        if from.id == to.id {
            validationMessage = "Pick two different households for this kit."
            return
        }
        let bin = readingEngine.pinTravel(from: from, to: to)
        let metres = readingEngine.haversineMetres(
            originLat: from.lat,
            originLon: from.lon,
            targetLat: to.lat,
            targetLon: to.lon
        )
        let minutes = patrolEngine.planningMinutes(for: bin)
        let rounded = Int(metres.rounded())
        let readout = "\(from.nickname) to \(to.nickname) is a \(bin.title) planning bin"
        readoutLabel = "Pin travel"
        readoutValue = bin.title
        readoutUnit = nil
        readoutContext = "\(rounded) m · \(minutes) planning minutes"
        readoutNote = "Haversine on stored stoop pins, not a live fix."
        secondaryLines = [
            ResultLine(label: "Planning minutes", value: "\(minutes)"),
            ResultLine(label: "From lat", value: formatCoord(from.lat)),
            ResultLine(label: "To lat", value: formatCoord(to.lat)),
            ResultLine(label: "Bin", value: bin.title)
        ]
        helperLines = [
            ResultLine(label: "Origin", value: from.nickname),
            ResultLine(label: "Target", value: to.nickname)
        ]
        cadenceRows = []
        clusterGroups = []
        publishDraft(
            kind: .pinTravel,
            readout: readout,
            stopIds: [from.id, to.id],
            primaryValue: Double(minutes),
            note: "pin travel",
            presentSave: true
        )
    }

    func computeCluster() {
        let radius: Double
        if radiusPresetID == "typed" {
            guard let typed = parsedPositive(radiusText) else {
                validationMessage = "Enter a radius greater than zero."
                return
            }
            radius = typed
        } else if let preset = parsedPositive(radiusPresetID) {
            radius = preset
            radiusText = radiusPresetID
        } else {
            validationMessage = "Enter a radius greater than zero."
            return
        }
        let stops = northLoopStops
        guard !stops.isEmpty else {
            validationMessage = "North Loop has no households to group."
            return
        }
        let groups = readingEngine.clusterStopIDs(stops, radiusMetres: radius)
        clusterGroups = groups.enumerated().map { index, ids in
            ClusterGroup(id: "group-\(index)-\(ids.joined(separator: "."))", stopIDs: ids)
        }
        let largest = groups.map(\.count).max() ?? 0
        let grouped = groups.filter { $0.count > 1 }.count
        let readout = "North Loop same-block cluster of \(largest) stoops inside \(Int(radius.rounded())) metres"
        readoutLabel = "Cluster"
        readoutValue = "\(largest)"
        readoutUnit = "stoops"
        readoutContext = "\(groups.count) groups · \(grouped) with neighbours"
        readoutNote = readout
        secondaryLines = [
            ResultLine(label: "Radius", value: "\(Int(radius.rounded())) m"),
            ResultLine(label: "Groups", value: "\(groups.count)"),
            ResultLine(label: "Singleton pins", value: "\(groups.filter { $0.count == 1 }.count)"),
            ResultLine(label: "Households", value: "\(stops.count)")
        ]
        helperLines = groups.prefix(4).enumerated().map { index, group in
            ResultLine(label: "Group \(index + 1)", value: "\(group.count) pins")
        }
        cadenceRows = []
        publishDraft(
            kind: .cluster,
            readout: readout,
            stopIds: stops.map(\.id),
            primaryValue: Double(largest),
            note: "cluster",
            presentSave: true
        )
    }

    func computeAccessNotes() {
        guard let stop = accessStop else {
            validationMessage = "Pick a household with stored access fields."
            return
        }
        let ready = readingEngine.accessNotesReady(for: stop)
        let readout = ready
            ? "\(stop.nickname) access notes are ready"
            : "\(stop.nickname) still needs an access field"
        readoutLabel = "Access notes"
        readoutValue = ready ? "Ready" : "Open"
        readoutUnit = nil
        readoutContext = "\(stop.floor) · \(stop.entryNote)"
        readoutNote = "\(stop.petNote) · \(stop.parkingNote)"
        secondaryLines = [
            ResultLine(label: "Entry", value: stop.entryNote),
            ResultLine(label: "Floor", value: stop.floor),
            ResultLine(label: "Pet", value: stop.petNote),
            ResultLine(label: "Parking", value: stop.parkingNote)
        ]
        helperLines = [
            ResultLine(label: "Cadence", value: "Every \(stop.cadenceDays) days"),
            ResultLine(label: "Last visit", value: "\(stop.lastVisitDayOffset) days ago")
        ]
        cadenceRows = []
        clusterGroups = []
        publishDraft(
            kind: .accessNotes,
            readout: readout,
            stopIds: [stop.id],
            primaryValue: ready ? 1 : 0,
            note: "access notes",
            presentSave: true
        )
    }

    func computeRoundLoad() {
        guard let budget = parsedInt(budgetText) else {
            validationMessage = "Enter a morning budget in minutes."
            return
        }
        let stops = listedStops
        let load = patrolEngine.loadMinutes(round: northLoop, stops: stops)
        let slack = budget - load
        let over = slack < 0
        let readout = over
            ? "\(northLoop.name) is \(abs(slack)) minutes over a \(budget)-minute budget"
            : "\(northLoop.name) load sits under the morning budget"
        readoutLabel = "Round load"
        readoutValue = "\(load)"
        readoutUnit = "min"
        readoutContext = "Budget \(budget) min · slack \(slack) min"
        readoutNote = readout
        let dwell = northLoopStops.reduce(0) { $0 + $1.dwellMinutes }
        let travel = max(0, load - dwell)
        secondaryLines = [
            ResultLine(label: "Dwell", value: "\(dwell) min"),
            ResultLine(label: "Travel bins", value: "\(travel) min"),
            ResultLine(label: "Checkpoints", value: "\(northLoop.stopIds.count)"),
            ResultLine(label: "Budget", value: "\(budget) min")
        ]
        helperLines = northLoopStops.prefix(4).map { stop in
            ResultLine(label: stop.nickname, value: "\(stop.dwellMinutes) min dwell")
        }
        cadenceRows = []
        clusterGroups = []
        publishDraft(
            kind: .roundLoad,
            readout: readout,
            stopIds: northLoop.stopIds,
            primaryValue: Double(load),
            note: "round load",
            presentSave: true
        )
    }

    func computeSkipCost() {
        guard let dropped = droppedStop else {
            validationMessage = "Pick a leftover household to drop."
            return
        }
        let stops = northLoopStops
        let days = readingEngine.skipCostDays(stops: stops, droppedStopID: dropped.id)
        let remaining = stops.filter { $0.id != dropped.id }
        let leftoverCosts = remaining.map { stop in
            (stop, readingEngine.skipCostDays(stops: stops, droppedStopID: stop.id))
        }
        let highest = leftoverCosts.max { $0.1 < $1.1 }
        let readout = "Skipping \(dropped.nickname) adds \(days) overdue days"
        readoutLabel = "Skip cost"
        readoutValue = "\(days)"
        readoutUnit = "days"
        readoutContext = highest.map { "Highest leftover: \($0.0.nickname) · \($0.1)d" }
        readoutNote = readout
        secondaryLines = [
            ResultLine(label: "Dropped", value: dropped.nickname),
            ResultLine(label: "Cadence", value: "Every \(dropped.cadenceDays) days"),
            ResultLine(label: "Last visit", value: "\(dropped.lastVisitDayOffset) days ago"),
            ResultLine(label: "Remaining stops", value: "\(remaining.count)")
        ]
        helperLines = leftoverCosts.sorted { $0.1 > $1.1 }.prefix(4).map { stop, cost in
            ResultLine(label: stop.nickname, value: "\(cost)d")
        }
        cadenceRows = []
        clusterGroups = []
        publishDraft(
            kind: .skipCost,
            readout: readout,
            stopIds: [dropped.id],
            primaryValue: Double(days),
            note: "skip cost",
            presentSave: true
        )
    }

    func openSaveDraft() {
        guard let draft = currentDraft else {
            validationMessage = "Compute a kit before saving a readout."
            return
        }
        pendingRoute = .saveDraft(draft)
        presentedDraft = draft
    }

    func nickname(for stopID: String) -> String {
        dependencies.stopRepository.stop(id: stopID)?.nickname ?? stopID
    }

    func clusterNicknames(_ group: ClusterGroup) -> String {
        group.stopIDs.map { nickname(for: $0) }.joined(separator: ", ")
    }

    private func publishDraft(
        kind: VisitKitKind,
        readout: String,
        stopIds: [String],
        primaryValue: Double,
        note: String,
        presentSave: Bool
    ) {
        draftSerial += 1
        let runID = store.activeRun?.id ?? "run-08"
        let draft = ReadingDraft(
            id: "draft-\(kind.rawValue)-\(draftSerial)",
            kind: kind,
            readout: readout,
            stopIds: stopIds,
            primaryValue: primaryValue,
            note: note,
            runId: runID
        )
        currentDraft = draft
        pendingRoute = .saveDraft(draft)
        didCompute = true
        computeCount += 1
        validationMessage = nil
        if presentSave {
            presentedDraft = draft
        }
    }

    private func clearValidation() {
        validationMessage = nil
    }

    private func kinds(in family: String) -> [VisitKitKind] {
        switch family {
        case "schedule": return [.cadence, .windowFit]
        case "pins": return [.pinTravel, .cluster]
        default: return [.accessNotes, .roundLoad, .skipCost]
        }
    }

    private func shortTitle(for kind: VisitKitKind) -> String {
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

    private static func familyID(for kind: VisitKitKind) -> String {
        switch kind {
        case .cadence, .windowFit: return "schedule"
        case .pinTravel, .cluster: return "pins"
        case .accessNotes, .roundLoad, .skipCost: return "circuit"
        }
    }

    private static func northLoopIDs(from dependencies: AppDependencies) -> [String] {
        if let round = dependencies.roundRepository.round(id: "round-01") {
            return round.stopIds
        }
        return dependencies.store.selectedRound.stopIds
    }

    private func parsedPositive(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }

    private func parsedInt(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= 0 else { return nil }
        return value
    }

    private func clockHour(_ hour: Int) -> String {
        let clamped = max(0, min(23, hour))
        let period = clamped >= 12 ? "PM" : "AM"
        let hour12 = clamped % 12
        let shown = hour12 == 0 ? 12 : hour12
        return "\(shown):00 \(period)"
    }

    private func formatCoord(_ value: Double) -> String {
        let tenths = (value * 10_000).rounded() / 10_000
        return "\(tenths)"
    }
}

@MainActor
struct KitRunnerScreen: View {
    @State private var viewModel: KitRunnerViewModel

    init(kitKind: VisitKitKind, dependencies: AppDependencies) {
        _viewModel = State(initialValue: KitRunnerViewModel(kitKind: kitKind, dependencies: dependencies))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ScreenScaffold {
            ScreenHeader(subtitle: viewModel.headerSubtitle)

            circuitStatus

            SectionCard {
                SegmentedPicker(
                    title: "Family",
                    options: viewModel.familyOptions,
                    selection: $viewModel.familyID
                )
                .onChange(of: viewModel.familyID) { _, newValue in
                    viewModel.applyFamily(newValue)
                }

                SegmentedPicker(
                    title: "Kit",
                    options: viewModel.kitOptions,
                    selection: $viewModel.kitKindID
                )
                .onChange(of: viewModel.kitKindID) { _, newValue in
                    viewModel.applyKit(newValue)
                }
            }

            kitInputs

            if let message = viewModel.validationMessage {
                InlineError(message: message)
            }
            if let pair = viewModel.pairError, viewModel.validationMessage == nil {
                InlineError(message: pair)
            }
            if let cadence = viewModel.cadenceError, viewModel.validationMessage == nil {
                InlineError(message: cadence)
            }

            computeControls

            if viewModel.didCompute {
                FieldReadout(
                    label: viewModel.readoutLabel,
                    value: viewModel.readoutValue,
                    unit: viewModel.readoutUnit,
                    context: viewModel.readoutContext,
                    note: viewModel.readoutNote
                )

                if !viewModel.secondaryLines.isEmpty {
                    SectionCard(title: "Breakdown") {
                        ForEach(viewModel.secondaryLines) { line in
                            LedgerRow(label: line.label, value: line.value)
                        }
                    }
                }

                if !viewModel.helperLines.isEmpty {
                    SectionCard(title: viewModel.kitKind.title) {
                        ForEach(viewModel.helperLines) { line in
                            DetailRow(label: line.label, value: line.value)
                        }
                    }
                }

                cadenceTable
                clusterTable
            } else {
                EmptyStateCard(
                    title: "No readout yet",
                    message: "Set the households and the one or two typed figures this kit needs, then run it. Nothing is stored until you save.",
                    actionTitle: viewModel.computeTitle
                ) {
                    viewModel.computeSelectedKit()
                }
            }

            kitCatalog
        }
        .navigationTitle(viewModel.kitKind.title)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: viewModel.computeCount)
        .sheet(item: $viewModel.presentedDraft) { draft in
            ReadingSaveScreen(draft: draft, dependencies: viewModel.dependencies)
        }
    }

    private var circuitStatus: some View {
        SectionCard(title: viewModel.northLoop.name) {
            LedgerRow(label: "Stoops", value: "\(viewModel.northLoop.stopIds.count)")
            LedgerRow(label: "Budget", value: "\(viewModel.northLoop.morningBudgetMinutes) min")
            LedgerRow(label: "Progress", value: viewModel.progressCaption)
            LedgerRow(label: "Focus", value: viewModel.store.focusedStopID.map { viewModel.nickname(for: $0) } ?? "none")
            DetailRow(label: "Circuit", value: viewModel.activeRunCaption)
        }
    }

    @ViewBuilder
    private var kitInputs: some View {
        switch viewModel.kitKind {
        case .cadence:
            cadenceInputs
        case .windowFit:
            windowInputs
        case .pinTravel:
            pinInputs
        case .cluster:
            clusterInputs
        case .accessNotes:
            accessInputs
        case .roundLoad:
            loadInputs
        case .skipCost:
            skipInputs
        }
    }

    private var cadenceInputs: some View {
        SectionCard(
            title: "Households on North Loop",
            footnote: "Last visit day against each stoop’s interval. Overdue names become the readout."
        ) {
            ChipRow {
                ForEach(viewModel.northLoopStops) { stop in
                    FilterChip(
                        title: stop.nickname,
                        isSelected: viewModel.isCadenceSelected(stop.id)
                    ) {
                        viewModel.toggleCadence(stopID: stop.id)
                    }
                }
            }
            ForEach(viewModel.selectedCadenceStops) { stop in
                DetailRow(
                    label: stop.nickname,
                    value: "Every \(stop.cadenceDays)d · last \(stop.lastVisitDayOffset)d",
                    isProminent: stop.lastVisitDayOffset > stop.cadenceDays
                )
            }
        }
    }

    private var windowInputs: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(
            title: "Window pair",
            footnote: "First dwell plus travel against the second open hour."
        ) {
            SegmentedPicker(
                title: "Travel source",
                options: viewModel.travelSourceOptions,
                selection: $viewModel.travelSourceID,
                help: "Typed minutes, or a bin from the travel table."
            )
            if viewModel.travelSourceID == "typed" {
                NumberField(
                    title: "Travel minutes",
                    value: $viewModel.travelMinutesText,
                    unit: "min",
                    prompt: "6",
                    help: "Minutes between the two stoops.",
                    error: viewModel.travelError
                )
            } else {
                SegmentedPicker(
                    title: "Planning bin",
                    options: viewModel.binOptions,
                    selection: $viewModel.selectedBinID
                )
            }
            stopPairPickers
        }
    }

    private var pinInputs: some View {
        SectionCard(
            title: "Pin pair",
            footnote: "Bins from stored pins, not a live fix."
        ) {
            stopPairPickers
            if let first = viewModel.firstStop, let second = viewModel.secondStop {
                DetailRow(label: "From", value: "\(first.nickname) · \(formatPair(first.lat, first.lon))")
                DetailRow(label: "To", value: "\(second.nickname) · \(formatPair(second.lat, second.lon))")
            }
        }
    }

    private var clusterInputs: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(
            title: "Cluster radius",
            footnote: "Groups start at the first unused pin and pull in neighbours inside the radius."
        ) {
            SegmentedPicker(
                title: "Radius",
                options: viewModel.radiusPresetOptions,
                selection: $viewModel.radiusPresetID
            )
            .onChange(of: viewModel.radiusPresetID) { _, newValue in
                viewModel.applyRadiusPreset(newValue)
            }

            if viewModel.radiusPresetID == "typed" {
                NumberField(
                    title: "Radius",
                    value: $viewModel.radiusText,
                    unit: "m",
                    prompt: "250",
                    help: "Metres around each seed pin.",
                    error: viewModel.radiusError
                )
            }
            DetailRow(label: "Pins in round", value: "\(viewModel.northLoopStops.count)")
            DetailRow(label: "Round", value: viewModel.northLoop.name)
        }
    }

    private var accessInputs: some View {
        SectionCard(
            title: "Access household",
            footnote: "Ready only when entry, floor, pet, and parking notes are all filled."
        ) {
            TabStrip(
                items: viewModel.northLoopStops,
                title: { $0.nickname },
                isSelected: { viewModel.accessStopID == $0.id },
                onSelect: { viewModel.accessStopID = $0.id }
            )
            if let stop = viewModel.accessStop {
                DetailRow(label: "Entry", value: stop.entryNote, isProminent: true)
                DetailRow(label: "Floor", value: stop.floor)
                DetailRow(label: "Pet", value: stop.petNote)
                DetailRow(label: "Parking", value: stop.parkingNote)
            }
        }
    }

    private var loadInputs: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(
            title: "Morning budget",
            footnote: "Dwell plus the planning minutes of every hop."
        ) {
            NumberField(
                title: "Budget",
                value: $viewModel.budgetText,
                unit: "min",
                prompt: "240",
                help: "Compare against the seeded budget.",
                error: viewModel.budgetError
            )
            ForEach(viewModel.northLoopStops) { stop in
                DetailRow(
                    label: stop.nickname,
                    value: "\(stop.dwellMinutes) min · \(clockHour(stop.windowStartHour))"
                )
            }
        }
    }

    private var skipInputs: some View {
        SectionCard(
            title: "Dropped household",
            footnote: "Extra overdue days if this stoop waits one more day."
        ) {
            TabStrip(
                items: viewModel.northLoopStops,
                title: { $0.nickname },
                isSelected: { viewModel.droppedStopID == $0.id },
                onSelect: { viewModel.droppedStopID = $0.id }
            )
            if let stop = viewModel.droppedStop {
                DetailRow(label: "Cadence", value: "Every \(stop.cadenceDays) days")
                DetailRow(label: "Last visit", value: "\(stop.lastVisitDayOffset) days ago")
                DetailRow(
                    label: "Implied cost",
                    value: "\(max(0, stop.lastVisitDayOffset + 1 - stop.cadenceDays)) days"
                )
            }
        }
    }

    private var stopPairPickers: some View {
        VStack(alignment: .leading, spacing: AppMetrics.contentSpacing) {
            SectionLabel(title: "First household", detail: viewModel.nickname(for: viewModel.firstStopID))
            TabStrip(
                items: viewModel.northLoopStops,
                title: { $0.nickname },
                isSelected: { viewModel.firstStopID == $0.id },
                onSelect: { viewModel.selectFirst($0.id) }
            )
            SectionLabel(title: "Second household", detail: viewModel.nickname(for: viewModel.secondStopID))
            TabStrip(
                items: viewModel.northLoopStops,
                title: { $0.nickname },
                isSelected: { viewModel.secondStopID == $0.id },
                onSelect: { viewModel.selectSecond($0.id) }
            )
        }
    }

    @ViewBuilder
    private var computeControls: some View {
        CTAButton(
            title: viewModel.computeTitle,
            systemImage: "function",
            hint: "Runs the selected kit and opens a save draft."
        ) {
            viewModel.computeSelectedKit()
        }
        .accessibilityIdentifier("smoke.kitRunner.computeCadence")

        if viewModel.canOpenDraft {
            TextAction(title: "Save this readout instead", systemImage: "tray.and.arrow.down") {
                viewModel.openSaveDraft()
            }
        }
    }

    @ViewBuilder
    private var cadenceTable: some View {
        if !viewModel.cadenceRows.isEmpty {
            SectionCard(title: "Cadence board", footnote: "In round order, not by urgency.") {
                ForEach(viewModel.cadenceRows) { row in
                    VStack(alignment: .leading, spacing: AppMetrics.tightSpacing) {
                        DetailRow(label: row.nickname, value: row.stateTitle, isProminent: row.stateTitle == CadenceState.overdue.title)
                        DetailRow(label: "Since last visit", value: row.daysSince)
                        DetailRow(label: "Window", value: row.window)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var clusterTable: some View {
        if !viewModel.clusterGroups.isEmpty {
            SectionCard(title: "Groups", footnote: "Each group shares a seed pin and a metre radius.") {
                ForEach(viewModel.clusterGroups) { group in
                    DetailRow(
                        label: "\(group.count) pins",
                        value: viewModel.clusterNicknames(group),
                        isProminent: group.count > 1
                    )
                }
            }
        }
    }

    private var kitCatalog: some View {
        VStack(alignment: .leading, spacing: AppMetrics.contentSpacing) {
            SectionLabel(title: "Kits", detail: "\(viewModel.kits.count)")

            SectionCard {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.kits.enumerated()), id: \.element.id) { index, kit in
                        if index > 0 { IndexRule() }

                        KitRow(
                            kind: kit.kind,
                            title: kit.title,
                            summary: kit.summary,
                            trailing: kit.kind.usesRadius ? "radius" : "typed",
                            action: { viewModel.applyKit(kit.kind.id) }
                        )
                    }
                }
            }
        }
    }

    private func formatPair(_ lat: Double, _ lon: Double) -> String {
        "\(lat) , \(lon)"
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
    KitRunnerScreen(kitKind: .cadence, dependencies: AppDependencies.preview())
}
