import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SwiftTA_OpenGL3Tests.allTests),
    ]
}
#endif
