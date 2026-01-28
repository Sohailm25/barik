// ABOUTME: Smoke tests verifying TOML config parsing works correctly.
// ABOUTME: Tests that RootToml and its nested config structs decode from TOML strings.

import XCTest
import TOMLDecoder
@testable import Barik

final class ConfigParsingTests: XCTestCase {

    // MARK: - Existing Config Parsing

    func testMinimalTOMLParses() throws {
        let toml = """
        theme = "dark"

        [widgets]
        displayed = ["default.spaces", "default.time"]
        """
        let decoder = TOMLDecoder()
        let root = try decoder.decode(RootToml.self, from: toml)

        XCTAssertEqual(root.theme, "dark")
        XCTAssertEqual(root.widgets.displayed.count, 2)
        XCTAssertEqual(root.widgets.displayed[0].id, "default.spaces")
        XCTAssertEqual(root.widgets.displayed[1].id, "default.time")
    }

    func testEmptyWidgetsDisplayedParses() throws {
        let toml = """
        [widgets]
        displayed = []
        """
        let decoder = TOMLDecoder()
        let root = try decoder.decode(RootToml.self, from: toml)

        XCTAssertTrue(root.widgets.displayed.isEmpty)
    }

    func testThemeDefaultsToNilWhenOmitted() throws {
        let toml = """
        [widgets]
        displayed = []
        """
        let decoder = TOMLDecoder()
        let root = try decoder.decode(RootToml.self, from: toml)

        XCTAssertNil(root.theme)
    }

    func testInlineWidgetParamsParse() throws {
        let toml = """
        [widgets]
        displayed = [
            { "default.time" = { time-zone = "America/Los_Angeles", format = "E d, hh:mm" } }
        ]
        """
        let decoder = TOMLDecoder()
        let root = try decoder.decode(RootToml.self, from: toml)

        XCTAssertEqual(root.widgets.displayed.count, 1)
        XCTAssertEqual(root.widgets.displayed[0].id, "default.time")
        XCTAssertEqual(root.widgets.displayed[0].inlineParams["time-zone"]?.stringValue, "America/Los_Angeles")
        XCTAssertEqual(root.widgets.displayed[0].inlineParams["format"]?.stringValue, "E d, hh:mm")
    }

    func testWidgetSectionConfigParses() throws {
        let toml = """
        [widgets]
        displayed = ["default.battery"]

        [widgets.default.battery]
        show-percentage = true
        warning-level = 30
        """
        let decoder = TOMLDecoder()
        let root = try decoder.decode(RootToml.self, from: toml)

        let batteryConfig = root.widgets.config(for: "default.battery")
        XCTAssertNotNil(batteryConfig)
    }

    // MARK: - New Config Sections (will fail until T004-T007 implemented)

    func testLLMConfigParses() throws {
        let toml = """
        [widgets]
        displayed = []

        [llm]
        api-key = "sk-ant-test123"
        model = "claude-sonnet-4-20250514"
        pii-consent = false
        """
        let decoder = TOMLDecoder()
        let root = try decoder.decode(RootToml.self, from: toml)

        XCTAssertNotNil(root.llm)
        XCTAssertEqual(root.llm?.apiKey, "sk-ant-test123")
        XCTAssertEqual(root.llm?.model, "claude-sonnet-4-20250514")
        XCTAssertEqual(root.llm?.piiConsent, false)
    }

    func testLLMConfigDefaultsWhenOmitted() throws {
        let toml = """
        [widgets]
        displayed = []
        """
        let decoder = TOMLDecoder()
        let root = try decoder.decode(RootToml.self, from: toml)

        XCTAssertNil(root.llm)
    }

    func testMessagingConfigParses() throws {
        let toml = """
        [widgets]
        displayed = []

        [messaging.imessage]
        enabled = true
        lookback-hours = 48

        [messaging.gmail]
        enabled = false
        check-interval-minutes = 10
        """
        let decoder = TOMLDecoder()
        let root = try decoder.decode(RootToml.self, from: toml)

        XCTAssertNotNil(root.messaging)
        XCTAssertEqual(root.messaging?.imessage?.enabled, true)
        XCTAssertEqual(root.messaging?.imessage?.lookbackHours, 48)
        XCTAssertEqual(root.messaging?.gmail?.enabled, false)
        XCTAssertEqual(root.messaging?.gmail?.checkIntervalMinutes, 10)
    }

    func testNotchDrawerConfigParses() throws {
        let toml = """
        [widgets]
        displayed = []

        [notch-drawer]
        width = 350
        max-height = 500
        animation-duration = 0.5
        """
        let decoder = TOMLDecoder()
        let root = try decoder.decode(RootToml.self, from: toml)

        XCTAssertNotNil(root.notchDrawer)
        XCTAssertEqual(root.notchDrawer?.width, 350)
        XCTAssertEqual(root.notchDrawer?.maxHeight, 500)
        XCTAssertEqual(root.notchDrawer?.animationDuration, 0.5)
    }

    func testNotchDrawerConfigDefaultsWhenOmitted() throws {
        let toml = """
        [widgets]
        displayed = []
        """
        let decoder = TOMLDecoder()
        let root = try decoder.decode(RootToml.self, from: toml)

        XCTAssertNil(root.notchDrawer)
    }

    func testFullConfigWithAllSections() throws {
        let toml = """
        theme = "system"

        [widgets]
        displayed = ["default.spaces", "default.time"]

        [llm]
        api-key = "sk-ant-test"
        model = "claude-sonnet-4-20250514"
        pii-consent = true

        [messaging.imessage]
        enabled = true
        lookback-hours = 24

        [messaging.gmail]
        enabled = true
        check-interval-minutes = 5

        [notch-drawer]
        width = 300
        max-height = 450
        animation-duration = 0.3
        """
        let decoder = TOMLDecoder()
        let root = try decoder.decode(RootToml.self, from: toml)

        XCTAssertEqual(root.theme, "system")
        XCTAssertNotNil(root.llm)
        XCTAssertNotNil(root.messaging)
        XCTAssertNotNil(root.notchDrawer)
        XCTAssertEqual(root.widgets.displayed.count, 2)
    }
}
