import SwiftUI

struct MenuBarItemsView: View {
    @StateObject var viewModel = MenuBarViewModel()
    
    var body: some View {
        let menuItems = viewModel.items
        HStack(spacing: 2) {
            ForEach(menuItems.filter { !$0.isSeparator }, id: \.self) { item in
                MenuItemView(
                    index: menuItems.firstIndex(of: item),
                    menuItem: item
                )
                .transition(.opacity)
            }
        }
        .animation(.smooth, value: viewModel.items)
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: 30)
        .buttonStyle(StaticButtonStyle())
    }
}

struct MenuItemView: View {
    let index: Int?
    let menuItem: MenuItem
    
    var body: some View {
        if index == 0 {
            let size: CGFloat = 21
            Menu {
                ForEach(menuItem.children, id: \.self) { child in
                    MenuItemView(index: nil, menuItem: child)
                }
            } label: {
                HStack {
                    if let icon = IconCache.shared.getIcon(for: menuItem.title) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: size, height: size)
                            .shadow(color: .iconShadow, radius: 2)
                    } else {
                        Image(systemName: "questionmark.circle")
                            .resizable()
                            .frame(width: size, height: size)
                    }
                    
                    Text(menuItem.title)
                        .shadow(color: .foregroundShadowOutside, radius: 3)
                        .fontWeight(.bold)
                        .foregroundColor(.foregroundOutside)
                }
            }
            .padding(.trailing, 5)
        } else {
            if menuItem.isSubtitle {
                Text(menuItem.title)
                    .font(.caption)
                    .position(y: 5)
            } else if menuItem.isSeparator {
                Divider()
            } else if menuItem.children.isEmpty {
                Button(action: { performPressAction(for: menuItem) }) {
                    Toggle(isOn: .constant(menuItem.isChecked)) {
                        Text(menuItem.title)
                    }
                }
            } else {
                Menu {
                    ForEach(menuItem.children, id: \.self) { child in
                        MenuItemView(index: nil, menuItem: child)
                    }
                } label: {
                    Text(menuItem.title)
                        .if(menuItem.isRoot) { obj in
                            obj.foregroundColor(.foregroundOutside)
                        }
                        .shadow(color: .foregroundShadowOutside, radius: 3)
                }
                .disabled(!menuItem.isEnabled)
            }
        }
    }
    
    /// Performs the press action for a menu item.
    private func performPressAction(for menuItem: MenuItem) {
        guard let element = menuItem.element else { return }
        let error = AXUIElementPerformAction(element, kAXPressAction as CFString)
        if error != .success {
            print("Error performing action for \(menuItem.title): \(error.rawValue)")
        }
    }
}
