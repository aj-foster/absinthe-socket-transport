import os
import Apollo
import Foundation
import SwiftPhoenixClient

enum AbsintheMessage {
  case error
  case response
  case subscriptionStart
  case subscriptionResult

  //
  // MARK: - Outgoing Messages
  //

  /**
   * Creates an outgoing message for the given GraphQL operation.
   *
   * - parameter op: GraphQLOperation as supplied by Apollo
   * - returns: Outgoing message payload
   */
  static func fromOperation<Operation: GraphQLOperation>(_ op: Operation) -> [String: Any] {
    var payload: [String: Any]
    payload = [ "query": op.queryDocument ]

    if let variables = op.variables {
      payload += [ "variables": variables ]
    }

    return payload
  }

  /**
   * Creates an outgoing message to unsubscribe from the given subscription by `id`.
   *
   * - parameter id: Absinthe subscription ID
   * - returns: Outgoing message payload
   */
  static func unsubscribe(id: String) -> [String: Any] {
    return [ "subscriptionId": id ]
  }

  //
  // MARK: - Incoming Messages
  //

  /**
   * Parse a channel message and call the given completion handler with the result.
   *
   * This function is meant to be used for both successful (status "ok") and unsuccessful (status "error") messages.
   *
   * - parameter operation: The original GraphQL operation (for typing the response)
   * - parameter message: Message as read by the Phoenix socket
   * - returns: Result with a typed `GraphQLResult` as expected by Apollo
   */
  static func parseResponse<Operation: GraphQLOperation>(
    operation: Operation,
    message: Message
  ) -> Result<GraphQLResult<Operation.Data>, Error> {
    guard let response = message.payload["response"] as? [String: Any]
    else {
      return .failure(AbsintheError(kind: .parseError, payload: message.payload))
    }

    do {
      return try .success(GraphQLResponse(operation: operation, body: response).parseResultFast())
    } catch {
      return .failure(error)
    }
  }

  /**
   * Parse a subscription start confirmation.
   *
   * - parameter message: Message as read by the Phoenix socket
   * - returns: Result with the subscription ID
   */
  static func parseSubscriptionStart(_ message: Message) -> Result<String, Error> {
    guard
      message.payload["status"] as? String == "ok"
    else {
      return .failure(AbsintheError(kind: .queryError, payload: message.payload))
    }

    guard
      let response = message.payload["response"] as? [String: Any],
      let id = response["subscriptionId"] as? String
    else {
      return .failure(AbsintheError(kind: .parseError, payload: message.payload))
    }

    return .success(id)
  }

  /**
   * Parse a subscription result.
   *
   * - parameter operation: The original GraphQL operation (for typing the response)
   * - parameter message: Message as read by the Phoenix socket
   * - returns: Result with a typed `GraphQLResult` as expected by Apollo
   */
  static func parseSubscriptionResult<Operation: GraphQLOperation>(
    operation: Operation,
    message: Message
  ) -> Result<GraphQLResult<Operation.Data>, Error> {
    guard let response = message.payload["result"] as? [String: Any]
    else {
      return .failure(AbsintheError(kind: .parseError, payload: message.payload))
    }

    do {
      return try .success(GraphQLResponse(operation: operation, body: response).parseResultFast())
    } catch {
      return .failure(error)
    }
  }
}
