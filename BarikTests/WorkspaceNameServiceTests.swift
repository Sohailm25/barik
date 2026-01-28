// ABOUTME: TDD tests for WorkspaceNameService — workspace display name persistence.
// ABOUTME: Tests get/set/remove, JSON persistence, corrupt file recovery, and edge cases.

import XCTest
@testable import Barik

final class WorkspaceNameServiceTests: XCTestCase {

    var testFilePath: String!

    override func setUp() {
        super.setUp()
        testFilePath = NSTemporaryDirectory() + UUID().uuidString + "-workspace-names.json"
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: testFilePath)
        super.tearDown()
    }

    // MARK: - Basic Operations

    func testGetDisplayNameReturnsNilWhenNotSet() {
        let service = WorkspaceNameService(filePath: testFilePath)
        XCTAssertNil(service.getDisplayName(for: "1"))
    }

    func testSetAndGetDisplayName() {
        let service = WorkspaceNameService(filePath: testFilePath)
        service.setDisplayName("Code", for: "1")
        XCTAssertEqual(service.getDisplayName(for: "1"), "Code")
    }

    func testSetMultipleDisplayNames() {
        let service = WorkspaceNameService(filePath: testFilePath)
        service.setDisplayName("Code", for: "1")
        service.setDisplayName("Browser", for: "2")
        service.setDisplayName("Terminal", for: "3")
        XCTAssertEqual(service.getDisplayName(for: "1"), "Code")
        XCTAssertEqual(service.getDisplayName(for: "2"), "Browser")
        XCTAssertEqual(service.getDisplayName(for: "3"), "Terminal")
    }

    func testOverwriteDisplayName() {
        let service = WorkspaceNameService(filePath: testFilePath)
        service.setDisplayName("Code", for: "1")
        service.setDisplayName("Editor", for: "1")
        XCTAssertEqual(service.getDisplayName(for: "1"), "Editor")
    }

    func testRemoveDisplayName() {
        let service = WorkspaceNameService(filePath: testFilePath)
        service.setDisplayName("Code", for: "1")
        service.removeDisplayName(for: "1")
        XCTAssertNil(service.getDisplayName(for: "1"))
    }

    func testRemoveNonExistentNameDoesNotCrash() {
        let service = WorkspaceNameService(filePath: testFilePath)
        service.removeDisplayName(for: "999")
    }

    // MARK: - Persistence

    func testPersistsToDisk() {
        let service1 = WorkspaceNameService(filePath: testFilePath)
        service1.setDisplayName("Code", for: "1")
        service1.setDisplayName("Browser", for: "2")

        let service2 = WorkspaceNameService(filePath: testFilePath)
        XCTAssertEqual(service2.getDisplayName(for: "1"), "Code")
        XCTAssertEqual(service2.getDisplayName(for: "2"), "Browser")
    }

    func testMissingFileCreatesOnWrite() {
        XCTAssertFalse(FileManager.default.fileExists(atPath: testFilePath))

        let service = WorkspaceNameService(filePath: testFilePath)
        service.setDisplayName("Code", for: "1")

        XCTAssertTrue(FileManager.default.fileExists(atPath: testFilePath))
    }

    // MARK: - Edge Cases

    func testEmptyStringNameIsStored() {
        let service = WorkspaceNameService(filePath: testFilePath)
        service.setDisplayName("", for: "1")
        XCTAssertEqual(service.getDisplayName(for: "1"), "")
    }

    func testCorruptedFileRecovery() {
        try! "not valid json {{{".write(toFile: testFilePath, atomically: true, encoding: .utf8)

        let service = WorkspaceNameService(filePath: testFilePath)
        XCTAssertNil(service.getDisplayName(for: "1"))

        service.setDisplayName("Code", for: "1")
        XCTAssertEqual(service.getDisplayName(for: "1"), "Code")
    }

    // MARK: - allDisplayNames

    func testAllDisplayNamesReturnsAll() {
        let service = WorkspaceNameService(filePath: testFilePath)
        service.setDisplayName("Code", for: "1")
        service.setDisplayName("Browser", for: "2")
        let all = service.allDisplayNames()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all["1"], "Code")
        XCTAssertEqual(all["2"], "Browser")
    }

    func testAllDisplayNamesEmptyWhenNoneSet() {
        let service = WorkspaceNameService(filePath: testFilePath)
        let all = service.allDisplayNames()
        XCTAssertTrue(all.isEmpty)
    }
}
