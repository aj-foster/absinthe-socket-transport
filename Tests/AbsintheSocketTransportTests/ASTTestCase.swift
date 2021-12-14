import XCTest

infix operator =~ : ComparisonPrecedence

func =~(lhs: [String: Any], rhs: [String: Any]) -> Bool {
  let subset = lhs.filter({ rhs.keys.contains($0.key)})
  return NSDictionary(dictionary: subset).isEqual(to: rhs)
}

func =~(lhs: [Any?], rhs: [Any?]) -> Bool {
  for (index, el) in rhs.enumerated() {
    if el != nil {
      let a = lhs[index]
      let b = rhs[index]
      guard a is AnyHashable else { return false }
      guard b is AnyHashable else { return false }
      if (a as! AnyHashable) != (b as! AnyHashable) { return false }
    }
  }
  return true
}

class ASTTestCase: XCTestCase {
  static var mockServer: MockServer!
  var mockServer: MockServer!

  func assertConnectionOpen(timeout: Double = 5, action: () -> Void) {
    XCTAssert(
      mockServer.waitForConnectionOpen(timeout: timeout, action: action) == .success,
      "No new connections occurred within \(timeout) seconds"
    )
  }

  func assertConnectionClose(timeout: Double = 5, action: () -> Void) {
    XCTAssert(
      mockServer.waitForConnectionClose(timeout: timeout, action: action) == .success,
      "No closed connections occurred within \(timeout) seconds"
    )
  }

  func assertConnected() {
    XCTAssertTrue(
      mockServer.hasConnection(),
      "Expected the server to have an active connection"
    )
  }

  func assertDisconnected() {
    XCTAssertFalse(
      mockServer.hasConnection(),
      "Expected the server not to have an active connection"
    )
  }

  func assertReceiveMessage(
    timeout: Double = 5,
    action: () -> Void,
    test: ((_ message: [Any]) -> Bool)? = nil
  ) {
    if let test = test {
      XCTAssert(
        mockServer.waitForMessage(action: action, test: test) == .success,
        "No message matching the given specification within \(timeout) seconds"
      )
    } else {
      XCTAssert(
        mockServer.waitForMessage(action: action, test: { message in true }) == .success,
        "No message within \(timeout) seconds"
      )
    }
  }
}
