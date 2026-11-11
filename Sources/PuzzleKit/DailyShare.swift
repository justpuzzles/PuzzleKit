import Foundation

/// The text a player shares after a daily: spoiler-free, short enough for a
/// message, and the same shape across the family so the games read as one.
///
///     Just Kakuro · Daily · Nov 10, 2026
///     Solved in 4:32 · Medium 9×9
///     5-day streak
///     https://kaikunze.de/justkakuro/
public struct DailyShare: Equatable, Sendable {
    public var game: String
    public var day: DayKey
    /// Already formatted by the game (each has its own clock style).
    public var timeText: String
    public var streak: Int
    /// Optional detail after the time, e.g. the board's size and difficulty.
    public var detail: String?
    public var url: URL?

    public init(game: String, day: DayKey, timeText: String, streak: Int,
                detail: String? = nil, url: URL? = nil) {
        self.game = game
        self.day = day
        self.timeText = timeText
        self.streak = streak
        self.detail = detail
        self.url = url
    }

    /// The language the app is shown in: the first of its own localizations
    /// that the player prefers. The share text is in that language, so the
    /// date must be too; the phone's region alone gave an English line a
    /// German, Japanese or Arabic-digit date.
    public static var appLocale: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
    }

    /// The day as the app's language writes it, on the Gregorian calendar
    /// that the day key itself uses.
    public func dayText(locale: Locale = DailyShare.appLocale) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let date = day.date(calendar: calendar)
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted,
                                     locale: locale, calendar: calendar)
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }

    public func text(locale: Locale = DailyShare.appLocale) -> String {
        var lines = ["\(game) · Daily · \(dayText(locale: locale))"]
        lines.append(["Solved in \(timeText)", detail].compactMap { $0 }.joined(separator: " · "))
        if streak > 1 {
            lines.append("\(streak)-day streak")
        }
        if let url {
            lines.append(url.absoluteString)
        }
        return lines.joined(separator: "\n")
    }
}
