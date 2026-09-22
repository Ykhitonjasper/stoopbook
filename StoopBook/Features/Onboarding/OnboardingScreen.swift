import SwiftUI

@MainActor
struct OnboardingScreen: View {
    @State private var viewModel: OnboardingViewModel

    init(dependencies: AppDependencies) {
        _viewModel = State(initialValue: OnboardingViewModel(dependencies: dependencies))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScreenScaffold(scrolls: false) {
            Group {
                switch viewModel.pageIndex {
                case 0:
                    linePage
                        .transition(.opacity)
                case 1:
                    kitsPage
                        .transition(.opacity)
                default:
                    phonePage
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityLabel("Introduction page \(viewModel.pageIndex + 1) of 3")

            footer
        }
        .sensoryFeedback(.selection, trigger: viewModel.pageIndex)
        .sensoryFeedback(.success, trigger: viewModel.didComplete)
    }

    // MARK: - Page one: the street line

    private var linePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    StoopMark(size: 34)
                        .padding(.bottom, 4)

                    Text(AppTheme.displayName)
                        .font(AppType.display(38))
                        .foregroundStyle(AppTheme.ink)

                    Text("The morning round, drawn as the street you walk it on.")
                        .font(AppType.row)
                        .foregroundStyle(AppTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 6)

                StreetLine(
                    stops: viewModel.morningStops,
                    focusedStopID: viewModel.focusedStopID,
                    state: { viewModel.cadenceState(for: $0) },
                    onSelect: { viewModel.focus($0.id) }
                )

                Text(viewModel.ledgerLine)
                    .font(AppType.meta)
                    .foregroundStyle(AppTheme.data)
                    .fixedSize(horizontal: false, vertical: true)

                SectionCard {
                    LedgerRow(label: "Overdue", value: "\(viewModel.overdueStops.count)", tone: AppTheme.rust)
                    LedgerRow(label: "Due today", value: "\(viewModel.dueTodayStops.count)", tone: AppTheme.accent)
                    LedgerRow(label: "Inside cadence", value: "\(viewModel.aheadStops.count)", tone: AppTheme.sage)
                    DetailRow(
                        label: "Next overdue",
                        value: viewModel.overdueStops.first.map { "\($0.nickname), \(viewModel.daysPastCadence($0)) days over" } ?? "nobody",
                        isProminent: true
                    )
                }

                ScreenNote(text: "Tap a house to put that household on the top of the page.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Page two: the kits

    private var kitsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
                ScreenHeader(
                    title: "Seven checks\nfrom one round",
                    subtitle: "One household list, seven ways to read it"
                )

                SectionCard {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)],
                        alignment: .leading,
                        spacing: 16
                    ) {
                        ForEach(viewModel.kits) { kit in
                            HStack(alignment: .center, spacing: 10) {
                                KitMark(kind: kit.kind, size: 19, tone: AppTheme.ink)
                                Text(kit.title)
                                    .font(AppType.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                SectionCard(title: "How a kit ends") {
                    LedgerRow(label: "You type", value: "radius, budget, minutes")
                    LedgerRow(label: "The kit reads", value: "cadence, windows, pins")
                    LedgerRow(label: "You save", value: "a readout on the visit")
                    DetailRow(
                        label: "Where it lands",
                        value: "The household, the circuit, and the day it was taken",
                        isProminent: true
                    )
                }

                ScreenNote(text: "Every figure is a planning estimate from the pins and windows already on this phone.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Page three: on this phone

    private var phonePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
                ScreenHeader(
                    title: "On this phone",
                    subtitle: "\(viewModel.rounds.count) rounds · \(viewModel.allStops.count) stoops · \(viewModel.places.count) blocks"
                )

                SectionCard {
                    LedgerRow(label: "Rounds", value: "\(viewModel.rounds.count) loops")
                    LedgerRow(label: "Stoops", value: "\(viewModel.allStops.count) households")
                    LedgerRow(label: "Blocks", value: "\(viewModel.places.count) neighbourhoods")
                    LedgerRow(label: "Storage", value: "this iPhone")
                    LedgerRow(label: "Location", value: "stored pins only")
                    LedgerRow(label: "Advertising", value: "usage data, not linked")
                    DetailRow(
                        label: "Delete All Data",
                        value: "Wipes the book and brings this introduction back",
                        isProminent: true
                    )
                }

                SectionCard(title: "Blocks in the book") {
                    ForEach(viewModel.places) { place in
                        LedgerRow(label: place.name, value: "\(viewModel.stopCount(for: place)) stoops")
                    }
                }

                ScreenNote(text: "The round book stays on this iPhone. Usage data may be used for advertising.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index == viewModel.pageIndex ? AppTheme.ink : AppTheme.edge)
                        .frame(width: 3, height: index == viewModel.pageIndex ? 16 : 11)
                }
            }
            .frame(height: 16)
            .animation(AppMotion.quick, value: viewModel.pageIndex)
            .accessibilityHidden(true)

            if viewModel.isLastPage {
                CTAButton(
                    title: "Get started",
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                    hint: "Finishes the introduction and opens the morning rounds"
                ) {
                    viewModel.completeOnboarding()
                }
            } else {
                CTAButton(
                    title: "Continue",
                    hint: "Shows the next introduction page"
                ) {
                    viewModel.advancePage()
                }
            }
        }
        .padding(.top, 4)
    }
}

@MainActor
@Observable
private final class OnboardingViewModel {
    var pageIndex = 0
    var didComplete = false

    private let store: StoopBookStore
    private let stopRepository: any VisitStopRepository
    private let roundRepository: any VisitRoundRepository
    private let placeRepository: any NeighbourhoodPlaceRepository
    private let readingEngine: ReadingEngine

    init(dependencies: AppDependencies) {
        store = dependencies.store
        stopRepository = dependencies.stopRepository
        roundRepository = dependencies.roundRepository
        placeRepository = dependencies.placeRepository
        readingEngine = dependencies.readingEngine
    }

    var isLastPage: Bool { pageIndex >= 2 }

    var rounds: [VisitRound] { roundRepository.listedRounds() }
    var allStops: [VisitStop] { stopRepository.listedStops() }
    var places: [NeighbourhoodPlace] { placeRepository.listedPlaces() }
    var kits: [VisitKit] { StoopBookSeed.kits }

    var morningRound: VisitRound { store.selectedRound }

    /// The line opens with its first household in hand, so the drawn street is
    /// never a row of identical boxes on the very first screen.
    var focusedStopID: String? {
        if let id = store.focusedStopID, morningStops.contains(where: { $0.id == id }) {
            return id
        }
        return morningStops.first?.id
    }

    var morningStops: [VisitStop] {
        store.resolvedStops(morningRound.stopIds.compactMap { stopRepository.stop(id: $0) })
    }

    var overdueStops: [VisitStop] {
        morningStops.filter { readingEngine.cadenceState(for: $0) == .overdue }
    }

    var dueTodayStops: [VisitStop] {
        morningStops.filter { readingEngine.cadenceState(for: $0) == .dueToday }
    }

    var aheadStops: [VisitStop] {
        morningStops.filter { readingEngine.cadenceState(for: $0) == .ahead }
    }

    var ledgerLine: String {
        "\(morningStops.count) stoops · \(morningRound.morningBudgetMinutes) min budget · \(overdueStops.count) overdue"
    }

    func advancePage() {
        guard pageIndex < 2 else { return }
        withAnimation(AppMotion.settle) {
            pageIndex += 1
        }
    }

    func completeOnboarding() {
        store.completeOnboarding()
        didComplete = true
    }

    func focus(_ stopID: String) {
        store.focusStop(stopID)
    }

    func cadenceState(for stop: VisitStop) -> CadenceState {
        readingEngine.cadenceState(for: stop)
    }

    func daysPastCadence(_ stop: VisitStop) -> Int {
        max(0, stop.lastVisitDayOffset - stop.cadenceDays)
    }

    func stopCount(for place: NeighbourhoodPlace) -> Int {
        allStops.filter { $0.neighbourhoodId == place.id }.count
    }
}

#Preview {
    OnboardingScreen(dependencies: .preview())
}
