// ABOUTME: System UI automation helpers using CGEvent key simulation.
// ABOUTME: Opens Notification Center and Weather app without private API usage.

import AppKit
import CoreGraphics

enum SystemUIHelper {

    static func openNotificationCenter() {
        simulateKeyPress(keyCode: 0x38, flags: .maskCommand)
    }

    static func openWeatherApp() {
        let weatherAppURL = URL(fileURLWithPath: "/System/Applications/Weather.app")
        NSWorkspace.shared.open(weatherAppURL)
    }

    static func openCalendarApp() {
        let calendarAppURL = URL(fileURLWithPath: "/System/Applications/Calendar.app")
        NSWorkspace.shared.open(calendarAppURL)
    }

    private static func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
