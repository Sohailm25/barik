import SwiftUI

@main
struct BarikApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Barik", image: "MenuBar") {
                   Button("Quit Barik") { NSApplication.shared.terminate(nil) }
               }
    }
}
