import SwiftUI
import UIKit

@MainActor
struct ExportReadingsScreen: View {
    private let dependencies: AppDependencies
    @Bindable private var store: StoopBookStore
    @State private var viewModel: ExportReadingsViewModel

    init(roundID: String, dependencies: AppDependencies) {
        self.dependencies = dependencies
        store = dependencies.store
        _viewModel = State(initialValue: ExportReadingsViewModel(roundID: roundID, dependencies: dependencies))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScreenScaffold {
            ScreenHeader(
                title: viewModel.headerTitle,
                subtitle: viewModel.headerSubtitle(roundName: store.selectedRound.name)
            )

            if viewModel.viewState.showsPlaceholder {
                emptyState
            } else {
                loadedBody(viewModel: viewModel)
            }
        }
        .navigationTitle("Pack")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: viewModel.copyCount)
        .task {
            viewModel.refresh()
        }
    }

    @ViewBuilder
    private func loadedBody(viewModel: ExportReadingsViewModel) -> some View {
        FieldReadout(
            label: viewModel.round.name,
            value: "\(viewModel.roundStops.count)",
            unit: "stoops",
            context: viewModel.heroContext,
            note: viewModel.heroNote
        )
        .accessibilityIdentifier("smoke.exportReadings.stoopReady")

        SectionCard(title: "This pack") {
            LedgerRow(label: "Stops", value: "\(viewModel.roundStops.count)")
            LedgerRow(label: "Budget", value: "\(viewModel.round.morningBudgetMinutes) min")
            LedgerRow(label: "Overdue", value: "\(viewModel.overdueCount)", tone: AppTheme.rust)
            LedgerRow(label: "Access ready", value: "\(viewModel.accessReadyCount)")
            LedgerRow(label: "Readouts", value: "\(viewModel.linkedReadings.count)")
        }

        SectionLabel(title: "Stop order", detail: "\(viewModel.roundStops.count)")

        SectionCard {
            ForEach(viewModel.orderLines) { line in
                LedgerRow(label: line.label, value: line.value)
            }
        }

        SectionCard(title: "Pack text") {
            Text(viewModel.packText)
                .font(AppType.micro)
                .foregroundStyle(AppTheme.data)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .wellSurface(padding: 14)
        }

        if let message = viewModel.validationMessage {
            InlineError(message: message)
        }

        CTAButton(
            title: viewModel.didCopy ? "Copied to pasteboard" : "Copy to pasteboard",
            systemImage: viewModel.didCopy ? "checkmark" : "doc.on.doc",
            hint: "Copies the North Loop pack text.",
            isEnabled: viewModel.canCopy
        ) {
            viewModel.copyPack()
        }
        .accessibilityIdentifier("smoke.exportReadings.copyPack")

        if viewModel.didCopy {
            FieldReadout(
                label: "Pasteboard",
                value: "Copied",
                unit: nil,
                context: viewModel.round.name,
                note: "\(viewModel.roundStops.count) stoops · \(viewModel.packText.count) characters. Nothing left this phone but the pasteboard."
            )
            .accessibilityIdentifier("smoke.exportReadings.copiedText")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
            EmptyStateCard(
                title: "No pack on this round",
                message: "That round is not on this phone. Build the North Loop pack to read the stop order.",
                systemImage: "square.and.arrow.up",
                actionTitle: "Build North Loop pack"
            ) {
                viewModel.showNorthLoop()
            }

            SectionCard(title: "Asked for") {
                LedgerRow(label: "Round", value: viewModel.roundID, tone: AppTheme.ink)
                LedgerRow(label: "Selected", value: store.selectedRound.name)
                LedgerRow(label: "Stops", value: "\(store.selectedRound.stopIds.count)")
            }
        }
    }
}

@MainActor
@Observable
private final class ExportReadingsViewModel {
    let dependencies: AppDependencies
    var roundID: String
    var didCopy = false
    var copyCount = 0
    var validationMessage: String?

    init(roundID: String, dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.roundID = roundID
    }

    var store: StoopBookStore { dependencies.store }

    var round: VisitRound {
        dependencies.roundRepository.round(id: roundID) ?? store.selectedRound
    }

    var listedStops: [VisitStop] {
        dependencies.stopRepository.listedStops()
    }

    var roundStops: [VisitStop] {
        round.stopIds.compactMap { stopID in
            listedStops.first(where: { $0.id == stopID }) ?? dependencies.stopRepository.stop(id: stopID)
        }
    }

    var readings: [KitReading] {
        var seen = Set<String>()
        var ordered: [KitReading] = []
        for reading in store.extraReadings + dependencies.readingRepository.listedReadings() {
            if seen.insert(reading.id).inserted {
                ordered.append(reading)
            }
        }
        return ordered
    }

    var linkedReadings: [KitReading] {
        let stopIDs = Set(round.stopIds)
        return readings.filter { reading in
            reading.stopIds.contains(where: { stopIDs.contains($0) })
        }
    }

    var packText: String {
        dependencies.readingEngine.exportPackText(
            round: round,
            stops: listedStops,
            readings: linkedReadings
        )
    }

    var viewState: ViewState {
        guard dependencies.roundRepository.round(id: roundID) != nil else {
            return .empty
        }
        if roundStops.isEmpty || packText.isEmpty {
            return .empty
        }
        return .loaded
    }

    var canCopy: Bool {
        packText.isEmpty == false
    }

    var headerTitle: String {
        viewState.showsPlaceholder ? "Pack is empty" : round.name
    }

    func headerSubtitle(roundName: String) -> String {
        if viewState.showsPlaceholder {
            return "No households on \(roundID). \(roundName) is still selected on this phone."
        }
        return "\(roundStops.count) stoops · \(overdueCount) overdue · \(accessReadyCount) access ready · \(linkedReadings.count) readouts"
    }

    var heroContext: String {
        if let river = riverStop {
            return "\(river.nickname) leads \(round.name)."
        }
        return "\(round.name) stop order"
    }

    var heroNote: String {
        "Travel bins are planning estimates from stored pins, not live location."
    }

    var riverStop: VisitStop? {
        roundStops.first { $0.id == "visit-01" } ?? roundStops.first { $0.nickname == "River Stoop 4B" }
    }

    var riverCaption: String {
        riverStop?.nickname ?? "No river stoop"
    }

    var overdueCount: Int {
        roundStops.filter { dependencies.readingEngine.cadenceState(for: $0) == .overdue }.count
    }

    var accessReadyCount: Int {
        roundStops.filter { dependencies.readingEngine.accessNotesReady(for: $0) }.count
    }

    var orderLines: [ResultLine] {
        var lines: [ResultLine] = []
        var previous: VisitStop?
        for stop in roundStops {
            var travel = "start"
            if let previous {
                travel = dependencies.readingEngine.pinTravel(from: previous, to: stop).title
            }
            let cadence = dependencies.readingEngine.cadenceState(for: stop).title
            lines.append(
                ResultLine(
                    label: stop.nickname,
                    value: "\(cadence) · \(travel)"
                )
            )
            previous = stop
        }
        return lines
    }

    func refresh() {
        _ = packText
        if canCopy {
            validationMessage = nil
        }
    }

    func showNorthLoop() {
        roundID = "round-01"
        didCopy = false
        validationMessage = nil
        store.selectRound(round)
        refresh()
    }

    func copyPack() {
        let text = packText
        guard text.isEmpty == false else {
            validationMessage = "The pack is empty, so copy stays off."
            return
        }
        UIPasteboard.general.string = text
        didCopy = true
        copyCount += 1
        validationMessage = nil
    }
}

#Preview {
    NavigationStack {
        ExportReadingsScreen(roundID: "round-01", dependencies: .preview())
    }
}
