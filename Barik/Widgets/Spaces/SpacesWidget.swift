import SwiftUI

struct SpacesWidget: View {
    @StateObject var viewModel = SpacesViewModel()

    private var showNavigator: Bool {
        isKeyPressed || showNavigatorProgrammally
    }
    @State private var isKeyPressed = false
    @State private var showNavigatorProgrammally = false
    @State private var keyMonitor: Any?

    @ObservedObject var configManager = ConfigManager.shared
    var foregroundHeight: CGFloat {
        configManager.config.experimental.foreground.resolveHeight()
    }
    var appMenuEnabled: Bool {
        configManager.config.experimental.appMenu.enabled
    }
    var navigatorKeyShortcut: KeyShortcut {
        configManager.config.experimental.appMenu.navigatorKey
    }

    var isAdvancedAnimation: Bool {
        configManager.config.experimental.appMenu.animation == .advanced
    }

    var body: some View {
        ZStack(alignment: .leading) {
            let spaces = viewModel.spaces

            if showNavigator || !appMenuEnabled {
                HStack(spacing: foregroundHeight < 30 ? 0 : 8) {
                    ForEach(spaces) { space in
                        SpaceView(space: space, isNavigator: true)
                            .transition(.blurReplace)
                    }
                }
                .padding(.horizontal, 5)
                .if(isAdvancedAnimation) {
                    $0.transition(.blurReplace.combined(with: .offset(y: 40)))
                }
                .if(!isAdvancedAnimation) {
                    $0.transition(.opacity)
                }
            }
            MenuBarItemsView()
                .opacity(showNavigator ? 0 : 1)
                .if(isAdvancedAnimation) {
                    $0
                        .offset(y: showNavigator ? -40 : 0)
                        .blur(radius: showNavigator ? 20 : 0)
                }

        }
        .experimentalConfiguration(horizontalPadding: 5, cornerRadius: 10)
        .animation(.smooth(duration: 0.3), value: viewModel.spaces)
        .animation(.smooth(duration: 0.3), value: showNavigatorProgrammally)
        .animation(
            showNavigatorProgrammally
                ? nil
                : (isKeyPressed
                    ? .timingCurve(1, 0, 0.3, 1, duration: 1.0) : .smooth(duration: 0.3)),
            value: isKeyPressed || showNavigatorProgrammally
        )
        .foregroundColor(.foreground)
        .environmentObject(viewModel)
        .onChange(of: viewModel.spaces) { oldValue, newValue in
            if oldValue != newValue {
                showNavigatorProgrammally = true
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(800)) {
                    showNavigatorProgrammally = false
                }
            }
        }
        .onAppear {
            keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
                let eventModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let modificatorIsPressed = eventModifiers == navigatorKeyShortcut.modifiers

                DispatchQueue.main.async {
                    self.isKeyPressed = modificatorIsPressed
                }
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
    }
}
