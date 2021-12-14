import XCTest
@testable import AbsintheSocketTransport

final class AbsintheSocketTransportTests: ASTTestCase {

  //
  // Lifecycle
  //

  override class func setUp() {
    super.setUp()
    mockServer = MockServer(port: 8123)
    mockServer.start()
  }

  override func setUp() {
    super.setUp()
    mockServer = AbsintheSocketTransportTests.mockServer
  }

  override func tearDown() {
    mockServer.close()
    super.tearDown()
  }

  override class func tearDown() {
    super.tearDown()
    mockServer.stop()
  }

  //
  // Tests: Connect
  //

  func testConnectOnInitByDefault() {
    var transport: AbsintheSocketTransport?

    assertConnectionOpen {
      transport = AbsintheSocketTransport("ws://localhost:8123")
    }

    transport?.disconnect()
  }

  func testConnectOnInitFalse() {
    let transport = AbsintheSocketTransport("ws://localhost:8123", connectOnInit: false)
    assertDisconnected()

    assertConnectionOpen {
      transport.connect()
    }

    transport.disconnect()
  }

  //
  // Tests: Channel
  //

  func testJoinsChannel() {
    let transport = AbsintheSocketTransport("ws://localhost:8123", connectOnInit: false)

    assertReceiveMessage(action: {
      transport.connect()
    }, test: { message in
      message =~ [nil, nil, "__absinthe__:control", "phx_join", nil]
    })

    transport.disconnect()
  }
}
