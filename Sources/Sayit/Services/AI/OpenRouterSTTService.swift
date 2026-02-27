import Foundation

final class OpenRouterSTTService: Sendable {
    private let keychainManager: KeychainManager
    private let model = "google/gemini-2.5-flash"

    init(keychainManager: KeychainManager) {
        self.keychainManager = keychainManager
    }

    var isConfigured: Bool {
        keychainManager.hasKey(.openRouterAPIKey)
    }

    // MARK: - Request/Response types

    private struct TextRefineRequest: Encodable {
        let model: String
        let messages: [Message]

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]

        struct Message: Encodable {
            let role: String
            let content: [ContentPart]
        }

        struct ContentPart: Encodable {
            let type: String
            let text: String?
            let input_audio: AudioData?

            init(text: String) {
                self.type = "text"
                self.text = text
                self.input_audio = nil
            }

            init(audio: AudioData) {
                self.type = "input_audio"
                self.text = nil
                self.input_audio = audio
            }
        }

        struct AudioData: Encodable {
            let data: String
            let format: String
        }
    }

    private struct ChatResponse: Decodable {
        let choices: [Choice]?
        let error: ResponseError?

        struct Choice: Decodable {
            let message: Message
        }

        struct Message: Decodable {
            let content: String?
        }

        struct ResponseError: Decodable {
            let message: String
        }
    }

    // MARK: - Text Refinement

    func refineText(_ text: String) async throws -> String {
        guard let apiKey = keychainManager.retrieve(keyType: .openRouterAPIKey) else {
            throw SayitError.missingAPIKey("OpenRouter")
        }

        let request = TextRefineRequest(
            model: model,
            messages: [
                TextRefineRequest.Message(
                    role: "user",
                    content: """
                    請整理以下語音轉文字的內容，移除語助詞（如：嗯、啊、呃、那個、就是、然後、對）和冗詞贅字，\
                    讓文字更精簡通順，但不要改變原意或增加新內容。\
                    保持原本的語言（繁體中文或其他語言）。\
                    只回傳整理後的文字，不要加任何說明。

                    原文：
                    \(text)
                    """
                ),
            ]
        )

        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw SayitError.networkError("Invalid API URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SayitError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SayitError.apiError("OpenRouter", httpResponse.statusCode, body)
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)

        if let error = chatResponse.error {
            throw SayitError.apiError("OpenRouter", httpResponse.statusCode, error.message)
        }

        guard let refined = chatResponse.choices?.first?.message.content else {
            throw SayitError.emptyResponse("OpenRouter")
        }

        return refined.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Transcription

    func transcribe(wavData: Data) async throws -> String {
        guard let apiKey = keychainManager.retrieve(keyType: .openRouterAPIKey) else {
            throw SayitError.missingAPIKey("OpenRouter")
        }

        let base64Audio = wavData.base64EncodedString()

        let request = ChatRequest(
            model: model,
            messages: [
                ChatRequest.Message(
                    role: "user",
                    content: [
                        ChatRequest.ContentPart(audio: ChatRequest.AudioData(
                            data: base64Audio,
                            format: "wav"
                        )),
                        ChatRequest.ContentPart(text: """
                        Transcribe this audio and refine the result. \
                        If the audio contains Mandarin Chinese, use Traditional Chinese (繁體中文). \
                        If the audio contains other languages, transcribe in that language.

                        After transcribing, clean up the text:
                        - Fix obvious speech recognition errors
                        - Add proper punctuation
                        - Fix grammar issues caused by speech recognition
                        - Do NOT change the meaning or add new content
                        - Preserve the original language and level of formality
                        - Do NOT include any timestamps

                        Return ONLY the final refined text, nothing else.
                        """),
                    ]
                ),
            ]
        )

        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw SayitError.networkError("Invalid API URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SayitError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SayitError.apiError("OpenRouter", httpResponse.statusCode, body)
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)

        if let error = chatResponse.error {
            throw SayitError.apiError("OpenRouter", httpResponse.statusCode, error.message)
        }

        guard let text = chatResponse.choices?.first?.message.content else {
            throw SayitError.emptyResponse("OpenRouter")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
