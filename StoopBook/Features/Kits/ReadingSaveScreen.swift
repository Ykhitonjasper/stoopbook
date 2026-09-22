import SwiftUI

@MainActor
@Observable
private final class ReadingSaveViewModel {
    let dependencies: AppDependencies
    let draft: ReadingDraft
    var selectedStopIDs: [String]
    var confirmNote: String
    var savedReading: KitReading?
    var pendingRoute: AppRoute?
    var validationMessage: String?
    var didSave = false
    var saveCount = 0
    var focusedStopID: String

    init(draft: ReadingDraft, dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.draft = draft
        let initial = draft.stopIds.isEmpty
            ? ReadingSaveViewModel.northLoopIDs(from: dependencies)
            : draft.stopIds
        selectedStopIDs = initial
        focusedStopID = initial.first
            ?? dependencies.store.focusedStopID
            ?? "visit-01"
        confirmNote = draft.note
    }

    var store: StoopBookStore { dependencies.store }

    var northLoopStops: [VisitStop] {
        let ids = dependencies.roundRepository.round(id: "round-01")?.stopIds
            ?? store.selectedRound.stopIds
        return ids.compactMap { dependencies.stopRepository.stop(id: $0) }
    }

    var attachedStops: [VisitStop] {
        selectedStopIDs.compactMap { dependencies.stopRepository.stop(id: $0) }
    }

    var focusedStop: VisitStop? {
        dependencies.stopRepository.stop(id: focusedStopID)
    }

    var focusedNickname: String {
        focusedStop?.nickname ?? "Household"
    }

    var kitTitle: String { draft.kind.title }

    var activeRun: PatrolRun? { store.activeRun }

    var runCaption: String {
        if let run = activeRun {
            return "\(run.summary) · \(circuitTitle(for: run.id))"
        }
        return "No active circuit — the readout still stores on the book."
    }

    /// The circuit a reading belongs to, named the way the book names rounds —
    /// never the stored key.
    func circuitTitle(for runID: String) -> String {
        if let run = dependencies.runRepository.run(id: runID),
           let round = dependencies.roundRepository.round(id: run.roundId) {
            return round.name
        }
        if store.activeRun?.id == runID {
            return store.selectedRound.name
        }
        return "No circuit"
    }

    /// The circuit the draft will be stored onto, by name.
    var draftCircuitTitle: String {
        circuitTitle(for: draft.runId)
    }

    func dayCaption(_ offset: Int) -> String {
        if offset == 0 { return "today" }
        if offset == 1 { return "1 day ago" }
        return "\(offset) days ago"
    }

    var attachedNames: String {
        let names = attachedStops.map(\.nickname)
        if names.isEmpty { return "No household attached" }
        return names.joined(separator: ", ")
    }

    var primaryDisplay: String {
        if draft.primaryValue == draft.primaryValue.rounded() {
            return "\(Int(draft.primaryValue.rounded()))"
        }
        return "\(draft.primaryValue)"
    }

    var canSave: Bool {
        !didSave && !selectedStopIDs.isEmpty && validationMessage == nil
    }

    var confirmationDetail: String {
        "\(kitTitle) on \(focusedNickname)"
    }

    func chooseStop(_ stopID: String) {
        focusedStopID = stopID
        if selectedStopIDs.contains(stopID) == false {
            selectedStopIDs.append(stopID)
        }
        store.focusStop(stopID)
        validationMessage = nil
    }

    func toggleAttached(_ stopID: String) {
        if let index = selectedStopIDs.firstIndex(of: stopID) {
            if selectedStopIDs.count == 1 {
                validationMessage = "Keep at least one North Loop household on the readout."
                return
            }
            selectedStopIDs.remove(at: index)
            if focusedStopID == stopID {
                focusedStopID = selectedStopIDs.first ?? stopID
            }
        } else {
            selectedStopIDs.append(stopID)
            focusedStopID = stopID
        }
        validationMessage = nil
    }

    func isAttached(_ stopID: String) -> Bool {
        selectedStopIDs.contains(stopID)
    }

    func saveReading() {
        if didSave {
            if let saved = savedReading {
                pendingRoute = .readingDetail(saved.id)
            }
            return
        }
        guard selectedStopIDs.isEmpty == false else {
            validationMessage = "Attach the readout to a North Loop household."
            return
        }
        let nextIndex = store.extraReadings.count + 1
        let identifier = "reading-user-\(padded(nextIndex))"
        let reading = KitReading(
            id: identifier,
            kind: draft.kind,
            readout: draft.readout,
            runId: draft.runId.isEmpty ? (store.activeRun?.id ?? "run-08") : draft.runId, // engine key, never shown
            stopIds: selectedStopIDs,
            primaryValue: draft.primaryValue,
            capturedDayOffset: 0,
            note: confirmNote
        )
        let saved = store.save(reading: reading)
        let persisted = dependencies.readingRepository.saveReading(saved)
        savedReading = persisted
        didSave = true
        saveCount += 1
        pendingRoute = .readingDetail(persisted.id)
        validationMessage = nil
    }

    func openSavedStoop() {
        let stopID = focusedStopID.isEmpty ? "visit-01" : focusedStopID
        store.focusStop(stopID)
        store.selectedTab = .maps
    }

    func nickname(for stopID: String) -> String {
        dependencies.stopRepository.stop(id: stopID)?.nickname ?? stopID
    }

    func windowLabel(for stop: VisitStop) -> String {
        "\(clockHour(stop.windowStartHour))–\(clockHour(stop.windowEndHour))"
    }

    private static func northLoopIDs(from dependencies: AppDependencies) -> [String] {
        dependencies.roundRepository.round(id: "round-01")?.stopIds
            ?? dependencies.store.selectedRound.stopIds
    }

    private func padded(_ value: Int) -> String {
        if value < 10 { return "0\(value)" }
        return "\(value)"
    }

    private func clockHour(_ hour: Int) -> String {
        let clamped = max(0, min(23, hour))
        let period = clamped >= 12 ? "PM" : "AM"
        let hour12 = clamped % 12
        let shown = hour12 == 0 ? 12 : hour12
        return "\(shown):00 \(period)"
    }
}

@MainActor
struct ReadingSaveScreen: View {
    @State private var viewModel: ReadingSaveViewModel
    @Environment(\.dismiss) private var dismiss

    init(draft: ReadingDraft, dependencies: AppDependencies) {
        _viewModel = State(initialValue: ReadingSaveViewModel(draft: draft, dependencies: dependencies))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ScreenScaffold {
                ScreenHeader(
                    title: "Save the readout",
                    subtitle: "\(viewModel.kitTitle) · \(viewModel.draftCircuitTitle) · \(viewModel.attachedNames)"
                )

                FieldReadout(
                    label: viewModel.kitTitle,
                    value: viewModel.primaryDisplay,
                    unit: unitForKind(viewModel.draft.kind),
                    context: viewModel.draft.readout,
                    note: viewModel.runCaption
                )
                .accessibilityIdentifier("smoke.readingSave.draftReady")

                activeCircuitCard

                SectionLabel(title: "Which household", detail: viewModel.attachedNames)

                SectionCard {
                    VStack(spacing: 2) {
                        ForEach(viewModel.northLoopStops) { stop in
                            HouseholdPickRow(
                                title: stop.nickname,
                                detail: "\(viewModel.windowLabel(for: stop)) · \(stop.floor) · \(stop.entryNote)",
                                isFocused: viewModel.focusedStopID == stop.id,
                                isAttached: viewModel.isAttached(stop.id)
                            ) {
                                viewModel.chooseStop(stop.id)
                            }
                        }
                    }
                }

                confirmationCard

                if let message = viewModel.validationMessage {
                    InlineError(message: message)
                }

                CTAButton(
                    title: viewModel.didSave ? "Saved to the circuit" : "Save to circuit",
                    systemImage: "tray.and.arrow.down",
                    hint: "Writes the readout onto the active run.",
                    isEnabled: viewModel.canSave
                ) {
                    viewModel.saveReading()
                }
                .accessibilityIdentifier("smoke.readingSave.saveReading")

                if let saved = viewModel.savedReading {
                    FieldReadout(
                        label: "Saved readout",
                        value: viewModel.primaryDisplay,
                        unit: unitForKind(saved.kind),
                        context: saved.readout,
                        note: "Stored on \(viewModel.attachedNames)."
                    )
                    .accessibilityIdentifier("smoke.readingDetail.savedReadout")

                    CTAButton(
                        title: "Open saved stoop",
                        systemImage: "mappin.and.ellipse",
                        hint: "Shows the saved line on the stoop map."
                    ) {
                        viewModel.openSavedStoop()
                        dismiss()
                    }
                    .accessibilityIdentifier("smoke.readingDetail.showSavedReadout")

                    SectionCard(title: "On the book") {
                        LedgerRow(label: "Captured", value: viewModel.dayCaption(saved.capturedDayOffset), tone: AppTheme.ink)
                        LedgerRow(label: "Kit", value: saved.kind.title)
                        LedgerRow(label: "Circuit", value: viewModel.circuitTitle(for: saved.runId))
                        LedgerRow(label: "Households", value: "\(saved.stopIds.count)")
                    }
                }

                helperCopy
            }
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.success, trigger: viewModel.saveCount)
        }
    }

    private var activeCircuitCard: some View {
        SectionCard(title: viewModel.store.selectedRound.name) {
            LedgerRow(label: "Stoops", value: "\(viewModel.store.selectedRound.stopIds.count)")
            LedgerRow(label: "Budget", value: "\(viewModel.store.selectedRound.morningBudgetMinutes) min")
            LedgerRow(label: "Completed", value: "\(viewModel.activeRun?.completedStopIds.count ?? 0)")
            LedgerRow(label: "Focus", value: viewModel.focusedNickname)
            DetailRow(label: "Circuit", value: viewModel.runCaption)
        }
    }

    private var confirmationCard: some View {
        SectionCard(title: "Confirmation") {
            LedgerRow(label: "Household", value: viewModel.focusedNickname, tone: AppTheme.ink)
            LedgerRow(label: "Primary", value: viewModel.primaryDisplay)
            LedgerRow(label: "Households on it", value: "\(viewModel.attachedStops.count)")
            DetailRow(label: "Kit", value: viewModel.confirmationDetail, isProminent: true)
            DetailRow(label: "State", value: viewModel.canSave ? "Ready to save" : (viewModel.didSave ? "Already stored" : "Needs a household"))
            if let stop = viewModel.focusedStop {
                DetailRow(label: "Entry", value: stop.entryNote)
                DetailRow(label: "Parking", value: stop.parkingNote)
            }
        }
    }

    private var helperCopy: some View {
        SectionCard(title: "What is stored") {
            LedgerRow(label: "Primary", value: viewModel.primaryDisplay)
            LedgerRow(label: "Kind", value: viewModel.draft.kind.title)
            ForEach(viewModel.attachedStops) { stop in
                LedgerRow(label: stop.nickname, value: "cadence \(stop.cadenceDays)d")
            }
            DetailRow(label: "Sentence", value: viewModel.draft.readout)
        }
    }

    private func unitForKind(_ kind: VisitKitKind) -> String? {
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
}

/// One household in the picker. The row the readout is attributed to is printed
/// in ink, the same selected state the round index uses.
private struct HouseholdPickRow: View {
    let title: String
    let detail: String
    let isFocused: Bool
    let isAttached: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppType.rowStrong)
                        .foregroundStyle(isFocused ? AppTheme.paper : AppTheme.ink)
                        .multilineTextAlignment(.leading)

                    Text(detail)
                        .font(AppType.caption)
                        .foregroundStyle(isFocused ? AppTheme.paper.opacity(0.78) : AppTheme.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(isAttached ? "on readout" : "not on")
                    .font(AppType.micro)
                    .foregroundStyle(isFocused ? AppTheme.paper.opacity(0.8) : (isAttached ? AppTheme.accent : AppTheme.inkSoft))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background {
                if isFocused {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.ink)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(isAttached ? "on this readout" : "not on this readout")")
        .accessibilityAddTraits(isFocused ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    let draft = ReadingDraft(
        id: "draft-preview",
        kind: .cadence,
        readout: "Maple Vestibule, Cedar Porch, Willow Stoop overdue on North Loop",
        stopIds: ["visit-01", "visit-04"],
        primaryValue: 3,
        note: "cadence",
        runId: "run-08"
    )
    return ReadingSaveScreen(draft: draft, dependencies: dependencies)
}
