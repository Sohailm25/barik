import SwiftUI

struct SettingsWidget: View {
    @State private var rect: CGRect = CGRect()

    var body: some View {
        ZStack {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 15))

        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        rect = geometry.frame(in: .global)
                    }
                    .onChange(of: geometry.frame(in: .global)) {
                        oldState, newState in
                        rect = newState
                    }
            }
        )
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "settings") {
                SettingsPopup(manager: sharedWidgetManager)
            }
        }
        .foregroundStyle(.foregroundOutside)
    }
}

struct SettingsWidget_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            SettingsWidget()
        }.frame(width: 200, height: 100)
    }
}
