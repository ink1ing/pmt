import Foundation

struct OpenAICompatibleClient {
    let endpointURL: URL
    let apiKey: String

    init(endpointURL: String, apiKey: String) throws {
        let trimmed = endpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed), components.scheme != nil, components.host != nil else {
            throw PMTError.invalidEndpoint
        }
        if components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        guard let url = components.url else {
            throw PMTError.invalidEndpoint
        }
        self.endpointURL = url
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func listModels() async throws -> [String] {
        let url = endpointURL.appending(path: "models")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return decoded.data.map(\.id).sorted()
    }

    func rewrite(text: String, model: String, systemPrompt: String, mode: RewriteMode) async throws -> String {
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PMTError.missingModel
        }

        let url = endpointURL.appending(path: "chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ChatCompletionRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "system", content: mode.instruction),
                .init(role: "user", content: text)
            ],
            temperature: 0.2
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw PMTError.api("模型没有返回可用内容。")
        }
        return content
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw PMTError.api("API 响应无效。")
        }
        guard 200..<300 ~= http.statusCode else {
            if let decoded = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw PMTError.api(decoded.error.message)
            }
            let body = String(data: data, encoding: .utf8) ?? "无响应内容"
            throw PMTError.api("API 请求失败：HTTP \(http.statusCode) \(body)")
        }
    }
}

private struct ModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
    }

    let data: [Model]
}

private struct ChatCompletionRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct APIErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    let error: APIError
}
