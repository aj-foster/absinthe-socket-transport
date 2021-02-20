import os
import Apollo
import Foundation
import SwiftPhoenixClient

public class AbsintheSocketTransport {

  //
  // Instance Variables
  //

  // Transports
  private let socket: SwiftPhoenixClient.Socket
  private let channel: SwiftPhoenixClient.Channel
  private var joined: Bool = false

  // Queues and active operations
  private let queue = DispatchQueue(label: "org.absinthe-graphql.AbsintheTransport")
  private var outgoing: [() -> Void] = []
  private var subscriptions: [String: String] = [:]
  private var subscriptionHandlers: [String: (Message) -> Void] = [:]
  private var cancelledSubscriptions: [String] = []

  //
  // Initializers
  //

  /**
   * Mirrors the `SwiftPhoenixClient.Socket` API.
   *
   * - parameter endpoint: URL of the GraphQL websocket endpoint, including a trailing `/websocket`
   * - parameter params: Optional parameters to include with the socket request
   */
  public convenience init (
    _ endpoint: String,
    params: Payload = [:]
  ) {
    self.init(endpoint, closedParams: { return params })
  }

  /**
   * Mirrors the `SwiftPhoenixClient.Socket` API.
   *
   * - parameter endpoint: URL of the GraphQL websocket endpoint, including a trailing `/websocket`
   * - parameter closedParams: Optional closure with parameters to include with the socket request. Use this
   *   to potentially update params prior to reconnections of the socket.
   */
  public init (
    _ endpoint: String,
    closedParams: PayloadClosure = { return [:] }
  ) {
    self.socket = SwiftPhoenixClient.Socket.init(endpoint)
    self.channel = socket.channel(Topics.absinthe)

    self.socket.delegateOnOpen(to: self) { target in target.socketDidConnect() }
    self.socket.delegateOnMessage(to: self) { target, message in target.socketDidReceiveMessage(message) }

    self.socket.connect()
  }

  //
  // Event Handlers: Socket
  //

  private func socketDidConnect() {
    if !self.joined {
      self.joined = true
      self.channel.join()
        .delegateReceive("ok", to: self) { target, message in target.channelDidJoin(message) }
        .delegateReceive("error", to: self) { target, message in target.channelDidError(message) }
        .delegateReceive("timeout", to: self) { target, message in target.channelDidTimeout(message) }
    }
  }

  private func socketDidReceiveMessage(_ message: Message) {
    // Ignore any messages that are not incoming subscription data.
    if message.event != Events.subscription { return }

    // Call registered handlers for the given subscription ID.
    self.subscriptionHandlers[message.topic]?(message)
  }

  //
  // Event Handlers: Channel
  //

  private func channelDidJoin(_ message: Message) {
    self.outgoing.forEach { $0() }
  }

  private func channelDidError(_ message: Message) {
    os_log("Error while joining Absinthe channel: %s", message.payload.description)
  }

  private func channelDidTimeout(_ message: Message) {
    os_log("Error while joining Absinthe channel (timeout): %s", message.payload.description)
  }

  //
  // Operations
  //

  private func createOperation<Operation: GraphQLOperation>(_ op: Operation) -> Payload {
    var payload: Payload
    payload = [ "query": op.queryDocument ]

    if let variables = op.variables {
      payload += [ "variables": variables ]
    }

    return payload
  }

  private func createUnsubscribe(id: String) -> Payload {
    return [ "subscriptionId": id ] // Do we need to strip off __absinthe__:doc:?
  }

  private func parseMessage(_ payload: Payload) -> Result<JSONObject, Error> {
    guard
      let status = payload["status"] as? String,
      let response = payload["response"] as? JSONObject
    else {
      os_log("Error while parsing channel message")
      return .failure(GraphQLError(["message": "Error while parsing response"]))
    }

    switch status {
    case "ok":
      return .success(response)
    default:
      return .failure(GraphQLError(response))
    }
  }

  //
  // Subscriptions
  //

  /**
   * Unsubscribes from the subscription with the given reference.
   *
   * - parameter ref: Channel frame reference for the original subscription request
   */
  public func unsubscribe(_ ref: String) {
    if let id = self.subscriptions[ref] {
      let payload = createUnsubscribe(id: id)
      queue.async {
        self.channel.push(Events.unsubscribe, payload: payload)
        self.subscriptions.removeValue(forKey: ref)
      }
    } else {
      self.cancelledSubscriptions.append(ref)
    }
  }
}

/**
 * Provides a cancellable task for all operations. In particular, we can cancel (unsubscribe) from subscriptions.
 */
class Subscription: Cancellable {
  let ref: String
  let transport: AbsintheSocketTransport

  /**
   * Create a new task for the given operation.
   */
  init(
    _ transport: AbsintheSocketTransport,
    _ ref: String
  ) {
    self.transport = transport
    self.ref = ref
  }

  /**
   * Cancel the subscription. Has no effect on queries and mutations.
   */
  public func cancel() {
    transport.unsubscribe(ref)
  }
}

typealias Outgoing = () -> Void

extension AbsintheSocketTransport: NetworkTransport {
  public func send<Operation>(operation: Operation, cachePolicy: CachePolicy, contextIdentifier: UUID?, callbackQueue: DispatchQueue, completionHandler: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void) -> Cancellable where Operation : GraphQLOperation {
    var cancellable: Cancellable
    var sendOperation: () -> Void

    // Convenience for calling the completion handler.
    func completionAsync(_ result: Result<GraphQLResult<Operation.Data>, Error>) {
      callbackQueue.async {
        completionHandler(result)
      }
    }

    switch operation.operationType {
    case .query,
         .mutation:
      cancellable = EmptyCancellable()

      sendOperation = { [weak self] in
        self?.send(operation: operation, completion: completionAsync)
      }

    case .subscription:
      let id = socket.makeRef()
      cancellable = Subscription(self, id)

      sendOperation = { [weak self] in
        self?.subscribe(operation: operation, subscriptionId: id, completion: completionAsync)
      }
    }

    if self.channel.isJoined {
      sendOperation()
    } else {
      self.outgoing.append(sendOperation)
    }

    return cancellable
  }

  private func send<Operation>(
    operation: Operation,
    completion: @escaping (_ result: Result<GraphQLResult<Operation.Data>, Error>) -> Void
  ) where Operation : GraphQLOperation {
    let payload = createOperation(operation)

    self.channel
      .push(Events.doc, payload: payload)
      .delegateReceive("ok", to: self) { target, message in
        let data = message.payload["response"] as! JSONObject
        let response = GraphQLResponse(operation: operation, body: data)

        do {
          let graphQLResult = try response.parseResultFast()
          completion(.success(graphQLResult))
        } catch {
          let error = AbsintheError(kind: .parseError, payload: data)
          completion(.failure(error))
        }
      }
      .delegateReceive("error", to: self) { target, message in
        let data = message.payload["response"] as! JSONObject
        completion(.failure(AbsintheError(kind: .queryError, payload: data)))
      }
  }

  private func subscribe<Operation>(
    operation: Operation,
    subscriptionId: String,
    completion: @escaping (_ result: Result<GraphQLResult<Operation.Data>, Error>) -> Void
  ) where Operation: GraphQLOperation {
    let payload = createOperation(operation)

    self.channel
      .push(Events.doc, payload: payload)
      .delegateReceive("ok", to: self) { target, message in
        if
          let data = message.payload["response"] as? JSONObject,
          let subId = data["subscriptionId"] as? String
        {
          self.subscriptions[subscriptionId] = subId
          self.subscriptionHandlers[subId] = { message in
            let data = message.payload["result"] as! JSONObject
            let response = GraphQLResponse(operation: operation, body: data)

            do {
              let graphQLResult = try response.parseResultFast()
              completion(.success(graphQLResult))
            } catch {
              let error = AbsintheError(kind: .parseError, payload: data)
              completion(.failure(error))
            }
          }

          if self.cancelledSubscriptions.contains(subscriptionId) {
            self.unsubscribe(subscriptionId)
          }
        }
      }
      .delegateReceive("error", to: self) { target, message in
        let data = message.payload["response"] as! JSONObject
        completion(.failure(AbsintheError(kind: .queryError, payload: data)))
      }
  }
}
