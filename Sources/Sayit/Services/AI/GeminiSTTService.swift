import Foundation

final class GeminiSTTService: Sendable {
    private let keychainManager: KeychainManager
    private let model = "gemini-2.5-flash-lite"

    init(keychainManager: KeychainManager) {
        self.keychainManager = keychainManager
    }

    struct GeminiRequest: Encodable {
        let contents: [Content]

        struct Content: Encodable {
            let parts: [Part]
        }

        struct Part: Encodable {
            let text: String?
            let inlineData: InlineData?

            enum CodingKeys: String, CodingKey {
                case text
                case inlineData = "inline_data"
            }

            init(text: String) {
                self.text = text
                self.inlineData = nil
            }

            init(inlineData: InlineData) {
                self.text = nil
                self.inlineData = inlineData
            }
        }

        struct InlineData: Encodable {
            let mimeType: String
            let data: String

            enum CodingKeys: String, CodingKey {
                case mimeType = "mime_type"
                case data
            }
        }
    }

    struct GeminiResponse: Decodable {
        let candidates: [Candidate]?
        let error: GeminiError?

        struct Candidate: Decodable {
            let content: Content
        }

        struct Content: Decodable {
            let parts: [Part]
        }

        struct Part: Decodable {
            let text: String?
        }

        struct GeminiError: Decodable {
            let message: String
        }
    }

    func transcribe(wavData: Data) async throws -> String {
        guard let apiKey = keychainManager.retrieve(keyType: .geminiAPIKey) else {
            throw SayitError.missingAPIKey("Gemini")
        }

        let base64Audio = wavData.base64EncodedString()

        let request = GeminiRequest(
            contents: [
                GeminiRequest.Content(parts: [
                    GeminiRequest.Part(inlineData: GeminiRequest.InlineData(
                        mimeType: "audio/wav",
                        data: base64Audio
                    )),
                    GeminiRequest.Part(text: """
                    Transcribe this audio and refine the result. \
                    If the audio contains Mandarin Chinese, use Traditional Chinese (繁體中文). \
                    If the audio contains other languages, transcribe in that language.

                    After transcribing, clean up the text:
                    - Fix obvious speech recognition errors
                    - Add proper punctuation
                    - Fix grammar issues caused by speech recognition
                    - Do NOT change the meaning or add new content
                    - Preserve the original language and level of formality

                    Return ONLY the final refined text, nothing else.
                    """),
                ])
            ]
        )

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw SayitError.networkError("Invalid API URL")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SayitError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SayitError.apiError("Gemini", httpResponse.statusCode, body)
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let error = geminiResponse.error {
            throw SayitError.apiError("Gemini", httpResponse.statusCode, error.message)
        }

        guard let text = geminiResponse.candidates?.first?.content.parts.first?.text else {
            throw SayitError.emptyResponse("Gemini")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum SayitError: LocalizedError {
    case missingAPIKey(String)
    case networkError(String)
    case apiError(String, Int, String)
    case emptyResponse(String)
    case audioError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let service):
            return "\(service) API key not configured"
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .apiError(let service, let code, let msg):
            return "\(service) API error (\(code)): \(msg)"
        case .emptyResponse(let service):
            return "\(service) returned empty response"
        case .audioError(let msg):
            return "Audio error: \(msg)"
        }
    }
}
