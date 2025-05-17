import AppKit
import SwiftUI

/// This view shows a space with its windows.
struct SpaceView: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @EnvironmentObject var viewModel: SpacesViewModel

    var config: ConfigData { configProvider.config }
    var spaceConfig: ConfigData { config["space"]?.dictionaryValue ?? [:] }

    @ObservedObject var configManager = ConfigManager.shared
    var foregroundHeight: CGFloat {
        configManager.config.experimental.foreground.resolveHeight()
    }

    var showKey: Bool { spaceConfig["show-key"]?.boolValue ?? true }

    let space: AnySpace
    let isNavigator: Bool

    @State private var isHovered = false

    private var isFocused: Bool {
        space.windows.contains { $0.isFocused } || space.isFocused
    }

    private var backgroundColor: Color? {
        guard isNavigator else { return nil }
        if foregroundHeight < 30 {
            return isFocused ? Color.noActive : Color.clear
        } else {
            return isFocused ? Color.active : Color.noActive
        }
    }

    var body: some View {
        Button(action: { viewModel.switchToSpace(space, needWindowFocus: true) }) {
            HStack(spacing: 0) {
                Spacer().frame(width: 10)
                if isNavigator && showKey {
                    Text(space.id)
                        .font(.headline)
                        .frame(minWidth: 15)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer().frame(width: 5)
                }
                HStack(spacing: 2) {
                    if isNavigator {
                        ForEach(space.windows) { window in
                            WindowView(window: window, space: space).id(window.id)
                        }
                    } else {
                        MenuBarItemsView()
                    }
                }
                Spacer().frame(width: 10)
            }
            .frame(height: 30)
            .background(backgroundColor)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: foregroundHeight < 30 ? 0 : 8, style: .continuous)
            )
            .shadow(color: .shadow, radius: foregroundHeight < 30 ? 0 : 2)
        }.buttonStyle(TransparentButtonStyle())
    }
}
