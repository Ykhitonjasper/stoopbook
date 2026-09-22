import Foundation

enum VisitKitKind: String, CaseIterable, Hashable, Identifiable {
    case cadence
    case windowFit
    case pinTravel
    case cluster
    case accessNotes
    case roundLoad
    case skipCost

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cadence: return "Cadence"
        case .windowFit: return "Window Fit"
        case .pinTravel: return "Pin Travel"
        case .cluster: return "Neighbourhood Cluster"
        case .accessNotes: return "Access Notes"
        case .roundLoad: return "Round Load"
        case .skipCost: return "Skip Cost"
        }
    }

    var usesRadius: Bool
    { self == .cluster }
}

enum TravelBin: String, CaseIterable, Hashable, Identifiable {
    case walkShort
    case walkLong
    case driveShort
    case driveLong

    var id: String { rawValue }

    var title: String {
        switch self {
        case .walkShort: return "Walk short"
        case .walkLong: return "Walk long"
        case .driveShort: return "Drive short"
        case .driveLong: return "Drive long"
        }
    }

    var planningMinutes: Int
    {
        switch self {
        case .walkShort: return 6
        case .walkLong: return 14
        case .driveShort: return 12
        case .driveLong: return 22
        }
    }
}

enum CadenceState: String, CaseIterable, Hashable, Identifiable {
    case overdue
    case dueToday
    case ahead

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overdue: return "Overdue"
        case .dueToday: return "Due today"
        case .ahead: return "Ahead"
        }
    }

    var sortOrder: Int {
        switch self {
        case .overdue: return 0
        case .dueToday: return 1
        case .ahead: return 2
        }
    }
}

enum ViewState: Equatable, Hashable {
    case loaded
    case empty

    var id: String {
        switch self {
        case .loaded: return "loaded"
        case .empty: return "empty"
        }
    }

    var title: String {
        switch self {
        case .loaded: return "Loaded"
        case .empty: return "Empty"
        }
    }

    var showsPlaceholder: Bool
    { self == .empty }
}

struct AppTab: CaseIterable, Hashable, Identifiable {
    let id: String
    let label: String
    let systemImage: String
    let sortOrder: Int

    static let kits = AppTab(id: "kits", label: "Rounds", systemImage: "point.topleft.down.to.point.bottomright.curvepath", sortOrder: 0)
    static let readings = AppTab(id: "readings", label: "Visits", systemImage: "list.bullet.rectangle", sortOrder: 1)
    static let maps = AppTab(id: "maps", label: "Stoops", systemImage: "mappin.and.ellipse", sortOrder: 2)
    static let settings = AppTab(id: "settings", label: "Settings", systemImage: "gearshape", sortOrder: 3)
    static let allCases: [AppTab] = [.kits, .readings, .maps, .settings]
}
