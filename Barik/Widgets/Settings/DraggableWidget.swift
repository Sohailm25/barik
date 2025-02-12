import SwiftUI
import UniformTypeIdentifiers

enum ContainerType {
    case menuBar, settingsPopup
}

struct DraggableWidget: View {
    let widget: WidgetItem
    @ObservedObject var manager: WidgetManager
    let container: ContainerType
    @Binding var items: [WidgetItem]
    
    var body: some View {
        manager.view(for: widget)
            .opacity(manager.draggingWidgetID == widget.id ? 0.0 : 1.0)
            .onDrag {
                manager.draggingWidgetID = widget.id
                return NSItemProvider(object: widget.id.uuidString as NSString)
            }
            .onDrop(
                of: [UTType.plainText],
                delegate: WidgetDropDelegate(item: widget, items: $items, manager: manager)
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        manager.draggingWidgetID = nil
                    }
            )
    }
}
