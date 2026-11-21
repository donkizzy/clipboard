import Foundation
import Testing
@testable import Clipboard

@Suite("RelativeTime")
struct RelativeTimeTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private let locale = Locale(identifier: "en_GB")
    /// 21 Nov 2026, 12:00 UTC
    private let now = Date(timeIntervalSince1970: 1_795_262_400)

    private func short(secondsAgo: TimeInterval) -> String {
        RelativeTime.short(now.addingTimeInterval(-secondsAgo), now: now, calendar: calendar, locale: locale)
    }

    @Test("Under a minute reads as now", arguments: [0, 1, 59.9] as [TimeInterval])
    func now(seconds: TimeInterval) {
        #expect(short(secondsAgo: seconds) == "now")
    }

    @Test("Future dates (clock skew) read as now")
    func future() {
        #expect(short(secondsAgo: -30) == "now")
    }

    @Test("Minutes, hours and days floor", arguments: [
        (60, "1m"), (119, "1m"), (120, "2m"), (3_599, "59m"),
        (3_600, "1h"), (7_199, "1h"), (86_399, "23h"),
        (86_400, "1d"), (3 * 86_400, "3d"), (604_799, "6d"),
    ] as [(TimeInterval, String)])
    func units(seconds: TimeInterval, expected: String) {
        #expect(short(secondsAgo: seconds) == expected)
    }

    @Test("A week or older shows day and month")
    func shortDate() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 9))!
        #expect(RelativeTime.short(date, now: now, calendar: calendar, locale: locale) == "12 Nov")
    }

    @Test("Previous years include the year")
    func previousYear() {
        let date = calendar.date(from: DateComponents(year: 2025, month: 3, day: 4))!
        #expect(RelativeTime.short(date, now: now, calendar: calendar, locale: locale) == "4 Mar 2025")
    }

    @Test("Spoken form for VoiceOver", arguments: [
        (10, "just now"), (60, "1 minute ago"), (120, "2 minutes ago"),
        (3_600, "1 hour ago"), (2 * 86_400, "2 days ago"),
    ] as [(TimeInterval, String)])
    func spoken(seconds: TimeInterval, expected: String) {
        let date = now.addingTimeInterval(-seconds)
        #expect(RelativeTime.spoken(date, now: now, calendar: calendar, locale: locale) == expected)
    }
}
