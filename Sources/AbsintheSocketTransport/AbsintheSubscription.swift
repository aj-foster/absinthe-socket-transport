import Apollo
import Foundation

/**
 * Provides a cancellable task for subscriptions. To unsubscribe, use `cancel()`.
 */
class AbsintheSubscription: Cancellable {
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
