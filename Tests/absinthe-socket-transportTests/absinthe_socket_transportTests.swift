import XCTest
@testable import absinthe_socket_transport

final class absinthe_socket_transportTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(absinthe_socket_transport().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
