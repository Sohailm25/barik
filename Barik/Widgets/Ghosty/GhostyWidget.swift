// ABOUTME: Menu bar widget for the Ghosty assistant showing a sparkles icon.
// ABOUTME: Taps toggle the Ghosty popup; also responds to Ctrl+Space hotkey notification.

import SwiftUI

struct GhostyWidget: View {
    @StateObject private var manager = GhostyManager.shared
    @State private var rect: CGRect = .zero

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
            Circle()
                .fill(connectionDotColor)
                .frame(width: 6, height: 6)
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { rect = geometry.frame(in: .global) }
                    .onChange(of: geometry.frame(in: .global)) { _, newValue in
                        rect = newValue
                    }
            }
        )
        .contentShape(Rectangle())
        .experimentalConfiguration(cornerRadius: 15)
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.001))
        .onTapGesture {
            showPopup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleGhostyPanel)) { _ in
            showPopup()
        }
    }

    private var connectionDotColor: Color {
        switch manager.connectionState {
        case .connected:
            return .green
        case .connecting, .tunnelConnecting, .tunnelConnected:
            return .orange
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }

    private func showPopup() {
        NSApp.activate(ignoringOtherApps: true)
        MenuBarPopup.show(rect: rect, id: "ghosty") {
            GhostyPopup(manager: manager)
        }
    }
}
