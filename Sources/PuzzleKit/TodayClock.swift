import Foundation
import Observation

/// Today's `DayKey`, kept current.
///
/// Every game computed `today` inside a view body. A body only re-runs when
/// something it reads changes, so Home left open across midnight kept showing
/// yesterday's daily as unsolved-and-open, or today's as solved. This is the
/// one observable source instead: it refreshes on the system's day-change,
/// time-zone and clock notifications, and the app calls `refresh()` when its
/// scene becomes active (no notification is delivered while suspended).
@Observable @MainActor
public final class TodayClock {
    public private(set) var today: DayKey

    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let calendar: @Sendable () -> Calendar
    @ObservationIgnored private var observers: ObserverBag?

    /// - Parameters:
    ///   - now: the clock, injectable for tests.
    ///   - calendar: read on every refresh, so a time-zone change is seen.
    ///   - center: where the day-change notifications arrive; pass `nil` to
    ///     observe nothing (tests drive `refresh()` themselves).
    public init(now: @escaping @Sendable () -> Date = { Date() },
                calendar: @escaping @Sendable () -> Calendar = { DayKey.localCalendar },
                center: NotificationCenter? = .default) {
        self.now = now
        self.calendar = calendar
        today = DayKey(date: now(), calendar: calendar())
        if let center {
            observers = ObserverBag(center: center, names: [
                .NSCalendarDayChanged, .NSSystemTimeZoneDidChange, .NSSystemClockDidChange,
            ]) { [weak self] in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    /// Re-reads the clock. Assigns only on a real change, so observers of
    /// `today` are not invalidated every time the app comes to the front.
    public func refresh() {
        let fresh = DayKey(date: now(), calendar: calendar())
        if fresh != today { today = fresh }
    }
}

/// Owns notification tokens and removes them when released. A separate
/// object so `TodayClock`'s deinit, which is nonisolated, never has to touch
/// main-actor state.
private final class ObserverBag: @unchecked Sendable {
    private let center: NotificationCenter
    private var tokens: [any NSObjectProtocol] = []

    init(center: NotificationCenter, names: [Notification.Name],
         action: @escaping @Sendable () -> Void) {
        self.center = center
        // Delivered on the main queue, which is what makes the
        // `assumeIsolated` in the action sound.
        tokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { _ in action() }
        }
    }

    deinit {
        for token in tokens { center.removeObserver(token) }
    }
}
