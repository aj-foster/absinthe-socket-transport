import os
import Apollo
import Foundation

enum AbsintheMessage {

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

  static func parse(_ payload: [String: Any]) -> Result<[String: Any], Error> {
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
}
