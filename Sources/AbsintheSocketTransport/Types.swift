import Foundation

//
// Channel Topics
//

enum Topic: String {
  case absinthe = "__absinthe__:control"  // GraphQL
  case phoenix = "phoenix"                // Keepalive
}

struct Topics {
  static let absinthe = Topic.absinthe.rawValue
  static let phoenix = Topic.phoenix.rawValue
}

//
//  Message Events
//

enum Event: String {
  case doc = "doc"                        // GraphQL query, mutation, or subscription
  case reply = "phx_reply"                // Generic server response
  case subscription = "subscription:data" // Incoming subscription results
  case unsubscribe = "unsubscribe"        // Unsubscribe from GraphQL subscription
}

struct Events {
  static let doc = Event.doc.rawValue
  static let reply = Event.reply.rawValue
  static let subscription = Event.subscription.rawValue
  static let unsubscribe = Event.unsubscribe.rawValue
}

//
// Message Data Keys
//

enum Key: String {
  case data = "data"                      // Response key for successful queries/mutations
  case error = "errors"                   // Response key for errored operations
  case subscriptionId = "subscriptionId"  // Response key for subscribe/unsubscribe operations
}

struct Keys {
  static let data = Key.data.rawValue
  static let error = Key.error.rawValue
  static let subscriptionId = Key.subscriptionId.rawValue
}
