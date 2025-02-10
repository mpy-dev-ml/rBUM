import XCTest
@testable import Core

final class DateProviderTests: XCTestCase {
    // MARK: - Properties

    private var dateProvider: DateProvider!
    private var fixedDate: Date!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        fixedDate = Date(timeIntervalSince1970: 1_706_976_000) // 2024-02-03 17:00:00 UTC
        dateProvider = TestDateProvider(fixedDate: fixedDate)
    }

    override func tearDown() async throws {
        dateProvider = nil
        fixedDate = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func testCurrentDate() throws {
        let currentDate = dateProvider.now
        XCTAssertEqual(currentDate, fixedDate)
    }

    func testDateComparison() throws {
        let earlier = Date(timeIntervalSince1970: 1_706_975_900) // 100 seconds earlier
        let later = Date(timeIntervalSince1970: 1_706_976_100) // 100 seconds later

        XCTAssertTrue(dateProvider.isDate(earlier, before: later))
        XCTAssertFalse(dateProvider.isDate(later, before: earlier))
        XCTAssertFalse(dateProvider.isDate(earlier, after: later))
        XCTAssertTrue(dateProvider.isDate(later, after: earlier))
    }

    func testDateDifference() throws {
        let earlier = Date(timeIntervalSince1970: 1_706_975_400) // 600 seconds earlier
        let later = Date(timeIntervalSince1970: 1_706_976_600) // 600 seconds later

        XCTAssertEqual(dateProvider.timeInterval(between: earlier, and: later), 1200)
        XCTAssertEqual(dateProvider.timeInterval(between: later, and: earlier), -1200)
    }

    func testDateFormatting() throws {
        let formattedDate = dateProvider.formatDate(fixedDate, style: .medium)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        XCTAssertEqual(formattedDate, formatter.string(from: fixedDate))
    }

    func testDateTimeFormatting() throws {
        let formattedDateTime = dateProvider.formatDateTime(fixedDate, dateStyle: .medium, timeStyle: .short)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        XCTAssertEqual(formattedDateTime, formatter.string(from: fixedDate))
    }

    func testRelativeDateFormatting() throws {
        let now = fixedDate
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!

        let yesterdayFormatted = dateProvider.formatRelativeDate(yesterday)
        let tomorrowFormatted = dateProvider.formatRelativeDate(tomorrow)

        XCTAssertTrue(yesterdayFormatted.contains("yesterday") || yesterdayFormatted.contains("1 day ago"))
        XCTAssertTrue(tomorrowFormatted.contains("tomorrow") || tomorrowFormatted.contains("in 1 day"))
    }

    func testDateComponents() throws {
        let components = dateProvider.components([.year, .month, .day], from: fixedDate)

        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 3)
    }

    func testDateManipulation() throws {
        let oneHourLater = dateProvider.date(byAdding: .hour, value: 1, to: fixedDate)
        let oneDayEarlier = dateProvider.date(byAdding: .day, value: -1, to: fixedDate)

        XCTAssertEqual(dateProvider.timeInterval(between: fixedDate, and: oneHourLater), 3600)
        XCTAssertEqual(dateProvider.timeInterval(between: oneDayEarlier, and: fixedDate), 86400)
    }
}

// MARK: - Test Helpers

private final class TestDateProvider: DateProvider {
    private let fixedDate: Date

    init(fixedDate: Date) {
        self.fixedDate = fixedDate
    }

    var now: Date {
        fixedDate
    }

    func isDate(_ date1: Date, before date2: Date) -> Bool {
        date1 < date2
    }

    func isDate(_ date1: Date, after date2: Date) -> Bool {
        date1 > date2
    }

    func timeInterval(between date1: Date, and date2: Date) -> TimeInterval {
        date2.timeIntervalSince(date1)
    }

    func formatDate(_ date: Date, style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func formatDateTime(_ date: Date, dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }

    func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: now)
    }

    func components(_ components: Set<Calendar.Component>, from date: Date) -> DateComponents {
        Calendar.current.dateComponents(components, from: date)
    }

    func date(byAdding component: Calendar.Component, value: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: component, value: value, to: date)!
    }
}
