//
//  MockServer.swift
//  
//  Adapted from https://github.com/MichaelNeas/perpetual-learning/blob/b9a155a/ios-sockets/SwiftWebSocketServer/SwiftWebSocketServer/SwiftWebSocketServer.swift
//  Created by Michael Neas on 11/30/19.
//  Copyright © 2019 Neas Lease. All rights reserved.
//

import Foundation
import Network
import os

/**
 * Provides a mock websocket server for testing purposes.
 *
 * Please note that this server assumes that only one connection will be made at a time. Parallel
 * test runs are unsupported.
 */
class MockServer {
  private let server: NWListener
  private let parameters: NWParameters

  init(port: UInt16) {
    let port = NWEndpoint.Port(rawValue: port)!

    parameters = NWParameters(tls: nil)
    parameters.allowLocalEndpointReuse = true
    parameters.includePeerToPeer = true

    let wsOptions = NWProtocolWebSocket.Options()
    wsOptions.autoReplyPing = true
    parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

    server = try! NWListener(using: parameters, on: port)
  }

  //
  // MARK: - Startup
  //

  /* Allow waiting for server startup to finish. */
  private var serverDidStartSemaphore: DispatchSemaphore?;

  /**
   * Start the mock server and block execution until the server is ready.
   */
  func start() {
    print("[MS] Starting Mock Server...")

    server.stateUpdateHandler = self.stateDidChange(to:)
    server.newConnectionHandler = self.connectionDidOpen(nwConnection:)
    server.start(queue: .init(label: "MockServer"))

    serverDidStartSemaphore = DispatchSemaphore(value: 0)
    _ = serverDidStartSemaphore?.wait(wallTimeout: .distantFuture)
    serverDidStartSemaphore = nil
  }

  /* Callback: NWListener.stateUpdateHandler */
  func stateDidChange(to newState: NWListener.State) {
    switch newState {
    case .ready:
      print("[MS] Mock Server Started")
      serverDidStartSemaphore?.signal()
    case .failed(let error):
      print("[MS] Error: Mock Server failed to start")
      print("[MS] Error: \(error.localizedDescription)")
      serverDidStartSemaphore?.signal()
      exit(EXIT_FAILURE)
    default:
      break
    }
  }

  //
  // MARK: - New Connections
  //

  /* Current connection. */
  private var connection: NWConnection? = nil

  /* Allow waiting for new connections. See `waitForConnection`. */
  private var connectionDidOpenSemaphore: DispatchSemaphore?

  /* Callback: NWListener.newConnectionHandler */
  private func connectionDidOpen(nwConnection: NWConnection) {
    os_log("[MS] Connection Open", log: .default, type: .debug)

    connection = nwConnection
    connection?.stateUpdateHandler = connectionStateDidChange(to:)
    setupReceiveMessage()
    connection?.start(queue: .init(label: "MockServerConnection"))

    connectionDidOpenSemaphore?.signal()
  }

  /* Callback: NWConnection.stateUpdateHandler */
  func connectionStateDidChange(to state: NWConnection.State) {
    os_log("[MS] Connection state: %s", log: .default, type: .debug, "\(state)" as CVarArg)

    switch state {
    case .waiting(_), .failed(_):
      connection?.stateUpdateHandler = nil
      connection?.cancel()
      connectionDidClose()

    case .cancelled:
      connection?.stateUpdateHandler = nil
      connectionDidClose()

    default:
      break
    }
  }

  /**
   * Run `action` and block execution until a new connection is made OR `timeout` expires.
   *
   * - Parameter timeout: Maximum time, in seconds, to wait for a new connection. Default 5 seconds.
   * - Parameter action: Code tha should initiate a new connection
   *
   * - Returns: Result indicating whether a new connection was made
   */
  func waitForConnectionOpen(timeout: Double = 5, action: () -> Void) -> DispatchTimeoutResult {
    connectionDidOpenSemaphore = DispatchSemaphore(value: 0)
    action()
    let result = connectionDidOpenSemaphore!.wait(wallTimeout: .now() + timeout)
    connectionDidOpenSemaphore = nil
    return result
  }

  /**
   * Check whether the mock server currently has a connected client.
   *
   * - Returns: `true` if there is an active connection, `false` if not
   */
  func hasConnection() -> Bool {
    return connection != nil
  }

  //
  // MARK: - Receiving Messages
  //

  /* Allow waiting for messages. See `waitForMessage`. */
  private var didReceiveMessageCallback: ((_ data: Data) -> Void)?

  /* Allow waiting for messages. See `waitForMessage`. */
  private var didReceiveMessageSemaphore: DispatchSemaphore?

  /* Recursively accept messages using NWConnection.receiveMessage. */
  private func setupReceiveMessage() {
    connection?.receiveMessage() { (data, context, isComplete, error) in
      if let data = data,
         let context = context,
         !data.isEmpty
      {
        self.handleMessage(data: data, context: context)
      }
      if error != nil {
        self.connection?.stateUpdateHandler = nil
        self.connection?.cancel()
        self.connectionDidClose()
      } else {
        self.setupReceiveMessage()
      }
    }
  }

  /* Pass message data to an active message assertion, if any. */
  private func handleMessage(data: Data, context: NWConnection.ContentContext) {
    didReceiveMessageCallback?(data)
  }

  /**
   * Run `action` and block execution until a message is received OR `timeout` expires.
   *
   * The `test` closure indicates whether a given message meets the criteria for success. We
   * assume that all incoming messages are JSON and decode them as `[String : Any]`.
   *
   * - Parameter timeout: Maximum time, in seconds, to wait for a message. Default 5 seconds.
   * - Parameter action: Code that should cause a matching message to arrive
   * - Parameter test: Indicator of whether a message meets the desired criteria
   *
   * - Returns: Result indicating whether the desired message arrived
   */
  func waitForMessage(
    timeout: Double = 5,
    action: () -> Void,
    test: @escaping (_ message: [Any]) -> Bool
  ) -> DispatchTimeoutResult {
    didReceiveMessageSemaphore = DispatchSemaphore(value: 0)

    didReceiveMessageCallback = { (data: Data) in
      os_log("[MS] Received message: %s", log: .default, type: .debug, String(decoding: data, as: UTF8.self))

      do {
        let message = try JSONSerialization.jsonObject(with: data, options: []) as! [Any]

        if test(message) {
          self.didReceiveMessageSemaphore?.signal()
        }
      } catch {
        os_log("[MS] Invalid message: %s", log: .default, type: .error, String(decoding: data, as: UTF8.self))
      }
    }

    action()
    let result = didReceiveMessageSemaphore!.wait(wallTimeout: .now() + timeout)

    didReceiveMessageSemaphore = nil
    didReceiveMessageCallback = nil

    return result
  }

  //
  // MARK: - Sending Messages
  //

  func send(data: Data) {
    os_log("[MS] Sent message: %s", log: .default, type: .debug, data as NSData)

    let metaData = NWProtocolWebSocket.Metadata(opcode: .binary)
    let context = NWConnection.ContentContext (identifier: "context", metadata: [metaData])
    self.connection?.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed({ error in
      if error != nil { self.close() }
    }))
  }

  //
  // MARK: - Closing Connections
  //

  /* Allow waiting for connection closures. See `waitForConnectionClose`. */
  private var connectionDidCloseSemaphore: DispatchSemaphore?

  private func connectionDidClose() {
    if connection != nil {
      os_log("[MS] Connection Close", log: .default, type: .debug)
    }

    connection = nil
    connectionDidCloseSemaphore?.signal()
  }

  func close() {
    connection?.stateUpdateHandler = nil
    connection?.cancel()
    connectionDidClose()
  }

  /**
   * Run `action` and block execution until the current connection closes OR `timeout` expires.
   *
   * - Parameter timeout: Maximum time, in seconds, to wait for closure. Default 5 seconds.
   * - Parameter action: Code that should initiate a connection closure
   *
   * - Returns: Result indicating whether the connection was closed
   */
  func waitForConnectionClose(timeout: Double = 5, action: () -> Void) -> DispatchTimeoutResult {
    connectionDidCloseSemaphore = DispatchSemaphore(value: 0)
    action()
    let result = connectionDidCloseSemaphore!.wait(wallTimeout: .now() + timeout)
    connectionDidCloseSemaphore = nil
    return result
  }

  /**
   * Stop the mock server and close existing connections.
   */
  func stop() {
    close()

    server.stateUpdateHandler = nil
    server.newConnectionHandler = nil
    server.cancel()
  }
}
