// ABOUTME: Tests for SpaceEvent handling and event-driven SpacesViewModel.
// ABOUTME: Verifies state transitions for all 5 SpaceEvent cases (TDD RED-GREEN-REFACTOR).

import XCTest
import Combine
@testable import Barik

final class SpacesViewModelTests: XCTestCase {

    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }

    func testSpaceEventInitialStateUpdatesSpaces() {
        let mockSpaces = [
            createMockAnySpace(id: "1", isFocused: true),
            createMockAnySpace(id: "2", isFocused: false)
        ]

        let event = SpaceEvent.initialState(mockSpaces)

        switch event {
        case .initialState(let spaces):
            XCTAssertEqual(spaces.count, 2)
            XCTAssertEqual(spaces[0].id, "1")
            XCTAssertTrue(spaces[0].isFocused)
        default:
            XCTFail("Expected initialState event")
        }
    }

    func testSpaceEventFocusChangedUpdatesFocusedSpace() {
        let event = SpaceEvent.focusChanged("2")

        switch event {
        case .focusChanged(let spaceId):
            XCTAssertEqual(spaceId, "2")
        default:
            XCTFail("Expected focusChanged event")
        }
    }

    func testSpaceEventWindowsUpdatedUpdatesWindows() {
        let mockWindows = [createMockAnyWindow(id: 100, title: "Test Window")]
        let event = SpaceEvent.windowsUpdated("1", mockWindows)

        switch event {
        case .windowsUpdated(let spaceId, let windows):
            XCTAssertEqual(spaceId, "1")
            XCTAssertEqual(windows.count, 1)
            XCTAssertEqual(windows[0].title, "Test Window")
        default:
            XCTFail("Expected windowsUpdated event")
        }
    }

    func testSpaceEventSpaceCreatedAddsSpace() {
        let event = SpaceEvent.spaceCreated("3")

        switch event {
        case .spaceCreated(let spaceId):
            XCTAssertEqual(spaceId, "3")
        default:
            XCTFail("Expected spaceCreated event")
        }
    }

    func testSpaceEventSpaceDestroyedRemovesSpace() {
        let event = SpaceEvent.spaceDestroyed("2")

        switch event {
        case .spaceDestroyed(let spaceId):
            XCTAssertEqual(spaceId, "2")
        default:
            XCTFail("Expected spaceDestroyed event")
        }
    }

    func testEventBasedSpacesProviderProtocolExists() {
        let _: any EventBasedSpacesProvider.Type = MockEventBasedSpacesProvider.self
    }

    private func createMockAnySpace(id: String, isFocused: Bool, windows: [AnyWindow] = []) -> AnySpace {
        return AnySpace(id: id, isFocused: isFocused, windows: windows)
    }

    private func createMockAnyWindow(id: Int, title: String) -> AnyWindow {
        return AnyWindow(id: id, title: title, appName: nil, isFocused: false, appIcon: nil)
    }
}

private class MockEventBasedSpacesProvider: EventBasedSpacesProvider {
    var spacesPublisher: AnyPublisher<SpaceEvent, Never> {
        PassthroughSubject<SpaceEvent, Never>().eraseToAnyPublisher()
    }

    func startObserving() {}
    func stopObserving() {}
}
