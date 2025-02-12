import SwiftUI
import UniformTypeIdentifiers

struct SettingsPopup: View {
    @ObservedObject var manager: WidgetManager
    var body: some View {
        VStack {
            Text("Widgets")
                .font(.title2)
                .fontWeight(.medium)
            ForEach(manager.settingsPopupWidgets) { widget in
                DraggableWidget(widget: widget,
                                manager: manager,
                                container: .settingsPopup,
                                items: $manager.settingsPopupWidgets)
            }
            .onDrop(of: [UTType.plainText],
                    delegate: ContainerDropDelegate(items: $manager.settingsPopupWidgets,
                                                    container: .settingsPopup,
                                                    manager: manager))
        }
        .foregroundColor(.white)
        .padding()
        .frame(width: 400)
    }
}

struct SettingsPopup_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarPopupView (isPreview: true) {
            SettingsPopup(manager: sharedWidgetManager)
        }.frame(height: 500)
    }
}
