import AppKit
import EventKit
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarView: View {
    @ObservedObject var manager: WidgetManager
    var body: some View {
        ZStack {
            HStack(spacing: 15) {
                Spacer()
                ForEach(manager.menuBarWidgets) { widget in
                    DraggableWidget(widget: widget,
                                    manager: manager,
                                    container: .menuBar,
                                    items: $manager.menuBarWidgets)
                }
            }
            .onDrop(of: [UTType.plainText],
                    delegate: ContainerDropDelegate(items: $manager.menuBarWidgets,
                                                    container: .menuBar,
                                                    manager: manager))
            .shadow(color: .gray, radius: 3)
            .font(.system(size: 16))
        }
        .frame(height: Constants.menuBarHeight)
        .contentShape(Rectangle())
    }
}

//struct MenuBarView_Previews: PreviewProvider {
//    static var previews: some View {
//        MenuBarView().background(.black)
//    }
//}
