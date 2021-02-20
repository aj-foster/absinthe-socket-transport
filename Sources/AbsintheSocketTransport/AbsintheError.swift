import Foundation

/**
 * Provides descriptions of errors that may occur while using the socket transport.
 */
public struct AbsintheError: Error, LocalizedError {
  public enum ErrorKind {
    case networkError
    case parseError
    case queryError

    var description: String {
      switch self {
      case .networkError:
        return "Absinthe socket error"
      case .parseError:
        return "Absinthe message parse error"
      case .queryError:
        return "Absinthe query error"
      }
    }
  }

  /// Kind of error that occurred.
  public let kind: ErrorKind

  /// Contents of the related message, if available.
  public let payload: [String: Any]?

  // Implementation for LocalizedError
  public var errorDescription: String? {
    if let payload = payload {
      return "\(self.kind.description): \(String(describing: payload))"
    } else {
      return self.kind.description
    }
  }
}
