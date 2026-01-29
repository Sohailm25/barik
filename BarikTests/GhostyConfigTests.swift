// ABOUTME: Tests for GhostyConfig TOML parsing and default values.
// ABOUTME: Verifies tunnel, gateway, and shortcut config decode correctly from TOML.

import XCTest
import TOMLDecoder
@testable import Barik

final class GhostyConfigTests: XCTestCase {

    func testGhostyConfigDefaultValues() {
        let config = GhostyConfig()

        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.shortcut, "ctrl+space")
        XCTAssertEqual(config.tunnel.host, "100.97.157.103")
        XCTAssertEqual(config.tunnel.user, "sohailmohammad")
        XCTAssertEqual(config.tunnel.port, 22)
        XCTAssertEqual(config.tunnel.remotePort, 18789)
        XCTAssertEqual(config.tunnel.localPort, 18789)
        XCTAssertEqual(config.gateway.healthCheckInterval, 15)
        XCTAssertEqual(config.gateway.reconnectMaxAttempts, 10)
        XCTAssertEqual(config.gateway.reconnectBaseDelay, 1.0)
        XCTAssertEqual(config.gateway.reconnectMaxDelay, 30.0)
        XCTAssertNil(config.gateway.password)
    }

    func testGhostyConfigDecodesFromTOML() throws {
        let toml = """
        enabled = false
        shortcut = "cmd+g"

        [tunnel]
        host = "10.0.0.1"
        user = "testuser"
        port = 2222
        remote-port = 9999
        local-port = 8888

        [gateway]
        health-check-interval = 30
        reconnect-max-attempts = 5
        reconnect-base-delay = 2.0
        reconnect-max-delay = 60.0
        password = "secret123"
        """
        let decoder = TOMLDecoder()
        let config = try decoder.decode(GhostyConfig.self, from: toml)

        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.shortcut, "cmd+g")
        XCTAssertEqual(config.tunnel.host, "10.0.0.1")
        XCTAssertEqual(config.tunnel.user, "testuser")
        XCTAssertEqual(config.tunnel.port, 2222)
        XCTAssertEqual(config.tunnel.remotePort, 9999)
        XCTAssertEqual(config.tunnel.localPort, 8888)
        XCTAssertEqual(config.gateway.healthCheckInterval, 30)
        XCTAssertEqual(config.gateway.reconnectMaxAttempts, 5)
        XCTAssertEqual(config.gateway.reconnectBaseDelay, 2.0)
        XCTAssertEqual(config.gateway.reconnectMaxDelay, 60.0)
        XCTAssertEqual(config.gateway.password, "secret123")
    }

    func testGhostyConfigDecodesPartialTOML() throws {
        let toml = """
        enabled = false
        """
        let decoder = TOMLDecoder()
        let config = try decoder.decode(GhostyConfig.self, from: toml)

        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.shortcut, "ctrl+space")
        XCTAssertEqual(config.tunnel.host, "100.97.157.103")
        XCTAssertEqual(config.gateway.reconnectMaxAttempts, 10)
    }

    func testTunnelConfigDefaultHost() {
        let tunnel = GhostyConfig.TunnelConfig()
        XCTAssertEqual(tunnel.host, "100.97.157.103")
    }

    func testGatewayConfigDefaultReconnect() {
        let gateway = GhostyConfig.GatewayConfig()
        XCTAssertEqual(gateway.reconnectMaxAttempts, 10)
        XCTAssertEqual(gateway.reconnectBaseDelay, 1.0)
        XCTAssertEqual(gateway.reconnectMaxDelay, 30.0)
    }

    func testFullRootTomlWithGhostyDecodes() throws {
        let toml = """
        theme = "dark"

        [widgets]
        displayed = ["default.spaces"]

        [ghosty]
        enabled = true
        shortcut = "ctrl+g"

        [ghosty.tunnel]
        host = "192.168.1.1"
        user = "admin"
        port = 22
        remote-port = 18789
        local-port = 18789

        [ghosty.gateway]
        health-check-interval = 20
        reconnect-max-attempts = 3
        reconnect-base-delay = 0.5
        reconnect-max-delay = 15.0
        """
        let decoder = TOMLDecoder()
        let root = try decoder.decode(RootToml.self, from: toml)

        XCTAssertNotNil(root.ghosty)
        XCTAssertTrue(root.ghosty?.enabled ?? false)
        XCTAssertEqual(root.ghosty?.shortcut, "ctrl+g")
        XCTAssertEqual(root.ghosty?.tunnel.host, "192.168.1.1")
        XCTAssertEqual(root.ghosty?.tunnel.user, "admin")
        XCTAssertEqual(root.ghosty?.gateway.healthCheckInterval, 20)
        XCTAssertEqual(root.ghosty?.gateway.reconnectMaxAttempts, 3)
    }
}
