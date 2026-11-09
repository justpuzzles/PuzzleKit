import Foundation

/// A calendar day, the key for daily puzzles and streaks.
///
/// Year, month and day are always **Gregorian**, read in the device's time
/// zone: the daily turns over at the player's midnight, but a phone set to
/// the Japanese or Buddhist calendar gets the same board and weekday as
/// everyone else. Lifted from Just Kakuro 1.1 (build 9), which is the version
/// that fixed this; the other games' copies predate the fix or match it.
///
/// Encodes as `{"year":…,"month":…,"day":…}`, the shape every game already
/// stores, so adopting this type needs no migration.
public struct DayKey: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Gregorian in the device's current time zone.
    public static var localCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    public init(date: Date, calendar: Calendar = DayKey.localCalendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        year = parts.year ?? 2000
        month = parts.month ?? 1
        day = parts.day ?? 1
    }

    /// Parses `YYYY-MM-DD`, the form `isoString` writes. Rejects anything
    /// that is not a real Gregorian date.
    public init?(isoString: String) {
        let parts = isoString.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...DayKey.daysIn(month: m, year: y)).contains(d)
        else { return nil }
        self.init(year: y, month: m, day: d)
    }

    /// `YYYY-MM-DD`. Part of every game's seed string, so its format is
    /// shipped API: never change it.
    public var isoString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public var description: String { isoString }

    /// Local midnight at the start of this day.
    public func date(calendar: Calendar = DayKey.localCalendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    /// The day before, by pure date arithmetic (no time zone, no DST).
    public func previous() -> DayKey { adding(days: -1) }

    /// The day after.
    public func next() -> DayKey { adding(days: 1) }

    /// Kept for source compatibility with the games' own copies, which took
    /// a calendar. The result never depended on it for a valid day.
    public func previous(calendar: Calendar) -> DayKey { previous() }

    /// Shifts by whole days on the proleptic Gregorian calendar. Independent
    /// of time zones, so it cannot skip or repeat a day across DST.
    public func adding(days: Int) -> DayKey {
        DayKey(julianDay: julianDay + days)
    }

    /// Days from `self` to `other` (positive when `other` is later).
    public func days(until other: DayKey) -> Int {
        other.julianDay - julianDay
    }

    /// 1 = Sunday … 7 = Saturday, the convention of `Calendar.component(.weekday)`.
    /// Computed from the date itself, never from a `Calendar`, so a time zone
    /// cannot shift a daily schedule.
    public var weekday: Int {
        // Julian Day Number 0 was a Monday; JDN mod 7: 0 = Mon … 6 = Sun.
        let mondayBased = ((julianDay % 7) + 7) % 7
        return (mondayBased + 1) % 7 + 1
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // MARK: - Julian day arithmetic

    /// Julian Day Number of this Gregorian date (Fliegel & Van Flandern).
    var julianDay: Int {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    init(julianDay jdn: Int) {
        let a = jdn + 32044
        let b = (4 * a + 3) / 146097
        let c = a - 146097 * b / 4
        let d = (4 * c + 3) / 1461
        let e = c - 1461 * d / 4
        let m = (5 * e + 2) / 153
        day = e - (153 * m + 2) / 5 + 1
        month = m + 3 - 12 * (m / 10)
        year = 100 * b + d - 4800 + m / 10
    }

    static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 2: (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }
}
