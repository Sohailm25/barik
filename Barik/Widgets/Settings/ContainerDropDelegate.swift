import SwiftUI
import UniformTypeIdentifiers

struct ContainerDropDelegate: DropDelegate {
    @Binding var items: [WidgetItem]
    let container: ContainerType
    @ObservedObject var manager: WidgetManager

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.plainText]).first else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
            DispatchQueue.main.async {
                var widgetID: String?
                if let data = data as? Data, let str = String(data: data, encoding: .utf8) {
                    widgetID = str
                } else if let str = data as? String {
                    widgetID = str
                }
                if let widgetID = widgetID {
                    let allWidgets = manager.menuBarWidgets + manager.settingsPopupWidgets
                    if let widget = allWidgets.first(where: { $0.id.uuidString == widgetID }) {
                        if !items.contains(widget) {
                            withAnimation {
                                items.append(widget)
                            }
                        }
                        // Remove the widget from the opposite container.
                        if container == .menuBar {
                            manager.settingsPopupWidgets.removeAll { $0.id == widget.id }
                        } else {
                            manager.menuBarWidgets.removeAll { $0.id == widget.id }
                        }
                    }
                }
            }
        }
        return true
    }
}
