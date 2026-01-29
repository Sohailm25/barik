// ABOUTME: Global keyboard shortcut manager using the HotKey library (soffes/HotKey).
// ABOUTME: Registers Ctrl+Space by default to toggle the Ghosty assistant panel.

import AppKit
import HotKey

class HotKeyManager {
    static let shared = HotKeyManager()
    private var toggleHotKey: HotKey?

    private init() {}

    func setup() {
        toggleHotKey = HotKey(key: .space, modifiers: [.control])
        toggleHotKey?.keyDownHandler = { [weak self] in
            _ = self
            NotificationCenter.default.post(name: .toggleGhostyPanel, object: nil)
        }
    }

    func updateHotKey(key: Key, modifiers: NSEvent.ModifierFlags) {
        toggleHotKey = HotKey(key: key, modifiers: modifiers)
        toggleHotKey?.keyDownHandler = { [weak self] in
            _ = self
            NotificationCenter.default.post(name: .toggleGhostyPanel, object: nil)
        }
    }
}

extension Notification.Name {
    static let toggleGhostyPanel = Notification.Name("toggleGhostyPanel")
}
