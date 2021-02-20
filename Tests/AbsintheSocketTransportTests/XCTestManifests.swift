import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(absinthe_socket_transportTests.allTests),
    ]
}
#endif
