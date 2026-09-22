import Foundation

struct VisitStop: Identifiable, Hashable {
    let id: String
    let nickname: String
    let lat: Double
    let lon: Double
    let cadenceDays: Int
    let lastVisitDayOffset: Int
    let windowStartHour: Int
    let windowEndHour: Int
    let dwellMinutes: Int
    let entryNote: String
    let floor: String
    let petNote: String
    let parkingNote: String
    let neighbourhoodId: String

    /// The same household standing on a different day of its cadence clock —
    /// how a recorded `seen` outcome moves the book without touching the seed.
    func withLastVisit(dayOffset: Int) -> VisitStop {
        VisitStop(
            id: id,
            nickname: nickname,
            lat: lat,
            lon: lon,
            cadenceDays: cadenceDays,
            lastVisitDayOffset: dayOffset,
            windowStartHour: windowStartHour,
            windowEndHour: windowEndHour,
            dwellMinutes: dwellMinutes,
            entryNote: entryNote,
            floor: floor,
            petNote: petNote,
            parkingNote: parkingNote,
            neighbourhoodId: neighbourhoodId
        )
    }
}

/// One closed visit: the outcome a person records at the door, kept next to the
/// day it happened. `seen` restarts the cadence clock from today; no-answer,
/// blocked, and skipped leave the clock alone and carry their mark on the book.
struct VisitOutcomeRecord: Identifiable, Hashable {
    let id: String
    let stopID: String
    let outcome: VisitOutcome
    let dayOffset: Int
    let note: String
}

struct VisitRound: Identifiable, Hashable {
    let id: String
    let name: String
    let stopIds: [String]
    let morningBudgetMinutes: Int
    let isDefault: Bool
}

struct NeighbourhoodPlace: Identifiable, Hashable {
    let id: String
    let name: String
    let centerLat: Double
    let centerLon: Double
    let blockNote: String
}

struct KitReading: Identifiable, Hashable {
    let id: String
    let kind: VisitKitKind
    let readout: String
    let runId: String
    let stopIds: [String]
    let primaryValue: Double
    let capturedDayOffset: Int
    let note: String
}

struct PatrolRun: Identifiable, Hashable {
    let id: String
    let roundId: String
    let isActive: Bool
    let completedStopIds: [String]
    let startedDayOffset: Int
    let summary: String
}

struct VisitKit: Identifiable, Hashable {
    let id: String
    let kind: VisitKitKind
    let title: String
    let summary: String
    let prompt: String
}

struct ReadingDraft: Identifiable, Hashable {
    let id: String
    let kind: VisitKitKind
    let readout: String
    let stopIds: [String]
    let primaryValue: Double
    let note: String
    let runId: String
}

struct ComparePair: Identifiable, Hashable {
    let id: String
    let label: String
    let firstReadingID: String
    let secondReadingID: String
    let isSeeded: Bool
}

/// How a door-visit ended. This is the difference between "a readout was saved"
/// and "I stood at that door": only `seen` restarts the cadence clock; the other
/// outcomes leave the debt standing and put their mark on the book instead.
enum VisitOutcome: String, CaseIterable, Hashable, Identifiable {
    case seen
    case noAnswer
    case blocked
    case skipped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seen: return "Seen"
        case .noAnswer: return "No answer"
        case .blocked: return "Access blocked"
        case .skipped: return "Skipped"
        }
    }

    var caption: String {
        switch self {
        case .seen: return "door opened, visit made"
        case .noAnswer: return "knocked, nobody came"
        case .blocked: return "could not get in"
        case .skipped: return "left for another morning"
        }
    }

    /// The book's own mark: seen stays quiet, the others carry a flag on the line.
    var glyph: String {
        switch self {
        case .seen: return "checkmark"
        case .noAnswer: return "bell"
        case .blocked: return "lock"
        case .skipped: return "arrow.uturn.backward"
        }
    }
}
