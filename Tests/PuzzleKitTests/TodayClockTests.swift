import Foundation
import Observation
import Testing
@testable import PuzzleKit

/// A settable clock for tests.
final class FakeNow: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date
    init(_ date: Date) { value = date }
    func get() -> Date { lock.withLock { value } }
    func set(_ date: Date) { lock.withLock { value = date } }
}

@MainActor
struct TodayClockTests {
    nonisolated private static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        Self.utc.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test func refreshPicksUpMidnight() {
        let fake = FakeNow(at(2026, 11, 10, 23, 59))
        let clock = TodayClock(now: { fake.get() }, calendar: { Self.utc }, center: nil)
        #expect(clock.today == DayKey(year: 2026, month: 11, day: 10))
        fake.set(at(2026, 11, 11, 0, 1))
        clock.refresh()
        #expect(clock.today == DayKey(year: 2026, month: 11, day: 11))
    }

    @Test func theDayChangedNotificationRefreshes() async {
        let center = NotificationCenter()
        let fake = FakeNow(at(2026, 11, 10, 23, 59))
        let clock = TodayClock(now: { fake.get() }, calendar: { Self.utc }, center: center)
        fake.set(at(2026, 11, 11, 0, 0))
        center.post(name: .NSCalendarDayChanged, object: nil)
        // Delivered on the main queue; let it run.
        for _ in 0..<50 where clock.today.day != 11 {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(clock.today == DayKey(year: 2026, month: 11, day: 11))
    }

    @Test func aSameDayRefreshDoesNotInvalidateObservers() {
        let fake = FakeNow(at(2026, 11, 10, 9))
        let clock = TodayClock(now: { fake.get() }, calendar: { Self.utc }, center: nil)
        let fired = FakeNow(.distantPast)
        withObservationTracking { _ = clock.today } onChange: { fired.set(.now) }
        fake.set(at(2026, 11, 10, 18))
        clock.refresh()
        #expect(fired.get() == .distantPast)
        fake.set(at(2026, 11, 11, 1))
        clock.refresh()
        #expect(fired.get() != .distantPast)
    }
}
