import EventKit
import SwiftUI

struct BatteryPopup: View {
    @ObservedObject var configProvider: ConfigProvider
    @State private var selectedVariant: MenuBarPopupVariant = .horizontal

    var body: some View {
        MenuBarPopupVariantView(
            selectedVariant: selectedVariant,
            onVariantSelected: { variant in
                selectedVariant = variant
                ConfigManager.shared.updateConfigValue(
                    key: "widgets.default.battery.popup.view-variant",
                    newValue: variant.rawValue
                )
            },
            vertical: { BatteryPopupVertical() },
            horizontal: { BatteryPopupHorizontal() }
        )
        .onAppear(perform: loadVariant)
        .onReceive(configProvider.$config, perform: updateVariant)
    }

    private func loadVariant() {
        if let variantString = configProvider.config["popup"]?.dictionaryValue?["view-variant"]?
            .stringValue,
            let variant = MenuBarPopupVariant(rawValue: variantString)
        {
            selectedVariant = variant
        } else {
            selectedVariant = .horizontal
        }
    }

    private func updateVariant(newConfig: ConfigData) {
        if let variantString = newConfig["popup"]?.dictionaryValue?["view-variant"]?.stringValue,
            let variant = MenuBarPopupVariant(rawValue: variantString)
        {
            selectedVariant = variant
        }
    }
}

struct BatteryPopupVertical: View {
    private var batteryManager = BatteryManager.shared

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4.5)
                Circle()
                    .trim(from: 0, to: CGFloat(batteryManager.batteryLevel) / 100)
                    .stroke(
                        batteryColor,
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                    )
                    .rotationEffect(Angle(degrees: -90))
                    .animation(
                        .easeOut(duration: 0.5), value: batteryManager.batteryLevel)
                Image(systemName: "laptopcomputer")
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .foregroundColor(.white)
                if batteryManager.isPluggedIn {
                    Image(
                        systemName: batteryManager.isCharging
                            ? "bolt.fill" : "powerplug.portrait.fill"
                    )
                    .foregroundColor(.white)
                    .offset(y: -24)
                    .shadow(color: Color.black, radius: 2, x: 0, y: 0)
                    .shadow(color: Color.black, radius: 2, x: 0, y: 0)
                    .transition(.blurReplace)
                }
            }
            .frame(width: 50, height: 50)
            .padding(.trailing, 10)
            VStack(alignment: .leading) {
                Text("MacBook Air")
                    .font(.title3)
                    .fontWeight(.medium)
                Text("\(batteryManager.batteryLevel)%")
                    .font(.callout)
            }
        }
        .padding(30)
    }

    private var batteryColor: Color {
        if batteryManager.isCharging {
            return .green
        } else {
            if batteryManager.batteryLevel <= 10 {
                return .red
            } else if batteryManager.batteryLevel <= 20 {
                return .yellow
            } else {
                return .white
            }
        }
    }
}

struct BatteryPopupHorizontal: View {
    private var batteryManager = BatteryManager.shared

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(batteryManager.batteryLevel) / 100)
                .stroke(
                    batteryColor,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(Angle(degrees: -90))
                .animation(
                    .easeOut(duration: 0.5), value: batteryManager.batteryLevel)
            Image(systemName: "laptopcomputer")
                .resizable()
                .scaledToFit()
                .padding(14)
                .foregroundColor(.white)
            if batteryManager.isPluggedIn {
                Image(
                    systemName: batteryManager.isCharging
                        ? "bolt.fill" : "powerplug.portrait.fill"
                )
                .foregroundColor(.white)
                .offset(y: -30)
                .shadow(color: Color.black, radius: 2, x: 0, y: 0)
                .shadow(color: Color.black, radius: 2, x: 0, y: 0)
                .transition(.blurReplace)
            }
        }
        .frame(width: 60, height: 60)
        .padding(30)
    }

    private var batteryColor: Color {
        if batteryManager.isCharging {
            return .green
        } else {
            if batteryManager.batteryLevel <= 10 {
                return .red
            } else if batteryManager.batteryLevel <= 20 {
                return .yellow
            } else {
                return .white
            }
        }
    }
}

struct BatteryPopup_Previews: PreviewProvider {
    static var previews: some View {
        BatteryPopupVertical()
            .background(Color.black)
            .previewLayout(.sizeThatFits)
            .environmentObject(ConfigProvider(config: ConfigData()))
        BatteryPopupHorizontal()
            .background(Color.black)
            .previewLayout(.sizeThatFits)
            .environmentObject(ConfigProvider(config: ConfigData()))
    }
}
