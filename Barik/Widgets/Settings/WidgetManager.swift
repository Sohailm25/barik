import SwiftUI

class WidgetManager: ObservableObject {
    @Published var menuBarWidgets: [WidgetItem]
    @Published var settingsPopupWidgets: [WidgetItem]
    @Published var draggingWidgetID: UUID? = nil

    init() {
        menuBarWidgets = [
            WidgetItem(type: .settings),
            WidgetItem(type: .network),
            WidgetItem(type: .battery)
        ]
        settingsPopupWidgets = [
            WidgetItem(type: .time)
        ]
    }
    
    func view(for widget: WidgetItem) -> some View {
        switch widget.type {
        case .settings:
            return AnyView(SettingsWidget())
        case .network:
            return AnyView(NetworkWidget())
        case .battery:
            return AnyView(BatteryWidget())
        case .time:
            return AnyView(TimeWidget())
        }
    }
}

let sharedWidgetManager = WidgetManager()
