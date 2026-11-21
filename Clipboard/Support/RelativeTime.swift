import Foundation

/// Compact timestamps for cards and rows: "now", "2m", "1h", "3d", "12 Nov".
enum RelativeTime {
    /// Short label as shown in the UI.
    ///
    /// - Under a minute (or in the future, e.g. clock skew): "now"
    /// - Under an hour: minutes ("2m"); under a day: hours ("1h")
    /// - Under a week: days ("3d")
    /// - Older: day and month ("12 Nov"), plus the year if it isn't this year
    static func short(
        _ date: Date,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "now"
        case ..<3_600: return "\(seconds / 60)m"
        case ..<86_400: return "\(seconds / 3_600)h"
        case ..<604_800: return "\(seconds / 86_400)d"
        default:
            let sameYear = calendar.isDate(date, equalTo: now, toGranularity: .year)
            return date.formatted(dayMonthStyle(includeYear: !sameYear, calendar: calendar, locale: locale))
        }
    }

    /// Spoken form for VoiceOver: "just now", "2 minutes ago", "12 November".
    static func spoken(
        _ date: Date,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        func ago(_ value: Int, _ unit: String) -> String {
            "\(value) \(unit)\(value == 1 ? "" : "s") ago"
        }
        switch seconds {
        case ..<60: return "just now"
        case ..<3_600: return ago(seconds / 60, "minute")
        case ..<86_400: return ago(seconds / 3_600, "hour")
        case ..<604_800: return ago(seconds / 86_400, "day")
        default:
            var style = Date.FormatStyle(date: .long, time: .omitted, locale: locale, calendar: calendar)
            style.timeZone = calendar.timeZone
            return date.formatted(style)
        }
    }

    private static func dayMonthStyle(includeYear: Bool, calendar: Calendar, locale: Locale) -> Date.VerbatimFormatStyle {
        let format: Date.FormatString = includeYear
            ? "\(day: .defaultDigits) \(month: .abbreviated) \(year: .defaultDigits)"
            : "\(day: .defaultDigits) \(month: .abbreviated)"
        return Date.VerbatimFormatStyle(format: format, locale: locale, timeZone: calendar.timeZone, calendar: calendar)
    }
}
