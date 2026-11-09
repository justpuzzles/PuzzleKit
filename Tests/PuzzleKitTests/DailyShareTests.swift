import Foundation
import Testing
@testable import PuzzleKit

struct DailyShareTests {
    let day = DayKey(year: 2026, month: 11, day: 10)

    @Test func fullCard() {
        let share = DailyShare(game: "Just Kakuro", day: day, timeText: "4:32", streak: 5,
                               detail: "Medium 9×9",
                               url: URL(string: "https://kaikunze.de/justkakuro/"))
        #expect(share.text(locale: Locale(identifier: "en_US")) == """
            Just Kakuro · Daily · Nov 10, 2026
            Solved in 4:32 · Medium 9×9
            5-day streak
            https://kaikunze.de/justkakuro/
            """)
    }

    @Test func aOneDayStreakIsNotWorthALine() {
        let share = DailyShare(game: "Just Hashi", day: day, timeText: "1:05", streak: 1)
        #expect(share.text(locale: Locale(identifier: "en_US")) == """
            Just Hashi · Daily · Nov 10, 2026
            Solved in 1:05
            """)
    }

    @Test func theDayIsTheKeyNotTheDeviceTimeZone() {
        // Whatever zone the test machine is in, the date printed is the key's.
        let share = DailyShare(game: "G", day: DayKey(year: 2026, month: 1, day: 1),
                               timeText: "0:10", streak: 0)
        #expect(share.dayText(locale: Locale(identifier: "en_US")) == "Jan 1, 2026")
    }
}
