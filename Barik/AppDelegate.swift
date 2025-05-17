import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var backgroundPanel: NSPanel?
    private var menuBarPanel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let error = ConfigManager.shared.initError {
            showFatalConfigError(message: error)
            return
        }

        // Show "What's New" banner if the app version is outdated
        if !VersionChecker.isLatestVersion() {
            VersionChecker.updateVersionFile()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NotificationCenter.default.post(
                    name: Notification.Name("ShowWhatsNewBanner"), object: nil)
            }
        }

        MenuBarPopup.setup()
        setupPanels()
    }

    /// Configures and displays the background and menu bar panels.
    private func setupPanels() {
        // Clear existing panels
        backgroundPanel?.close()
        menuBarPanel?.close()
        backgroundPanel = nil
        menuBarPanel = nil

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.frame

        // Create background panel
        backgroundPanel = createPanel(
            frame: screenFrame,
            level: Int(CGWindowLevelForKey(.desktopWindow)),
            hostingRootView: AnyView(BackgroundView()))

        // Create menu bar panel
        menuBarPanel = createPanel(
            frame: screenFrame,
            level: Int(CGWindowLevelForKey(.backstopMenu)),
            hostingRootView: AnyView(MenuBarView()))
    }

    /// Creates an NSPanel with the provided parameters.
    private func createPanel(
        frame: CGRect, level: Int,
        hostingRootView: AnyView
    ) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.level = NSWindow.Level(rawValue: level)
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.contentView = NSHostingView(rootView: hostingRootView)
        panel.orderFront(nil)
        return panel
    }

    private func showFatalConfigError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Configuration Error"
        alert.informativeText =
            "\(message)\n\nPlease double check ~/.barik-config.toml and try again."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quit")

        alert.runModal()
        NSApplication.shared.terminate(nil)
    }
}
