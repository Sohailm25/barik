import Foundation
import Cocoa

struct MenuItem: Hashable {
    let isRoot: Bool
    let title: String
    let element: AXUIElement?
    var children: [MenuItem]
    let isSeparator: Bool
    let isEnabled: Bool
    let hotkey: String?
    let isSubtitle: Bool
    let isChecked: Bool
    
    static func == (lhs: MenuItem, rhs: MenuItem) -> Bool {
        return lhs.isRoot == rhs.isRoot &&
        lhs.title == rhs.title &&
        lhs.children == rhs.children &&
        lhs.isSeparator == rhs.isSeparator &&
        lhs.isEnabled == rhs.isEnabled &&
        lhs.hotkey == rhs.hotkey &&
        lhs.isSubtitle == rhs.isSubtitle &&
        lhs.isChecked == rhs.isChecked
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(isRoot)
        hasher.combine(title)
        hasher.combine(children)
        hasher.combine(isSeparator)
        hasher.combine(isEnabled)
        hasher.combine(hotkey)
        hasher.combine(isSubtitle)
        hasher.combine(isChecked)
    }
}

class MenuBarViewModel: ObservableObject {
    @Published var items: [MenuItem] = []
    private var timer: Timer?
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.loadMenu()
        }
        loadMenu()
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func loadMenu() {
        if ConfigManager.shared.config.experimental.appMenu.enabled {
            DispatchQueue.global(qos: .background).async {
                let menuItems = fetchMenuBarHierarchy()
                DispatchQueue.main.async {
                    self.items = menuItems
                }
            }
        }
    }
}

private func formatShortcut(cmd: String?, modifiers: Int, virtualKey: Int) -> String {
    let virtualKeyMappings: [Int: String] = [
        0x24: "↩",
        0x35: "⎋",
        0x31: "␣",
        0x4C: "⌤",
        0x47: "⌧",
        0x30: "⇥",
        0x33: "⌫",
        0x39: "⇪",
        0x3F: "fn",
        0x7A: "F1",
        0x78: "F2",
        0x63: "F3",
        0x76: "F4",
        0x60: "F5",
        0x61: "F6",
        0x62: "F7",
        0x64: "F8",
        0x65: "F9",
        0x6D: "F10",
        0x67: "F11",
        0x6F: "F12",
        0x69: "F13",
        0x6B: "F14",
        0x71: "F15",
        0x6A: "F16",
        0x40: "F17",
        0x4F: "F18",
        0x50: "F19",
        0x5A: "F20",
        0x73: "↖",
        0x74: "⇞",
        0x75: "⌦",
        0x77: "↘",
        0x79: "⇟",
        0x7B: "◀︎",
        0x7C: "▶︎",
        0x7D: "▼",
        0x7E: "▲"
    ]
    
    let emojiMappings = [
        "🎤": "mic",
        "🌐": "globe"
    ]
    
    let modifierSymbols = [
        (key: 0x04, symbol: "⌃", isActive: { modifiers & 0x04 != 0 }),
        (key: 0x02, symbol: "⌥", isActive: { modifiers & 0x02 != 0 }),
        (key: 0x01, symbol: "⇧", isActive: { modifiers & 0x01 != 0 }),
        (key: 0x08, symbol: "⌘", isActive: { modifiers & 0x08 == 0 }),
        (key: 0x10, symbol: "fn", isActive: { modifiers & 0x10 != 0 })
    ]
    
    let parts = modifierSymbols.filter { $0.isActive() }.map { $0.symbol }
    var allParts = parts
    
    if virtualKey > 0, let keySymbol = virtualKeyMappings[virtualKey] {
        allParts.append(keySymbol)
        return allParts.joined()
    }
    
    if let cmd = cmd, !cmd.isEmpty {
        let commandChar = (cmd == "SS") ? "ß" : (emojiMappings[cmd] ?? cmd)
        allParts.append(commandChar)
    }
    
    if allParts == ["⌘"] { return "" }
    return allParts.joined(separator: " ")
}

private func fetchMenuHierarchy(for element: AXUIElement, isRoot: Bool) -> [MenuItem] {
    var items: [MenuItem] = []
    var children: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
    guard result == .success, let childrenArray = children as? [AXUIElement] else {
        return items
    }
    
    for child in childrenArray {
        var titleObj: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleObj)
        let titleStr: String = (titleResult == .success && (titleObj as? String)?.isEmpty == false) ? (titleObj as! String) : ""
        
        var enabledObj: AnyObject?;
        AXUIElementCopyAttributeValue(child, kAXEnabledAttribute as CFString, &enabledObj)
        let isEnabled = enabledObj as? Bool ?? true
        
        var valueObj: AnyObject?
        AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &valueObj)
        let isChecked = String(describing: valueObj).contains("On")
        
        var cmdCharObj: AnyObject?
        AXUIElementCopyAttributeValue(child, kAXMenuItemCmdCharAttribute as CFString, &cmdCharObj)
        let cmdChar = cmdCharObj as? String
        
        var cmdModifiersObj: AnyObject?
        AXUIElementCopyAttributeValue(child, kAXMenuItemCmdModifiersAttribute as CFString, &cmdModifiersObj)
        let cmdModifiers = cmdModifiersObj as? Int ?? 0
        
        var cmdVirtualKeyObj: AnyObject?
        AXUIElementCopyAttributeValue(child, kAXMenuItemCmdVirtualKeyAttribute as CFString, &cmdVirtualKeyObj)
        let cmdVirtualKey = cmdVirtualKeyObj as? Int ?? 0
        
        let hotkey = formatShortcut(cmd: cmdChar, modifiers: cmdModifiers, virtualKey: cmdVirtualKey)
        let subItems = fetchMenuHierarchy(for: child, isRoot: false)
        
        if titleStr.isEmpty {
            let separatorItem = MenuItem(isRoot: false, title: "", element: child, children: [], isSeparator: true, isEnabled: false, hotkey: nil, isSubtitle: false, isChecked: false)
            items.append(separatorItem)
            if !subItems.isEmpty {
                items.append(contentsOf: subItems)
            }
        } else {
            let menuItem = MenuItem(isRoot: isRoot, title: titleStr, element: child, children: subItems, isSeparator: false, isEnabled: isEnabled, hotkey: hotkey, isSubtitle: false, isChecked: isChecked)
            items.append(menuItem)
        }
    }
    
    if isRoot && items.count > 1 {
        items[1].children.removeFirst()
        items[1].children.insert(MenuItem(isRoot: false, title: "Application Menu", element: nil, children: [], isSeparator: false, isEnabled: false, hotkey: "", isSubtitle: true, isChecked: false), at: 0)
        items[1].children.append(MenuItem(isRoot: false, title: "", element: nil, children: [], isSeparator: false, isEnabled: false, hotkey: "", isSubtitle: false, isChecked: false))
        items[1].children.append(MenuItem(isRoot: false, title: "System Menu", element: nil, children: [], isSeparator: false, isEnabled: false, hotkey: "", isSubtitle: true, isChecked: false))
        items[1].children.append(contentsOf: items.first!.children.dropFirst())
        items.removeFirst()
    }
    
    return items
}

private func fetchMenuBarHierarchy() -> [MenuItem] {
    var resultItems: [MenuItem] = []
    let systemWideElement = AXUIElementCreateSystemWide()
    
    var focusedApp: AnyObject?
    let appResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)
    guard appResult == .success, let appObject = focusedApp else {
        print("Failed to get focused application. Code: \(appResult.rawValue)")
        return []
    }
    let appElement = appObject as! AXUIElement
    
    var menuBar: AnyObject?
    let menuBarResult = AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBar)
    guard menuBarResult == .success, let menuBarObject = menuBar else {
        print("Failed to get menu bar for focused app. Code: \(menuBarResult.rawValue)")
        return []
    }
    let menuBarElement = menuBarObject as! AXUIElement
    
    resultItems = fetchMenuHierarchy(for: menuBarElement, isRoot: true)
    return resultItems
}
