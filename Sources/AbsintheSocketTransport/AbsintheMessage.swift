import os
import Apollo
import Foundation

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

  static func parse(_ payload: [String: Any], as kind: Self) -> Result<[String: Any], Error> {
    switch kind {
    case .error:
      return .success([:])
    case .response:
      return .success([:])
    case .subscriptionStart:
      return .success([:])
    case .subscriptionResult:
      return .success([:])
    }
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

  /**
   * Parse an error response (as indicated by status "error").
   *
   * - parameter payload: Body of the error message, e.g. `["status": "error", "errors": (...)]`
   * - returns: Result with a typed `GraphQLResult` that has errors but no data
   */
  static func parseError<Operation: GraphQLOperation>(
    operation: Operation,
    payload: [String: Any]
  ) -> Result<GraphQLResult<Operation.Data>, Error> {
    guard
      payload["status"] as? String == "error",
      let errors = payload["errors"] as? [[String: Any]]
    else {
      return .failure(AbsintheError(kind: .parseError, payload: payload))
    }

    let parsedErrors = errors.map { GraphQLError($0) }
    let result = GraphQLResult<Operation.Data>(data: nil, extensions: nil, errors: parsedErrors, source: .server, dependentKeys: nil)

    return .success(result)
  }

  /**
   * Parse a successful response (as indicated by status "ok").
   *
   * - parameter operation: The original GraphQL operation (for typing the response)
   * - parameter payload: Body of the response message, e.g. `["status": "ok", "response": ...]`
   * - returns: Result with a typed `GraphQLResult` as expected by Apollo
   */
  static func parseResponse<Operation: GraphQLOperation>(
    operation: Operation,
    payload: [String: Any]
  ) -> Result<GraphQLResult<Operation.Data>, Error> {
    guard
      payload["status"] as? String == "ok",
      let response = payload["response"] as? [String: Any]
    else {
      return .failure(AbsintheError(kind: .parseError, payload: payload))
    }

    let gqlResponse = GraphQLResponse(operation: operation, body: response)

    do {
      let parsedResponse = try gqlResponse.parseResultFast()
      return .success(parsedResponse)
    } catch {
      let error = AbsintheError(kind: .parseError, payload: payload)
      return .failure(error)
    }
  }

  /**
   * Parse a subscription start confirmation.
   *
   * - parameter payload: Body of the response message containing a subscription ID
   * - returns: Result with the subscription ID
   */
  static func parseSubscriptionStart(_ payload: [String: Any]) -> Result<String, Error> {
    guard
      payload["status"] as? String == "ok",
      let response = payload["response"] as? [String: Any],
      let id = response["subscriptionId"] as? String
    else {
      return .failure(AbsintheError(kind: .parseError, payload: payload))
    }

    return .success(id)
  }

  /**
   * Parse a subscription result.
   *
   * - parameter operation: The original GraphQL operation (for typing the response)
   * - parameter payload: Body of the response message, e.g. `["subscriptionId": "...", "result": ...]`
   * - returns: Result with a typed `GraphQLResult` as expected by Apollo
   */
  static func parseSubscriptionResult<Operation: GraphQLOperation>(
    operation: Operation,
    payload: [String: Any]
  ) -> Result<GraphQLResult<Operation.Data>, Error> {
    guard
      let response = payload["result"] as? [String: Any]
    else {
      return .failure(AbsintheError(kind: .parseError, payload: payload))
    }

    let gqlResponse = GraphQLResponse(operation: operation, body: response)

    do {
      let parsedResponse = try gqlResponse.parseResultFast()
      return .success(parsedResponse)
    } catch {
      let error = AbsintheError(kind: .parseError, payload: payload)
      return .failure(error)
    }
  }
}
