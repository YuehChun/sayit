import Foundation

enum SayitError: LocalizedError {
    case audioError(String)
    case missingAPIKey(String)
    case networkError(String)
    case apiError(String, Int, String)
    case emptyResponse(String)

    var errorDescription: String? {
        switch self {
        case .audioError(let msg):
            return "Audio error: \(msg)"
        case .missingAPIKey(let provider):
            return "\(provider) API key not configured"
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .apiError(let provider, let code, let msg):
            return "\(provider) API error (\(code)): \(msg)"
        case .emptyResponse(let provider):
            return "\(provider) returned empty response"
        }
    }
}
