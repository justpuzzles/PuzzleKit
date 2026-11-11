import Foundation

/// What recording a daily solve did. The caller uses it to decide what else
/// counts: only `.counted` and `.late` are new solves.
public enum DailyOutcome: Equatable, Sendable {
    /// Today's (or the newest) daily, solved for the first time. `streak` is
    /// the streak after it.
    case counted(streak: Int)
    /// An older daily solved for the first time after a newer one. The time
    /// is kept; the streak is left alone, because rewinding it would break a
    /// live run. (Hashi 1.0 reset the streak to 1 here.)
    case late
    /// A daily that was already solved. Nothing is recorded: not the time,
    /// not the streak, and the caller should not count stats or best times.
    case replay(firstTime: TimeInterval)

    /// True when this solve must not count toward stats, best times or a
    /// share card's time.
    public var isReplay: Bool {
        if case .replay = self { true } else { false }
    }
}

/// The daily-puzzle record: per-day times and the streak.
///
/// A value type with no storage of its own, so the game's progress store
/// keeps persisting it under the key it already uses. The JSON shape is the
/// one Just Kakuro 1.1 writes (`lastCompleted`, `currentStreak`, `bestStreak`,
/// `completedTimes` keyed by `DayKey.isoString`); decoding tolerates any field
/// being absent, so a record written by an older or newer build never throws
/// the whole history away.
public struct DailyRecord: Codable, Equatable, Sendable {
    public var lastCompleted: DayKey?
    public var currentStreak: Int
    public var bestStreak: Int
    public var completedTimes: [String: TimeInterval]

    public init(lastCompleted: DayKey? = nil, currentStreak: Int = 0, bestStreak: Int = 0,
                completedTimes: [String: TimeInterval] = [:]) {
        self.lastCompleted = lastCompleted
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.completedTimes = completedTimes
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastCompleted = try? c.decodeIfPresent(DayKey.self, forKey: .lastCompleted)
        currentStreak = (try? c.decodeIfPresent(Int.self, forKey: .currentStreak)) ?? 0
        bestStreak = (try? c.decodeIfPresent(Int.self, forKey: .bestStreak)) ?? 0
        completedTimes = (try? c.decodeIfPresent([String: TimeInterval].self,
                                                 forKey: .completedTimes)) ?? [:]
    }

    private enum CodingKeys: String, CodingKey {
        case lastCompleted, currentStreak, bestStreak, completedTimes
    }

    public func hasCompleted(_ day: DayKey) -> Bool {
        completedTimes[day.isoString] != nil
    }

    public func time(for day: DayKey) -> TimeInterval? {
        completedTimes[day.isoString]
    }

    /// The streak as of `today`. Computed, never stored: a missed day shows 0
    /// without anything having to run at midnight.
    public func displayStreak(today: DayKey) -> Int {
        guard let last = lastCompleted else { return 0 }
        return last == today || last == today.previous() ? currentStreak : 0
    }

    /// True when yesterday kept the streak alive and today is still open: the
    /// streak ends at midnight unless today is solved.
    public func isAtRisk(today: DayKey) -> Bool {
        currentStreak > 0 && lastCompleted == today.previous() && !hasCompleted(today)
    }

    /// True when the streak shown today is the best one so far (and more than
    /// a single day, which is not worth calling a record).
    public func isBestStreak(today: DayKey) -> Bool {
        let shown = displayStreak(today: today)
        return shown > 1 && shown == bestStreak
    }

    /// Records a solved daily. Idempotent per day: a replay changes nothing.
    /// The streak increments on consecutive days and restarts at 1 after a
    /// gap; `lastCompleted` only moves forward.
    ///
    /// `today` guards against a clock that was set ahead. A daily solved on a
    /// future date would otherwise stay `lastCompleted`, and every real solve
    /// until that date would count as `.late`, holding the streak at 0. A
    /// `lastCompleted` more than one day after `today` is therefore dropped
    /// (its time is kept). One day of slack, because flying west across the
    /// date line moves `today` back a day legitimately.
    @discardableResult
    public mutating func record(day: DayKey, time: TimeInterval,
                                today: DayKey = DayKey(date: Date())) -> DailyOutcome {
        if let first = completedTimes[day.isoString] {
            return .replay(firstTime: first)
        }
        completedTimes[day.isoString] = time
        if let last = lastCompleted, today.days(until: last) > 1 {
            lastCompleted = nil
            currentStreak = 0
        }
        if let last = lastCompleted, !(last < day) {
            return .late
        }
        currentStreak = lastCompleted == day.previous() ? currentStreak + 1 : 1
        lastCompleted = day
        bestStreak = max(bestStreak, currentStreak)
        return .counted(streak: currentStreak)
    }
}
