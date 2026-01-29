// ABOUTME: Central orchestrator for the Ghosty assistant, managing tunnel, gateway, and chat session.
// ABOUTME: Singleton that owns SSHTunnelManager, GatewayConnection, and GhostySession lifecycle.

import Foundation
import Combine
import SwiftUI

class GhostyManager: ObservableObject {
    static let shared = GhostyManager()

    @Published var connectionState: ConnectionState = .disconnected
    @Published var session = GhostySession()
    @Published var reconnectAttempt: Int = 0

    private var tunnelManager: SSHTunnelManager?
    private var gateway: GatewayConnection?
    private var messageQueue: [String] = []
    private var cancellables = Set<AnyCancellable>()

    private var config: GhostyConfig {
        ConfigManager.shared.config.ghosty
    }

    private init() {}

    init(gateway: GatewayConnection?) {
        self.gateway = gateway
    }

    // MARK: - Connection

    func startConnection() {
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .tunnelConnecting
        }

        let tunnel = SSHTunnelManager(config: config.tunnel, gatewayConfig: config.gateway)
        self.tunnelManager = tunnel

        tunnel.$tunnelState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleTunnelStateChange(state)
            }
            .store(in: &cancellables)

        tunnel.startTunnel()
    }

    private func handleTunnelStateChange(_ state: SSHTunnelManager.TunnelState) {
        switch state {
        case .disconnected:
            break
        case .connecting:
            DispatchQueue.main.async { [weak self] in
                self?.connectionState = .tunnelConnecting
            }
        case .connected:
            DispatchQueue.main.async { [weak self] in
                self?.connectionState = .tunnelConnected
            }
            if gateway == nil || !gateway!.isConnected {
                connectGateway()
            }
        case .failed(let message):
            DispatchQueue.main.async { [weak self] in
                self?.reconnectAttempt += 1
                self?.connectionState = .error(message)
            }
        }
    }

    private func connectGateway() {
        gateway?.disconnect()
        let gw = GatewayConnection(port: config.tunnel.localPort, config: config.gateway)
        self.gateway = gw

        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .connecting
        }

        gw.onChatEvent = { [weak self] event in
            self?.handleChatEvent(event)
        }

        gw.onConnectionChanged = { [weak self] connected in
            DispatchQueue.main.async { [weak self] in
                if connected {
                    self?.connectionState = .connected
                    self?.reconnectAttempt = 0
                } else {
                    self?.connectionState = .error("Gateway disconnected")
                    if self?.session.isStreaming == true {
                        if let lastIndex = self?.lastAssistantMessageIndex() {
                            self?.session.messages[lastIndex].state = .error("Connection interrupted")
                        }
                        self?.session.activeRunId = nil
                    }
                }
            }
        }

        gw.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                if connected {
                    self?.connectionState = .connected
                }
            }
            .store(in: &cancellables)

        gw.connect()
    }

    // MARK: - Send Message

    func sendMessage(_ text: String, withScreenshot: Bool = false) {
        if session.isStreaming {
            messageQueue.append(text)
            return
        }

        let userMessage = ChatMessage(role: .user, content: text, state: .sending, hasScreenshot: withScreenshot)
        DispatchQueue.main.async { [weak self] in
            self?.session.messages.append(userMessage)
        }

        var attachments: [ChatAttachment]? = nil
        if withScreenshot {
            if let base64 = ScreenCaptureService.captureAsBase64() {
                attachments = [ChatAttachment(
                    type: "screenshot",
                    mimeType: "image/jpeg",
                    fileName: "screen-capture.jpg",
                    content: base64
                )]
            }
        }

        let params = ChatSendParams(
            sessionKey: session.sessionKey,
            message: text,
            attachments: attachments,
            idempotencyKey: UUID().uuidString
        )

        guard let gateway = self.gateway else {
            DispatchQueue.main.async { [weak self] in
                self?.markLastUserMessageError("No gateway connection")
            }
            return
        }

        gateway.send(method: "chat.send", params: params) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    if response.ok {
                        self.markLastUserMessageComplete()
                        let assistantMessage = ChatMessage(
                            role: .assistant,
                            content: "",
                            state: .streaming
                        )
                        self.session.messages.append(assistantMessage)
                        self.session.activeRunId = response.id
                    } else {
                        let errorMsg = response.error?.message ?? "Request failed"
                        self.markLastUserMessageError(errorMsg)
                    }
                case .failure(let error):
                    self.markLastUserMessageError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Chat Event Handling

    func handleChatEvent(_ event: ChatEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let lastIdx = self.lastAssistantMessageIndex()

            switch event.state {
            case "delta":
                if let lastIndex = lastIdx {
                    let text = self.extractTextFromMessage(event.message)
                    // Gateway sends cumulative text in each delta, not incremental
                    self.session.messages[lastIndex].content = text
                }

            case "final":
                if let lastIndex = lastIdx {
                    let text = self.extractTextFromMessage(event.message)
                    if !text.isEmpty {
                        self.session.messages[lastIndex].content = text
                    }
                    self.session.messages[lastIndex].state = .complete
                }
                self.session.activeRunId = nil
                self.processMessageQueue()

            case "aborted":
                if let lastIndex = lastIdx {
                    self.session.messages[lastIndex].state = .complete
                }
                self.session.activeRunId = nil
                self.processMessageQueue()

            case "error":
                if let lastIndex = lastIdx {
                    let errorMsg = event.errorMessage ?? "Unknown error"
                    self.session.messages[lastIndex].state = .error(errorMsg)
                }
                self.session.activeRunId = nil
                self.processMessageQueue()

            default:
                break
            }
        }
    }

    private func extractTextFromMessage(_ message: ChatEventMessage?) -> String {
        guard let message = message else { return "" }
        guard let content = message.content else { return "" }
        return content.compactMap { block in
            block.type == "text" ? block.text : nil
        }.joined()
    }

    func abortCurrentStream(runId: String) {
        let params = ChatAbortParams(sessionKey: session.sessionKey, runId: runId)
        gateway?.send(method: "chat.abort", params: params) { _ in }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let lastIndex = self.lastAssistantMessageIndex() {
                self.session.messages[lastIndex].state = .complete
            }
            self.session.activeRunId = nil
        }
    }

    // MARK: - Panel

    func dismissPanel() {
        NotificationCenter.default.post(name: .willHideWindow, object: nil)
    }

    // MARK: - Helpers

    private func lastAssistantMessageIndex() -> Int? {
        return session.messages.lastIndex(where: { $0.role == .assistant })
    }

    private func markLastUserMessageComplete() {
        if let idx = session.messages.lastIndex(where: { $0.role == .user }) {
            session.messages[idx].state = .complete
        }
    }

    private func markLastUserMessageError(_ message: String) {
        if let idx = session.messages.lastIndex(where: { $0.role == .user }) {
            session.messages[idx].state = .error(message)
        }
    }

    private func processMessageQueue() {
        guard !messageQueue.isEmpty else { return }
        let nextMessage = messageQueue.removeFirst()
        sendMessage(nextMessage)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let dismissGhostyPanel = Notification.Name("dismissGhostyPanel")
}
