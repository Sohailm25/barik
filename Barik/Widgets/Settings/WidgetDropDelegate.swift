import SwiftUI
import UniformTypeIdentifiers

struct WidgetDropDelegate: DropDelegate {
    let item: WidgetItem
    @Binding var items: [WidgetItem]
    let manager: WidgetManager

    func dropEntered(info: DropInfo) {
        guard let provider = info.itemProviders(for: [UTType.plainText]).first else { return }
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
            DispatchQueue.main.async {
                var draggedID: String?
                if let data = data as? Data, let str = String(data: data, encoding: .utf8) {
                    draggedID = str
                } else if let str = data as? String {
                    draggedID = str
                }
                if let draggedID = draggedID,
                   let fromWidget = items.first(where: { $0.id.uuidString == draggedID }),
                   fromWidget != item,
                   let fromIndex = items.firstIndex(of: fromWidget),
                   let toIndex = items.firstIndex(of: item) {
                    withAnimation {
                        items.move(fromOffsets: IndexSet(integer: fromIndex),
                                   toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                    }
                }
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        manager.draggingWidgetID = nil
        return true
    }
}
