import SwiftUI

struct MenuBarPopupView<Content: View>: View {
    let content: Content
    let isPreview: Bool

    @ObservedObject var configManager = ConfigManager.shared
    var foregroundHeight: CGFloat {
        configManager.config.experimental.foreground.resolveHeight()
    }

    @State private var contentHeight: CGFloat = 0
    @State private var viewFrame: CGRect = .zero
    @State private var animationValue: Double = 0.01
    @State private var scaleYAnimationValue: Double = 0.01
    @State private var isShowAnimation = false
    @State private var isHideAnimation = false
    @State private var isResizeAnimation = false

    private let willShowWindow = NotificationCenter.default.publisher(
        for: .willShowWindow)
    private let willHideWindow = NotificationCenter.default.publisher(
        for: .willHideWindow)
    private let willResizeWindow = NotificationCenter.default.publisher(
        for: .willResizeWindow)
    private let willChangeContent = NotificationCenter.default.publisher(
        for: .willChangeContent)

    init(isPreview: Bool = false, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.isPreview = isPreview
        if isPreview {
            _animationValue = State(initialValue: 1.0)
        }
    }

    var body: some View {
        let cornerRadiusValue = ((1.0 - animationValue) * 1) + 40
        let blurRadiusValue = (1.0 - (0.1 + 0.9 * animationValue)) * 20
        let scaleXValue = 0.2 + 0.8 * animationValue
        
        return ZStack(alignment: .topTrailing) {
            content
                .background(
                    ZStack {
                        VisualEffectBlur(material: .menu, blendingMode: .behindWindow)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadiusValue, style: .continuous))
                        Color.backgroundPopup
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadiusValue, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadiusValue, style: .continuous)
                        .stroke(GlassGradient.gradient, lineWidth: 1)
                )
                .padding(.top, foregroundHeight + 5)
                .offset(x: computedOffset, y: computedYOffset)
                .shadow(color: .popupShadow, radius: 30)
                .blur(radius: blurRadiusValue)
                .scaleEffect(x: scaleXValue)
                .scaleEffect(y: scaleYAnimationValue)
                .opacity(animationValue)
                .transaction { transaction in
                    if isHideAnimation {
                        transaction.animation = .linear(duration: 0.1)
                    }
                }
                .onReceive(willShowWindow) { _ in
                    guard !isShowAnimation else { return }
                    isShowAnimation = true
                    withAnimation(
                        .smooth(
                            duration: Double(
                                Constants
                                    .menuBarPopupAnimationDurationInMilliseconds
                            ) / 1000.0, extraBounce: 0.3)
                    ) {
                        animationValue = 1.0
                    }
                    withAnimation(
                        .smooth(
                            duration: Double(
                                Constants
                                    .menuBarPopupAnimationDurationInMilliseconds
                            ) / 1000.0, extraBounce: 0.38)
                    ) {
                        scaleYAnimationValue = 1.0
                    }
                    DispatchQueue.main.asyncAfter(
                        deadline: .now()
                            + .milliseconds(
                                Constants
                                    .menuBarPopupAnimationDurationInMilliseconds
                            ) + 0.1
                    ) {
                        isShowAnimation = false
                    }
                }
                .onReceive(willHideWindow) { _ in
                    guard !isHideAnimation else { return }
                    isHideAnimation = true
                    withAnimation(
                        .interactiveSpring(
                            duration: Double(
                                Constants
                                    .menuBarPopupAnimationDurationInMilliseconds
                            ) / 1000.0)
                    ) {
                        animationValue = 0.01
                        scaleYAnimationValue = 0.01
                    }
                    DispatchQueue.main.asyncAfter(
                        deadline: .now()
                            + .milliseconds(
                                Constants
                                    .menuBarPopupAnimationDurationInMilliseconds
                            )
                    ) {
                        isHideAnimation = false
                    }
                }
                .onReceive(willChangeContent) { _ in
                    guard !isHideAnimation else { return }
                    
                    isHideAnimation = true
                    withAnimation(
                        .spring(
                            duration: Double(
                                Constants
                                    .menuBarPopupAnimationDurationInMilliseconds
                            ) / 1000.0)
                    ) {
                        animationValue = 0.01
                        scaleYAnimationValue = 0.01
                    }
                    DispatchQueue.main.asyncAfter(
                        deadline: .now()
                            + .milliseconds(
                                Constants
                                    .menuBarPopupAnimationDurationInMilliseconds
                            )
                    ) {
                        isHideAnimation = false
                    }
                }
                .onReceive(willResizeWindow) { _ in
                    guard !isResizeAnimation else { return }
                    isResizeAnimation = true
                    
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + 0.5
                    ) {
                        isResizeAnimation = false
                    }
                }
                        .animation(
                            .smooth(duration: 0.3),
                            value: isResizeAnimation ? computedOffset : 0
                        )
                        .animation(
                            .smooth(duration: 0.3),
                            value: isResizeAnimation ? computedYOffset : 0)
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        DispatchQueue.main.async {
                            viewFrame = geometry.frame(in: .global)
                            contentHeight = geometry.size.height
                        }
                    }
                    .onChange(of: geometry.size) { _, __ in
                        viewFrame = geometry.frame(in: .global)
                        contentHeight = geometry.size.height
                    }
            }
        )
        .foregroundStyle(.foregroundPopup)
        .buttonStyle(DefaultButtonStyle())
    }

    var computedOffset: CGFloat {
        let screenWidth = NSScreen.main?.frame.width ?? 0
        let W = viewFrame.width
        let M = viewFrame.midX
        let newLeft = (M - W / 2) - 20
        let newRight = (M + W / 2) + 20

        if newRight > screenWidth {
            return screenWidth - newRight
        } else if newLeft < 0 {
            return -newLeft
        }
        return 0
    }

    var computedYOffset: CGFloat {
        return viewFrame.height / 2
    }
}

extension Notification.Name {
    static let willShowWindow = Notification.Name("willShowWindow")
    static let willHideWindow = Notification.Name("willHideWindow")
    static let willResizeWindow = Notification.Name("willResizeWindow")
    static let willChangeContent = Notification.Name("willChangeContent")
}
