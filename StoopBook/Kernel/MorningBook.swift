import Foundation

/// The morning laid out on a clock. The same stored pins and the same travel bins
/// as every ledger line — only spread across hours instead of summed into bins,
/// so the street finally reads as the walk it is: stop 1 at 8:00, dwell 30, hop 6,
/// stop 2 by 8:36. This is planning arithmetic, never a live estimate.
struct MorningLeg: Identifiable {
    let stop: VisitStop
    /// Position on the morning, from one.
    let index: Int
    /// Minutes from midnight the walk arrives at this door.
    let arrivalMinutes: Int
    let dwellMinutes: Int
    /// Travel from the previous pin, in the same planning bins everywhere else.
    let hopMinutes: Int?
    let hopTitle: String?
    /// Latest departure from this door that still reaches every later window.
    /// Nil on the last house — nothing after it constrains the clock.
    let leaveByMinutes: Int?

    var id: String { stop.id }
    var departureMinutes: Int { arrivalMinutes + dwellMinutes }
    var windowEndMinutes: Int { stop.windowEndHour * 60 }
    /// True when the plan walks up after the agreed window has closed.
    var arrivesLate: Bool { arrivalMinutes > windowEndMinutes }
}

/// One lawful ordering of the same round, costed: what the load becomes, how many
/// overdue households stay on the morning, and who moves to Saturday.
struct RoundProposal: Identifiable {
    enum Strategy: String, CaseIterable, Identifiable {
        /// Worst cadence debt walks first.
        case overdueFirst
        /// Doors open in the order the windows open.
        case windowFirst
        /// A nearest-pin chain, so shared vestibules share one walk-up.
        case sameVestibule

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overdueFirst: return "Overdue first"
            case .windowFirst: return "Window first"
            case .sameVestibule: return "Same vestibule"
            }
        }

        var note: String {
            switch self {
            case .overdueFirst: return "Deepest cadence debt takes the first door."
            case .windowFirst: return "The day is ordered by when windows open."
            case .sameVestibule: return "Nearest pin next, so one building is one walk-up."
            }
        }
    }

    let strategy: Strategy
    /// The morning that fits the budget, already on the clock.
    let legs: [MorningLeg]
    let loadMinutes: Int
    /// Overdue households that stay on this morning.
    let overdueKept: Int
    /// The tail that does not fit the budget: the Saturday list.
    let overflow: [VisitStop]

    var id: String { strategy.rawValue }

    var overflowNames: String {
        overflow.map(\.nickname).joined(separator: ", ")
    }
}

/// The arithmetic of one morning: a clock rail over the round, and lawful orders
/// over the same pool. Nothing here watches the clock — the book plans, the
/// person walks.
struct MorningBook {
    /// The seed's earliest window opens at eight, and the morning is read from
    /// the front door out.
    let dayStartMinutes: Int = 8 * 60

    private let reading = ReadingEngine()
    private let patrol = PatrolEngine()

    // MARK: - Clock

    /// Wall-clock text for minutes from midnight, in the book's 8:00 AM style.
    func clock(_ minutes: Int) -> String {
        let clamped = max(0, min(24 * 60 - 1, minutes))
        let hour = clamped / 60
        let minute = clamped % 60
        let period = hour >= 12 ? "PM" : "AM"
        let shown12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", shown12, minute, period)
    }

    // MARK: - Timeline

    /// The round walked on a clock, in the given order.
    func legs(order stopIDs: [String], stops: [VisitStop]) -> [MorningLeg] {
        let byID = Dictionary(uniqueKeysWithValues: stops.map { ($0.id, $0) })
        let chain = stopIDs.compactMap { byID[$0] }
        guard !chain.isEmpty else { return [] }

        var drawn: [(stop: VisitStop, index: Int, arrival: Int, hop: Int?, hopTitle: String?)] = []
        var clockHand = dayStartMinutes
        var previous: VisitStop?
        for (index, stop) in chain.enumerated() {
            var hop: Int?
            var hopTitle: String?
            if let previous {
                let bin = reading.pinTravel(from: previous, to: stop)
                let minutes = patrol.planningMinutes(for: bin)
                hop = minutes
                hopTitle = bin.title
                clockHand += minutes
            }
            drawn.append((stop, index, clockHand, hop, hopTitle))
            clockHand += stop.dwellMinutes
            previous = stop
        }

        // Leave-by walks backwards: the last house frees the clock, and every
        // earlier door inherits the tightest later window. Leaving after it pushes
        // somebody past the hour they agreed to.
        var leaveBy = [Int?](repeating: nil, count: drawn.count)
        var latestOut: Int?
        for index in stride(from: drawn.count - 1, through: 1, by: -1) {
            leaveBy[index - 1] = latestOut
            let leg = drawn[index]
            let hop = leg.hop ?? 0
            let windowCap = leg.stop.windowEndHour * 60 - hop
            let chainCap = (latestOut ?? Int.max) - leg.stop.dwellMinutes - hop
            latestOut = min(windowCap, chainCap)
        }

        return drawn.enumerated().map { position, entry in
            MorningLeg(
                stop: entry.stop,
                index: entry.index,
                arrivalMinutes: entry.arrival,
                dwellMinutes: entry.stop.dwellMinutes,
                hopMinutes: entry.hop,
                hopTitle: entry.hopTitle,
                leaveByMinutes: leaveBy[position]
            )
        }
    }

    func timeline(round: VisitRound, stops: [VisitStop]) -> [MorningLeg] {
        legs(order: round.stopIds, stops: stops)
    }

    // MARK: - Lawful orders

    /// Every lawful ordering of the round, costed against the same budget.
    func proposals(round: VisitRound, stops: [VisitStop]) -> [RoundProposal] {
        let pool = round.stopIds.compactMap { id in stops.first { $0.id == id } }
        return RoundProposal.Strategy.allCases.map { strategy in
            proposal(strategy: strategy, pool: pool, budget: round.morningBudgetMinutes)
        }
    }

    private func proposal(strategy: RoundProposal.Strategy, pool: [VisitStop], budget: Int) -> RoundProposal {
        let ordered = order(strategy: strategy, pool: pool)
        let fitting = fit(within: budget, chain: ordered)
        let keptIDs = fitting.kept.map(\.id)
        let timed = legs(order: keptIDs, stops: pool)
        return RoundProposal(
            strategy: strategy,
            legs: timed,
            loadMinutes: patrol.loadMinutes(
                round: VisitRound(id: "proposal", name: "Proposal", stopIds: keptIDs, morningBudgetMinutes: budget, isDefault: false),
                stops: pool
            ),
            overdueKept: fitting.kept.filter { reading.cadenceState(for: $0) == .overdue }.count,
            overflow: fitting.overflow
        )
    }

    /// Walk the chain and cut where the budget runs out: everything past that
    /// point is the Saturday list, in the order it would have been walked.
    private func fit(within budget: Int, chain: [VisitStop]) -> (kept: [VisitStop], overflow: [VisitStop]) {
        var kept: [VisitStop] = []
        var clockHand = dayStartMinutes
        var previous: VisitStop?
        for stop in chain {
            var hop = 0
            if let previous {
                hop = patrol.planningMinutes(for: reading.pinTravel(from: previous, to: stop))
            }
            let arrival = clockHand + hop
            if arrival + stop.dwellMinutes > dayStartMinutes + budget {
                if let cut = chain.firstIndex(where: { $0.id == stop.id }) {
                    return (kept, Array(chain[cut...]))
                }
                return (kept, [stop])
            }
            kept.append(stop)
            clockHand = arrival + stop.dwellMinutes
            previous = stop
        }
        return (kept, [])
    }

    /// The three orders a dispatcher is allowed to mean, each deterministic from
    /// the stored book — never a shuffle.
    private func order(strategy: RoundProposal.Strategy, pool: [VisitStop]) -> [VisitStop] {
        switch strategy {
        case .overdueFirst:
            return pool.sorted { first, second in
                let firstState = reading.cadenceState(for: first)
                let secondState = reading.cadenceState(for: second)
                if firstState != secondState { return firstState.sortOrder < secondState.sortOrder }
                if firstState == .overdue {
                    let firstDebt = first.lastVisitDayOffset - first.cadenceDays
                    let secondDebt = second.lastVisitDayOffset - second.cadenceDays
                    if firstDebt != secondDebt { return firstDebt > secondDebt }
                }
                if firstState == .ahead {
                    let firstLeft = first.cadenceDays - first.lastVisitDayOffset
                    let secondLeft = second.cadenceDays - second.lastVisitDayOffset
                    if firstLeft != secondLeft { return firstLeft < secondLeft }
                }
                return first.nickname < second.nickname
            }

        case .windowFirst:
            return pool.sorted { first, second in
                if first.windowStartHour != second.windowStartHour {
                    return first.windowStartHour < second.windowStartHour
                }
                if first.windowEndHour != second.windowEndHour {
                    return first.windowEndHour < second.windowEndHour
                }
                return first.nickname < second.nickname
            }

        case .sameVestibule:
            guard !pool.isEmpty else { return [] }
            var remaining = pool
            var chain: [VisitStop] = []
            var current = remaining.removeFirst()
            chain.append(current)
            while !remaining.isEmpty {
                let nearest = remaining.min { lhs, rhs in
                    let lhsDistance = reading.haversineMetres(originLat: current.lat, originLon: current.lon, targetLat: lhs.lat, targetLon: lhs.lon)
                    let rhsDistance = reading.haversineMetres(originLat: current.lat, originLon: current.lon, targetLat: rhs.lat, targetLon: rhs.lon)
                    if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                    return lhs.nickname < rhs.nickname
                }
                guard let nearest else { break }
                remaining.removeAll { $0.id == nearest.id }
                chain.append(nearest)
                current = nearest
            }
            return chain
        }
    }

    // MARK: - The sheet a stand-in can walk

    /// The text pack rewritten as the same plot the screen draws: order, hours,
    /// one access line per door, and who is overdue. A person can take this and
    /// walk the morning.
    func standInSheet(round: VisitRound, stops: [VisitStop], readings: [KitReading]) -> String {
        let byID = Dictionary(uniqueKeysWithValues: stops.map { ($0.id, $0) })
        let pool = round.stopIds.compactMap { byID[$0] }
        let fitting = fit(within: round.morningBudgetMinutes, chain: pool)
        let timed = legs(order: fitting.kept.map(\.id), stops: pool)
        let load = patrol.loadMinutes(
            round: VisitRound(id: round.id, name: round.name, stopIds: fitting.kept.map(\.id), morningBudgetMinutes: round.morningBudgetMinutes, isDefault: round.isDefault),
            stops: pool
        )
        let slack = round.morningBudgetMinutes - load

        var lines: [String] = []
        lines.append("\(round.name.uppercased()) — MORNING BOOK")
        lines.append("Budget \(round.morningBudgetMinutes) min · load \(load) min · \(slack >= 0 ? "slack" : "over") \(abs(slack)) min · \(fitting.kept.count) doors")
        lines.append("")

        for leg in timed {
            let state = reading.cadenceState(for: leg.stop)
            let debt = state == .overdue
                ? "OVERDUE \(max(0, leg.stop.lastVisitDayOffset - leg.stop.cadenceDays))d"
                : (state == .dueToday ? "due today" : "inside cadence")
            let access = "\(leg.stop.entryNote) · floor \(leg.stop.floor) · \(leg.stop.petNote) · park: \(leg.stop.parkingNote)"
            var row = "\(leg.index + 1). \(leg.stop.nickname) — \(clock(leg.arrivalMinutes)) · dwell \(leg.dwellMinutes) min"
            if let leaveBy = leg.leaveByMinutes {
                row += " · out by \(clock(leaveBy))"
            }
            lines.append(row)
            lines.append("   \(debt) · \(access)")
            if leg.arrivesLate {
                lines.append("   NOTE: walks up after the \(clock(leg.windowEndMinutes)) window close")
            }
            if let hop = leg.hopMinutes, let title = leg.hopTitle {
                lines.append("   ↑ \(title.lowercased()) \(hop) min from previous")
            }
        }

        if !fitting.overflow.isEmpty {
            lines.append("")
            lines.append("TO SATURDAY: \(fitting.overflow.map(\.nickname).joined(separator: ", "))")
        }

        lines.append("")
        lines.append("\(readings.count) readouts stored on the book.")
        return lines.joined(separator: "\n")
    }
}
