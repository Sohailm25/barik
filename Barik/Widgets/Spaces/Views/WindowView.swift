import SwiftUI

/// This view shows a window and its icon.
struct WindowView: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @EnvironmentObject var viewModel: SpacesViewModel

    var config: ConfigData { configProvider.config }
    var windowConfig: ConfigData { config["window"]?.dictionaryValue ?? [:] }
    var titleConfig: ConfigData {
        windowConfig["title"]?.dictionaryValue ?? [:]
    }

    var showTitle: Bool { windowConfig["show-title"]?.boolValue ?? true }
    var maxLength: Int { titleConfig["max-length"]?.intValue ?? 50 }
    var alwaysDisplayAppTitleFor: [String] {
        titleConfig["always-display-app-name-for"]?.arrayValue?.filter({
            $0.stringValue != nil
        }).map { $0.stringValue! } ?? []
    }

    let window: AnyWindow
    let space: AnySpace

    @State var isHovered = false

    var body: some View {
        let titleMaxLength = maxLength
        let size: CGFloat = 21
        let sameAppCount = space.windows.filter { $0.appName == window.appName }
            .count
        let title =
            sameAppCount > 1
                && !alwaysDisplayAppTitleFor.contains { $0 == window.appName }
            ? window.title ?? "" : (window.appName ?? "")
        let spaceIsFocused = space.windows.contains { $0.isFocused }
        Button(action: {
            viewModel.focusSpace(spaceId: space.id)
            usleep(100_000)
            viewModel.focusWindow(windowId: window.id)
        }) {
            HStack {
                ZStack {
                    // Get the app icon - try multiple methods
                    if let appIcon = getAppIcon() {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: size, height: size)
                            .shadow(
                                color: .iconShadow,
                                radius: 2
                            )
                    } else {
                        Image(systemName: "questionmark.circle")
                            .resizable()
                            .frame(width: size, height: size)
                    }
                }
                .opacity(spaceIsFocused && !window.isFocused ? 0.5 : 1)
                .transition(.blurReplace)

                if window.isFocused, !title.isEmpty, showTitle {
                    HStack {
                        Text(
                            title.count > titleMaxLength
                                ? String(title.prefix(titleMaxLength)) + "..."
                                : title
                        )
                        .fixedSize(horizontal: true, vertical: false)
                        .shadow(color: .foregroundShadow, radius: 3)
                        .fontWeight(.semibold)
                        Spacer().frame(width: 5)
                    }
                    .transition(.blurReplace)
                }
            }
            .padding(.all, 2)
            .background(
                isHovered || (!showTitle && window.isFocused)
                    ? Color.hovered : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .frame(height: 30)
            .contentShape(Rectangle())
            .onHover {
                isHovered = $0
            }
        }.buttonStyle(TransparentButtonStyle())
    }
    
    /// Get the app icon for the window using various methods
    private func getAppIcon() -> NSImage? {
        // Method 1: Use bundle identifier if available
        if let bundleId = window.appBundleIdentifier, !bundleId.isEmpty, 
           let icon = IconCache.shared.getIcon(for: bundleId) {
            return icon
        }
        
        // Method 2: Try to get icon by app URL if app name is available
        if let appName = window.appName {
            // Try bundle identifier
            if let bundleId = window.appBundleIdentifier, 
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                return icon
            }
            
            // Try app name path
            let appPath = "/Applications/\(appName).app"
            if FileManager.default.fileExists(atPath: appPath) {
                let icon = NSWorkspace.shared.icon(forFile: appPath)
                return icon
            }
        }
        
        return nil
    }
}
