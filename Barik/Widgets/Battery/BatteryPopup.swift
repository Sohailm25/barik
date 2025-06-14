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
            BatteryCircleView(
                size: 50,
                lineWidth: 4.5,
                iconPadding: 10,
                plugIconOffset: CGSize(width: 0, height: -24)
            )
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
}

struct BatteryPopupHorizontal: View {
    var body: some View {
        BatteryCircleView(
            size: 60,
            lineWidth: 6,
            iconPadding: 14,
            plugIconOffset: CGSize(width: 0, height: -30)
        )
        .padding(30)
    }
}

fileprivate struct BatteryCircleView: View {
    let size: CGFloat
    let lineWidth: CGFloat
    let iconPadding: CGFloat
    let plugIconOffset: CGSize
    
    private var batteryManager = BatteryManager.shared
    
    init(size: CGFloat, lineWidth: CGFloat, iconPadding: CGFloat, plugIconOffset: CGSize) {
        self.size = size
        self.lineWidth = lineWidth
        self.iconPadding = iconPadding
        self.plugIconOffset = plugIconOffset
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(batteryManager.batteryLevel) / 100)
                .stroke(
                    batteryColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(Angle(degrees: -90))
                .animation(
                    .easeOut(duration: 0.5), value: batteryManager.batteryLevel)
            Image(systemName: "laptopcomputer")
                .resizable()
                .scaledToFit()
                .padding(iconPadding)
            if batteryManager.isPluggedIn {
                Image(
                    systemName: batteryManager.isCharging
                        ? "bolt.fill" : "powerplug.portrait.fill"
                )
                .offset(plugIconOffset)
                .shadow(color: .foregroundPopupInverted.opacity(0.8), radius: 2, x: 0, y: 0)
                .shadow(color: .foregroundPopupInverted.opacity(0.8), radius: 2, x: 0, y: 0)
                .foregroundColor(.foregroundPopup)
                .transition(.blurReplace)
            }
        }
        .frame(width: size, height: size)
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
                return .foregroundPopup
            }
        }
    }
}

struct BatteryPopup_Previews: PreviewProvider {
    static var previews: some View {
        BatteryPopupVertical()
            .previewLayout(.sizeThatFits)
            .environmentObject(ConfigProvider(config: ConfigData()))
        BatteryPopupHorizontal()
            .previewLayout(.sizeThatFits)
            .environmentObject(ConfigProvider(config: ConfigData()))
    }
}
