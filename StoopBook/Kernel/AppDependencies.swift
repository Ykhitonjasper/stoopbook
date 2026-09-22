import Foundation

@MainActor struct AppDependencies {
    let store: StoopBookStore
    let stopRepository: any VisitStopRepository
    let roundRepository: any VisitRoundRepository
    let placeRepository: any NeighbourhoodPlaceRepository
    let readingRepository: any KitReadingRepository
    let runRepository: any PatrolRunRepository
    let readingEngine: ReadingEngine
    let patrolEngine: PatrolEngine

    static func preview() -> AppDependencies {
        AppDependencies(
            store: StoopBookStore(),
            stopRepository: SeededStopRepository(stops: StoopBookSeed.stops),
            roundRepository: SeededRoundRepository(rounds: StoopBookSeed.rounds),
            placeRepository: SeededPlaceRepository(places: StoopBookSeed.places),
            readingRepository: SeededReadingRepository(readings: StoopBookSeed.readings),
            runRepository: SeededRunRepository(runs: StoopBookSeed.pastRounds),
            readingEngine: ReadingEngine(),
            patrolEngine: PatrolEngine()
        )
    }

    static func live() -> AppDependencies { preview() }
}
