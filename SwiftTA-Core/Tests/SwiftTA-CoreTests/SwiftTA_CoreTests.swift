import XCTest
@testable import SwiftTA_Core

final class SwiftTA_CoreTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(SwiftTA_Core().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
