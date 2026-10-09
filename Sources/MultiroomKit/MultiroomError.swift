import Foundation

/// Typed failures deliberately exclude URLs, credentials, raw responses, and household identifiers.
public enum MultiroomError: Error, LocalizedError, Codable, Equatable, Sendable {
    case invalidConfiguration
    case invalidResponse
    case networkUnavailable
    case timedOut
    case responseTooLarge
    case unauthorized
    case forbidden
    case resourceGone
    case rateLimited(retryAfter: TimeInterval?)
    case http(status: Int)
    case authenticationFailed
    case noSpeakers
    case noHouseholds
    case householdSelectionRequired
    case householdUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "Invalid SDK configuration."
        case .invalidResponse: "Unexpected response format or topology."
        case .networkUnavailable: "Network request failed."
        case .timedOut: "Network request timed out."
        case .responseTooLarge: "Response exceeds the size limit."
        case .unauthorized: "Sonos authorization is invalid or expired."
        case .forbidden: "Sonos denied access to this resource."
        case .resourceGone: "The Sonos resource no longer exists."
        case .rateLimited: "Sonos rate limit reached."
        case .http(let status): "HTTP request failed with status \(status)."
        case .authenticationFailed: "Credentials could not be obtained."
        case .noSpeakers: "No usable UPnP speakers were discovered."
        case .noHouseholds: "No Sonos households are available."
        case .householdSelectionRequired: "Select a household explicitly."
        case .householdUnavailable: "The selected household is unavailable."
        }
    }
}

func sanitized(_ error: Error) -> MultiroomError {
    (error as? MultiroomError) ?? .networkUnavailable
}

func checkCancellation(_ error: Error) throws {
    if error is CancellationError || Task.isCancelled { throw CancellationError() }
}
