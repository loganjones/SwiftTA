import XCTest
@testable import SwiftTA_Ctypes

final class SwiftTA_CtypesTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(TA_HPI_MARKER, 0x49504148)
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
