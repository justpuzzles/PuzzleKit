import Foundation
import Testing
@testable import PuzzleKit

struct DailyRecordTests {
    let mon = DayKey(year: 2026, month: 11, day: 9)
    var tue: DayKey { mon.next() }
    var wed: DayKey { tue.next() }

    @Test func consecutiveDaysBuildAStreakAndAGapRestartsIt() {
        var record = DailyRecord()
        #expect(record.record(day: mon, time: 60) == .counted(streak: 1))
        #expect(record.record(day: tue, time: 50) == .counted(streak: 2))
        #expect(record.record(day: wed.next(), time: 40) == .counted(streak: 1))
        #expect(record.bestStreak == 2)
    }

    @Test func aReplayRecordsNothing() {
        var record = DailyRecord()
        record.record(day: mon, time: 90)
        let before = record
        let outcome = record.record(day: mon, time: 30)
        #expect(outcome == .replay(firstTime: 90))
        #expect(outcome.isReplay)
        #expect(record == before)
    }

    @Test func finishingAnOlderDailyLateKeepsTheStreak() {
        var record = DailyRecord()
        record.record(day: tue, time: 60)
        record.record(day: wed, time: 60)
        #expect(record.record(day: mon, time: 120) == .late)
        #expect(record.currentStreak == 2)
        #expect(record.lastCompleted == wed)
        #expect(record.time(for: mon) == 120)
    }

    @Test func displayStreakFallsToZeroAfterAMissedDay() {
        var record = DailyRecord()
        record.record(day: mon, time: 60)
        record.record(day: tue, time: 60)
        #expect(record.displayStreak(today: tue) == 2)
        #expect(record.displayStreak(today: wed) == 2)
        #expect(record.isAtRisk(today: wed))
        #expect(record.displayStreak(today: wed.next()) == 0)
        #expect(!record.isAtRisk(today: wed.next()))
        #expect(record.isBestStreak(today: tue))
    }

    @Test func decodesKakuroOnePointOneRecords() throws {
        // Exactly what Just Kakuro 1.1 writes under kakuro.daily.v1.
        let json = #"""
        {"lastCompleted":{"year":2026,"month":11,"day":9},"currentStreak":3,"bestStreak":5,
         "completedTimes":{"2026-11-08":75.5,"2026-11-09":61}}
        """#
        let record = try JSONDecoder().decode(DailyRecord.self, from: Data(json.utf8))
        #expect(record.currentStreak == 3)
        #expect(record.bestStreak == 5)
        #expect(record.time(for: mon) == 61)
        #expect(record.lastCompleted == mon)
    }

    @Test func aPartialRecordStillDecodes() throws {
        let record = try JSONDecoder().decode(DailyRecord.self,
                                              from: Data(#"{"bestStreak":4}"#.utf8))
        #expect(record.bestStreak == 4)
        #expect(record.completedTimes.isEmpty)
        #expect(record.lastCompleted == nil)
    }

    /// Clock set ahead to Dec 1 and that daily solved: once the clock is
    /// back, today's solve starts a streak instead of counting as late.
    @Test func aDailySolvedUnderAClockSetAheadDoesNotFreezeTheStreak() {
        var record = DailyRecord()
        let december = DayKey(year: 2026, month: 12, day: 1)
        #expect(record.record(day: december, time: 30, today: december) == .counted(streak: 1))
        #expect(record.record(day: mon, time: 60, today: mon) == .counted(streak: 1))
        #expect(record.record(day: tue, time: 50, today: tue) == .counted(streak: 2))
        #expect(record.displayStreak(today: tue) == 2)
        // The future day's time is kept: replaying it later records nothing.
        #expect(record.time(for: december) == 30)
    }

    /// Flying west across the date line: today goes back a day. The streak
    /// that ended on "tomorrow" must survive.
    @Test func oneDayAheadIsTheDateLineNotAWrongClock() {
        var record = DailyRecord()
        record.record(day: tue, time: 60, today: tue)
        record.record(day: wed, time: 60, today: wed)
        #expect(record.record(day: tue.previous(), time: 70, today: tue) == .late)
        #expect(record.currentStreak == 2)
        #expect(record.lastCompleted == wed)
    }
}
