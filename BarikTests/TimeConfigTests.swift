// ABOUTME: Tests for time widget click-action config parsing.
// ABOUTME: Verifies parsing of click-action option (calendar vs notification-center).

import XCTest
import TOMLDecoder
@testable import Barik

final class TimeConfigTests: XCTestCase {

    func testClickActionCalendarParses() throws {
        let toml = """
        [widgets]
        displayed = []

        [widgets.default.time]
        click-action = "calendar"
        """
        let decoder = TOMLDecoder()
        let root = try decoder.decode(RootToml.self, from: toml)

        let timeConfig = root.widgets.config(for: "default.time")
        XCTAssertNotNil(timeConfig)
        XCTAssertEqual(timeConfig?["click-action"]?.stringValue, "calendar")
    }

    func testClickActionNotificationCenterParses() throws {
        let toml = """
        [widgets]
        displayed = []

        [widgets.default.time]
        click-action = "notification-center"
        """
        let decoder = TOMLDecoder()
        let root = try decoder.decode(RootToml.self, from: toml)

        let timeConfig = root.widgets.config(for: "default.time")
        XCTAssertNotNil(timeConfig)
        XCTAssertEqual(timeConfig?["click-action"]?.stringValue, "notification-center")
    }

    func testClickActionDefaultsToCalendarWhenOmitted() throws {
        let toml = """
        [widgets]
        displayed = []

        [widgets.default.time]
        format = "E d, J:mm"
        """
        let decoder = TOMLDecoder()
        let root = try decoder.decode(RootToml.self, from: toml)

        let timeConfig = root.widgets.config(for: "default.time")
        XCTAssertNotNil(timeConfig)
        XCTAssertNil(timeConfig?["click-action"])
    }

    func testTimeClickActionEnumParsesCalendar() {
        let action = TimeClickAction(rawValue: "calendar")
        XCTAssertEqual(action, .calendar)
    }

    func testTimeClickActionEnumParsesNotificationCenter() {
        let action = TimeClickAction(rawValue: "notification-center")
        XCTAssertEqual(action, .notificationCenter)
    }

    func testTimeClickActionEnumReturnsNilForInvalid() {
        let action = TimeClickAction(rawValue: "invalid")
        XCTAssertNil(action)
    }
}
