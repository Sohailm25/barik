// ABOUTME: NSPanel subclass that can become the key window for keyboard input.
// ABOUTME: Used by the menu bar panel so inline TextFields can receive keystrokes.

import AppKit

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
