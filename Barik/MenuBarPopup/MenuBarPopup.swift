import SwiftUI

private var panel: HidingPanel?

class HidingPanel: NSPanel, NSWindowDelegate {
    var hideTimer: Timer?
    var contentIdentifier: String?

    override var canBecomeKey: Bool {
        return true
    }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing bufferingType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect, styleMask: style, backing: bufferingType,
            defer: flag)
        self.delegate = self
    }

    func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .willHideWindow, object: nil)
        }

        hideTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(
                Constants.menuBarPopupAnimationDurationInMilliseconds) / 1000.0,
            repeats: false
        ) { [weak self] _ in
            self?.orderOut(nil)
        }
    }
}

class MenuBarPopup {
    static func show<Content: View>(
        rect: CGRect, id: String, @ViewBuilder content: @escaping () -> Content
    ) {
        guard let panel = panel else { return }

        if panel.isKeyWindow, panel.contentIdentifier == id {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .willHideWindow, object: nil)
            }

            let duration =
                Double(Constants.menuBarPopupAnimationDurationInMilliseconds)
                / 1000.0
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                panel.orderOut(nil)
                panel.contentIdentifier = nil
            }
            return
        }

        let isContentChange =
            panel.isKeyWindow
            && (panel.contentIdentifier != nil && panel.contentIdentifier != id)
        panel.contentIdentifier = id

        panel.hideTimer?.invalidate()
        panel.hideTimer = nil

        if panel.isKeyWindow {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .willChangeContent, object: nil)
            }

            let baseDuration =
                Double(Constants.menuBarPopupAnimationDurationInMilliseconds)
                / 1000.0
            let duration = isContentChange ? baseDuration / 2 : baseDuration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                panel.contentView = NSHostingView(
                    rootView:
                        ZStack {
                            MenuBarPopupView {
                                content()
                            }
                            .position(x: rect.midX)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
                panel.makeKeyAndOrderFront(nil)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: .willShowWindow, object: nil)
                }
            }
        } else {
            panel.contentView = NSHostingView(
                rootView:
                    ZStack {
                        MenuBarPopupView {
                            content()
                        }
                        .position(x: rect.midX)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
            panel.makeKeyAndOrderFront(nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .willShowWindow, object: nil)
            }
        }
    }

    static func setup() {
        // Close existing panel if any
        panel?.close()
        panel = nil

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.frame
        let panelFrame = NSRect(
            x: frame.minX,
            y: frame.minY,
            width: frame.width,
            height: frame.height
        )

        let newPanel = HidingPanel(
            contentRect: panelFrame,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        newPanel.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.collectionBehavior = [.canJoinAllSpaces]

        panel = newPanel
    }
}
