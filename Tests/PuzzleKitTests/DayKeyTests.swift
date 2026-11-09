import Foundation
import Testing
@testable import PuzzleKit

struct DayKeyTests {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// The Zeller weekday Just Kakuro 1.1 ships. `DayKey.weekday` replaces it
    /// and must agree on every day, or a game's schedule moves.
    private func shippedZeller(_ day: DayKey) -> Int {
        var y = day.year, m = day.month
        if m < 3 { m += 12; y -= 1 }
        let k = y % 100, j = y / 100
        let h = (day.day + (13 * (m + 1)) / 5 + k + k / 4 + j / 4 + 5 * j) % 7
        return ((h + 6) % 7) + 1
    }

    @Test func arithmeticMatchesFoundationAcrossFourCenturies() {
        // 1900-01-01 … 2300-12-31 covers both kinds of century year.
        var date = utc.date(from: DateComponents(year: 1900, month: 1, day: 1))!
        let end = utc.date(from: DateComponents(year: 2300, month: 12, day: 31))!
        var key = DayKey(date: date, calendar: utc)
        while date <= end {
            let expected = DayKey(date: date, calendar: utc)
            #expect(key == expected)
            #expect(key.weekday == utc.component(.weekday, from: date))
            #expect(key.weekday == shippedZeller(key))
            #expect(DayKey(julianDay: key.julianDay) == key)
            date = utc.date(byAdding: .day, value: 1, to: date)!
            key = key.next()
            if key != DayKey(date: date, calendar: utc) { break }
        }
        #expect(key == DayKey(year: 2301, month: 1, day: 1))
    }

    @Test func previousCrossesMonthYearAndLeapDay() {
        #expect(DayKey(year: 2026, month: 1, day: 1).previous() == DayKey(year: 2025, month: 12, day: 31))
        #expect(DayKey(year: 2024, month: 3, day: 1).previous() == DayKey(year: 2024, month: 2, day: 29))
        #expect(DayKey(year: 2100, month: 3, day: 1).previous() == DayKey(year: 2100, month: 2, day: 28))
        #expect(DayKey(year: 2000, month: 3, day: 1).previous() == DayKey(year: 2000, month: 2, day: 29))
        #expect(DayKey(year: 2026, month: 11, day: 10).days(until: DayKey(year: 2027, month: 11, day: 10)) == 365)
    }

    @Test func gregorianWhateverThePhoneCalendar() {
        // 2026-11-10 noon in Tokyo, read through the default local calendar,
        // must not come out as Reiwa 8.
        let date = utc.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 3))!
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var gregorianTokyo = Calendar(identifier: .gregorian)
        gregorianTokyo.timeZone = japanese.timeZone
        #expect(DayKey(date: date, calendar: gregorianTokyo) == DayKey(year: 2026, month: 11, day: 10))
        #expect(DayKey.localCalendar.identifier == .gregorian)
    }

    @Test func midnightTurnsOverInTheDeviceTimeZone() {
        // 23:30 in New York is already the next day in UTC.
        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = TimeZone(identifier: "America/New_York")!
        let lateEvening = ny.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 23, minute: 30))!
        #expect(DayKey(date: lateEvening, calendar: ny) == DayKey(year: 2026, month: 11, day: 10))
        #expect(DayKey(date: lateEvening, calendar: utc) == DayKey(year: 2026, month: 11, day: 11))
    }

    @Test func isoStringRoundTripsAndRejectsNonsense() {
        let day = DayKey(year: 2026, month: 2, day: 3)
        #expect(day.isoString == "2026-02-03")
        #expect(DayKey(isoString: "2026-02-03") == day)
        #expect(DayKey(isoString: "2026-02-29") == nil)
        #expect(DayKey(isoString: "2024-02-29") != nil)
        #expect(DayKey(isoString: "2026-13-01") == nil)
        #expect(DayKey(isoString: "2026-2-3") == nil)
        #expect(DayKey(isoString: "") == nil)
    }

    @Test func encodesInTheShapeTheGamesAlreadyStore() throws {
        let json = #"{"year":2026,"month":1,"day":1}"#
        let day = try JSONDecoder().decode(DayKey.self, from: Data(json.utf8))
        #expect(day == DayKey(year: 2026, month: 1, day: 1))
        let back = try JSONSerialization.jsonObject(with: JSONEncoder().encode(day)) as? [String: Int]
        #expect(back == ["year": 2026, "month": 1, "day": 1])
    }

    @Test func seedIsFNV1aOverPrefixAndISODate() {
        // Reference values: FNV-1a 64 of "" and "a" are the published vectors.
        #expect(DaySeed.fnv1a("") == 0xcbf29ce484222325)
        #expect(DaySeed.fnv1a("a") == 0xaf63dc4c8601ec8c)
        let day = DayKey(year: 2026, month: 1, day: 1)
        #expect(DaySeed.seed(prefix: "kakuro.daily.v1.", day: day)
                == DaySeed.fnv1a("kakuro.daily.v1.2026-01-01"))
    }
}
