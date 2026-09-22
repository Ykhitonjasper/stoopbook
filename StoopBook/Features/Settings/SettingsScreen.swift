import SwiftUI

@MainActor
struct SettingsScreen: View {
    @Bindable private var store: StoopBookStore
    @State private var viewModel: SettingsViewModel
    @Environment(\.openURL) private var openURL
    @State private var confirmDelete = false

    /// A block drawn as the row of houses it is: the marks at index size, one per
    /// stoop of the block, cadence on the roofs — then its name and count in prose.
    private func blockLine(place: NeighbourhoodPlace, stopCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HouseStreet(
                houses: viewModel.blockHouses(place),
                showsSidewalk: false
            )
            DetailRow(label: place.name, value: "\(stopCount) stoops")
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(place.name), \(stopCount) stoops")
    }

    /// A past morning drawn as the street it walked, brass roofs where it went.
    private func circuitLine(run: PatrolRun, name: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HouseStreet(houses: viewModel.circuitHouses(run))
            DetailRow(
                label: name,
                value: run.isActive ? "live · \(run.completedStopIds.count) done" : "\(run.completedStopIds.count) of \(max(run.completedStopIds.count, viewModel.circuitHouses(run).count)) walked"
            )
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(run.completedStopIds.count) stoops walked")
    }

    init(dependencies: AppDependencies) {
        store = dependencies.store
        _viewModel = State(initialValue: SettingsViewModel(dependencies: dependencies))
    }

    var body: some View {
        ScreenScaffold {
            ScreenHeader(
                title: AppTheme.displayName,
                subtitle: viewModel.ledgerLine
            )

            SectionCard(title: "On this phone") {
                DetailRow(label: "App", value: "\(AppTheme.displayName) · v\(viewModel.bundleVersion)", isProminent: true)
                DetailRow(label: "Round", value: "\(store.selectedRound.name) · \(store.selectedRound.stopIds.count) stoops · \(store.selectedRound.morningBudgetMinutes) min budget")
                DetailRow(label: "Stored", value: "\(viewModel.readingCount) readouts · \(viewModel.runCount) circuits")
                DetailRow(label: "Storage", value: "Readouts, blocks and circuits live on this iPhone")
                DetailRow(label: "Location", value: "Stored pins only. The app never asks for a live fix.")
                DetailRow(label: "Advertising", value: "Usage data, not linked to you. Third-party ads.")
                DetailRow(label: "Basemap", value: "Apple's map tiles load only while the sheet is set to Map. Your pins never leave the phone.")
            }

            SectionLabel(title: "Kits", detail: "\(VisitKitKind.allCases.count)")

            SectionCard {
                VStack(spacing: 0) {
                    ForEach(Array(VisitKitKind.allCases.enumerated()), id: \.element.id) { index, kind in
                        if index > 0 { IndexRule() }

                        HStack(alignment: .center, spacing: 12) {
                            KitMark(kind: kind, size: 18, tone: AppTheme.ink)
                            Text(kind.title)
                                .font(AppType.rowStrong)
                                .foregroundStyle(AppTheme.ink)
                            Spacer(minLength: 8)
                            Text(viewModel.kitCaption(for: kind))
                                .font(AppType.micro)
                                .foregroundStyle(AppTheme.data)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.vertical, 11)
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            SectionLabel(title: "Blocks", detail: "\(viewModel.places.count)")

            SectionCard {
                ForEach(Array(viewModel.places.enumerated()), id: \.element.id) { index, place in
                    blockLine(place: place, stopCount: viewModel.stopCountValue(for: place))
                    if index < viewModel.places.count - 1 { IndexRule() }
                }
            }

            SectionLabel(title: "Past circuits", detail: "\(viewModel.runCount)")

            SectionCard {
                ForEach(Array(viewModel.runs.enumerated()), id: \.element.id) { index, run in
                    circuitLine(run: run, name: viewModel.roundName(for: run))
                    if index < viewModel.runs.count - 1 { IndexRule() }
                }
            }

            SectionCard {
                IndexRow(
                    title: "Privacy",
                    detail: "Visit records on this iPhone, and usage data used for ads"
                ) {
                    viewModel.openPrivacy(using: openURL)
                }

                IndexRule()

                IndexRow(
                    title: "Terms",
                    detail: "The terms that apply to this local round book"
                ) {
                    viewModel.openTerms(using: openURL)
                }
            }

            SectionCard(title: "Delete All Data", footnote: "Clears every readout, block, and circuit on this iPhone, then brings the introduction back.") {
                DetailRow(label: "Stored", value: "\(viewModel.readingCount) readouts · \(viewModel.placeCount) blocks · \(viewModel.runCount) circuits", isProminent: true)

                CTAButton(
                    title: "Delete All Data",
                    systemImage: "trash",
                    emphasis: .destructive,
                    hint: "Asks for confirmation before clearing this iPhone copy"
                ) {
                    confirmDelete = true
                }
                .padding(.top, 4)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete All Data",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete All Data", role: .destructive) {
                viewModel.deleteAllData()
            }
            Button("Keep records", role: .cancel) {}
        } message: {
            Text("This removes every local visit readout, block, and past circuit, then returns to the introduction.")
        }
        .sensoryFeedback(.warning, trigger: confirmDelete)
    }
}

@MainActor
@Observable
private final class SettingsViewModel {
    private let stopRepository: any VisitStopRepository
    private let readingRepository: any KitReadingRepository
    private let placeRepository: any NeighbourhoodPlaceRepository
    private let runRepository: any PatrolRunRepository
    private let roundRepository: any VisitRoundRepository
    private let readingEngine: ReadingEngine
    private let store: StoopBookStore

    init(dependencies: AppDependencies) {
        store = dependencies.store
        stopRepository = dependencies.stopRepository
        readingRepository = dependencies.readingRepository
        placeRepository = dependencies.placeRepository
        runRepository = dependencies.runRepository
        roundRepository = dependencies.roundRepository
        readingEngine = dependencies.readingEngine
    }

    var places: [NeighbourhoodPlace] { placeRepository.listedPlaces() }
    var readings: [KitReading] { readingRepository.listedReadings() }
    var runs: [PatrolRun] { runRepository.listedRuns() }
    var readingCount: Int { readings.count + store.extraReadings.count }
    var placeCount: Int { places.count }
    var runCount: Int { runs.count }

    var ledgerLine: String {
        "\(readingCount) readouts · \(placeCount) blocks · \(runCount) circuits · v\(bundleVersion)"
    }

    var bundleVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let trimmed = (version ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "1.0" : trimmed
    }

    func openPrivacy(using openURL: OpenURLAction) {
        if let url = Legal.privacy {
            openURL(url)
        }
    }

    func openTerms(using openURL: OpenURLAction) {
        if let url = Legal.terms {
            openURL(url)
        }
    }

    func deleteAllData() {
        _ = readingRepository.deleteAllReadings()
        _ = placeRepository.deleteAllPlaces()
        _ = runRepository.deleteAllRuns()
        store.deleteAll()
        store.resetOnboarding()
    }

    func roundName(for run: PatrolRun) -> String {
        roundRepository.round(id: run.roundId)?.name ?? run.roundId
    }

    func stopCount(for place: NeighbourhoodPlace) -> String {
        "\(stopCountValue(for: place)) stoops"
    }

    func stopCountValue(for place: NeighbourhoodPlace) -> Int {
        stopRepository.listedStops().filter { $0.neighbourhoodId == place.id }.count
    }

    /// The block's stoops as houses, cadence on every roof.
    func blockHouses(_ place: NeighbourhoodPlace) -> [StreetHouse] {
        stopRepository.listedStops()
            .filter { $0.neighbourhoodId == place.id }
            .sorted { $0.nickname < $1.nickname }
            .map { stop in
                let resolved = store.resolvedStop(stop)
                let state = readingEngine.cadenceState(for: resolved)
                return StreetHouse(
                    id: stop.id,
                    roofTone: state.tone,
                    dwellFraction: RowhouseMark.dwellFraction(dwellMinutes: stop.dwellMinutes),
                    caption: RowhouseMark.dayCaption(state: state, lastVisitDayOffset: resolved.lastVisitDayOffset, cadenceDays: resolved.cadenceDays),
                    captionTone: state.tone
                )
            }
    }

    /// The morning's walk as houses, brass where the circuit already went.
    func circuitHouses(_ run: PatrolRun) -> [StreetHouse] {
        let done = Set(run.completedStopIds)
        return roundRepository.round(id: run.roundId)?.stopIds.compactMap { stopID -> StreetHouse? in
            guard let raw = stopRepository.stop(id: stopID) else { return nil }
            let stop = store.resolvedStop(raw)
            let state = readingEngine.cadenceState(for: stop)
            let walked = done.contains(stop.id)
            return StreetHouse(
                id: stop.id,
                roofTone: walked ? AppTheme.brass : state.tone,
                dwellFraction: RowhouseMark.dwellFraction(dwellMinutes: stop.dwellMinutes),
                caption: RowhouseMark.dayCaption(state: state, lastVisitDayOffset: stop.lastVisitDayOffset, cadenceDays: stop.cadenceDays),
                captionTone: walked ? AppTheme.brass : state.tone
            )
        } ?? []
    }

    func kitCaption(for kind: VisitKitKind) -> String {
        switch kind {
        case .cadence: return "overdue check"
        case .windowFit: return "window vs travel"
        case .pinTravel: return "pin-to-pin bin"
        case .cluster: return "same block"
        case .accessNotes: return "entry notes"
        case .roundLoad: return "dwell vs budget"
        case .skipCost: return "cost of a skip"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsScreen(dependencies: .preview())
    }
}
