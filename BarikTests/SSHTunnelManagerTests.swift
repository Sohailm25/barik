// ABOUTME: Tests for SSH tunnel state transitions, command construction, and reconnect logic.
// ABOUTME: Tests config-available aspects now; SSHTunnelManager tests commented until service exists.

import XCTest
@testable import Barik

final class SSHTunnelManagerTests: XCTestCase {

    func testDefaultTunnelConfigValues() {
        let config = GhostyConfig.TunnelConfig()
        XCTAssertEqual(config.host, "100.97.157.103")
        XCTAssertEqual(config.user, "sohailmohammad")
        XCTAssertEqual(config.port, 22)
        XCTAssertEqual(config.remotePort, 18789)
        XCTAssertEqual(config.localPort, 18789)
    }

    func testReconnectBackoffCalculation() {
        let gateway = GhostyConfig.GatewayConfig()
        let base = gateway.reconnectBaseDelay
        let maxDelay = gateway.reconnectMaxDelay

        let delay1 = min(base * pow(2.0, 0), maxDelay)
        let delay2 = min(base * pow(2.0, 1), maxDelay)
        let delay3 = min(base * pow(2.0, 2), maxDelay)
        let delay6 = min(base * pow(2.0, 5), maxDelay)

        XCTAssertEqual(delay1, 1.0, accuracy: 0.01)
        XCTAssertEqual(delay2, 2.0, accuracy: 0.01)
        XCTAssertEqual(delay3, 4.0, accuracy: 0.01)
        XCTAssertEqual(delay6, 30.0, accuracy: 0.01, "Should cap at maxDelay")
    }

    func testMaxReconnectAttemptsRespected() {
        let gateway = GhostyConfig.GatewayConfig()
        XCTAssertEqual(gateway.reconnectMaxAttempts, 10)

        var attemptCount = 0
        for attempt in 0..<20 {
            if attempt >= gateway.reconnectMaxAttempts {
                break
            }
            attemptCount += 1
        }
        XCTAssertEqual(attemptCount, 10)
    }

    func testSSHCommandConstruction() {
        let config = GhostyConfig.TunnelConfig()
        let expectedCommand = "ssh -N -L \(config.localPort):127.0.0.1:\(config.remotePort) \(config.user)@\(config.host) -p \(config.port)"
        XCTAssertEqual(
            expectedCommand,
            "ssh -N -L 18789:127.0.0.1:18789 sohailmohammad@100.97.157.103 -p 22"
        )
    }

    // TODO: Uncomment when SSHTunnelManager is implemented
    //
    // func testTunnelStateTransitions() {
    //     // Verify TunnelState enum has expected cases
    //     let disconnected = TunnelState.disconnected
    //     let connecting = TunnelState.connecting
    //     let connected = TunnelState.connected
    //     let error = TunnelState.error("connection refused")
    //
    //     XCTAssertNotEqual(disconnected, connecting)
    //     XCTAssertNotEqual(connected, error)
    // }
    //
    // func testTunnelStateIsEquatable() {
    //     XCTAssertEqual(TunnelState.disconnected, TunnelState.disconnected)
    //     XCTAssertEqual(TunnelState.connected, TunnelState.connected)
    //     XCTAssertEqual(TunnelState.error("a"), TunnelState.error("a"))
    //     XCTAssertNotEqual(TunnelState.error("a"), TunnelState.error("b"))
    //     XCTAssertNotEqual(TunnelState.connected, TunnelState.disconnected)
    // }
}
