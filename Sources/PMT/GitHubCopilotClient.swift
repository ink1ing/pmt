import Foundation

struct GitHubCopilotAuthSession {
    let deviceCode: String
    let userCode: String
    let verificationURL: URL
    let interval: TimeInterval
    let expiresAt: Date
}

struct GitHubCopilotAccount {
    let login: String
    let accessToken: String
}

struct GitHubCopilotClient: PromptModelClient {
    private static let clientID = "01ab8ac9400c4e429b23"
    private static let deviceCodeURL = URL(string: "https://github.com/login/device/code")!
    private static let tokenURL = URL(string: "https://github.com/login/oauth/access_token")!
    private static let userURL = URL(string: "https://api.github.com/user")!
    private static let copilotTokenURL = URL(string: "https://api.github.com/copilot_internal/v2/token")!
    private static let copilotModelsURL = URL(string: "https://api.githubcopilot.com/models")!
    private static let copilotCompletionsURL = URL(string: "https://api.githubcopilot.com/chat/completions")!
    private static let tokenCache = CopilotTokenCache()

    let accessToken: String

    static func startDeviceFlow() async throws -> GitHubCopilotAuthSession {
        let body = urlEncodedBody([
            "client_id": clientID,
            "scope": "read:user"
        ])

        var request = URLRequest(url: deviceCodeURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        let response: DeviceCodeResponse = try await send(request)
        guard let verificationURL = URL(string: response.verificationUriComplete ?? response.verificationUri) else {
            throw PMTError.api("GitHub 授权地址无效。")
        }

        return GitHubCopilotAuthSession(
            deviceCode: response.deviceCode,
            userCode: response.userCode,
            verificationURL: verificationURL,
            interval: TimeInterval(response.interval ?? 5),
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn ?? 900))
        )
    }

    static func pollAuthorization(session: GitHubCopilotAuthSession) async throws -> GitHubCopilotAccount {
        var interval = session.interval

        while Date() < session.expiresAt {
            try await Task.sleep(nanoseconds: UInt64(max(interval, 1) * 1_000_000_000))

            let body = urlEncodedBody([
                "client_id": clientID,
                "device_code": session.deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
            ])

            var request = URLRequest(url: tokenURL)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = body

            let tokenResponse: OAuthTokenResponse = try await send(request, allowOAuthPending: true)
            if tokenResponse.error == "authorization_pending" {
                continue
            }
            if tokenResponse.error == "slow_down" {
                interval = min(interval + 2, 15)
                continue
            }
            if let error = tokenResponse.error {
                throw PMTError.api(tokenResponse.errorDescription ?? error)
            }
            guard let accessToken = tokenResponse.accessToken else {
                throw PMTError.api("GitHub 授权没有返回 access token。")
            }

            let account = try await fetchAccount(accessToken: accessToken)
            return GitHubCopilotAccount(login: account.login, accessToken: accessToken)
        }

        throw PMTError.api("GitHub 授权已超时。")
    }

    func listModels() async throws -> [String] {
        let apiToken = try await copilotAPIToken()
        var request = URLRequest(url: Self.copilotModelsURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        setCopilotHeaders(on: &request)

        let response: CopilotModelsResponse = try await Self.send(request)
        return response.data
            .filter { $0.modelPickerEnabled != false }
            .map(\.id)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .removingDuplicates()
            .sorted()
    }

    func rewrite(text: String, model: String, systemPrompt: String, mode: RewriteMode) async throws -> String {
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PMTError.missingModel
        }

        let apiToken = try await copilotAPIToken()
        var request = URLRequest(url: Self.copilotCompletionsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setCopilotHeaders(on: &request)

        let body = ChatCompletionRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: text)
            ],
            temperature: 0.2
        )
        request.httpBody = try JSONEncoder().encode(body)

        let decoded: ChatCompletionResponse = try await Self.send(request)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw PMTError.api("模型没有返回可用内容。")
        }
        return content
    }

    func testModelLatency(model: String, systemPrompt: String, mode: RewriteMode) async throws -> TimeInterval {
        let start = Date()
        _ = try await rewrite(text: "Test prompt.", model: model, systemPrompt: systemPrompt, mode: mode)
        return Date().timeIntervalSince(start)
    }

    private static func fetchAccount(accessToken: String) async throws -> GitHubUserResponse {
        var request = URLRequest(url: userURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("PMT/0.0.81", forHTTPHeaderField: "User-Agent")
        return try await send(request)
    }

    private func copilotAPIToken() async throws -> String {
        if let cached = await Self.tokenCache.token(for: accessToken) {
            return cached
        }

        var request = URLRequest(url: Self.copilotTokenURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("PMT/0.0.81", forHTTPHeaderField: "User-Agent")

        let response: CopilotTokenResponse = try await Self.send(request)
        let expiresAt = response.expiresAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            ?? Date().addingTimeInterval(10 * 60)
        await Self.tokenCache.set(response.token, expiresAt: expiresAt, for: accessToken)
        return response.token
    }

    private func setCopilotHeaders(on request: inout URLRequest) {
        request.setValue("GithubCopilot/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("vscode/1.100.0", forHTTPHeaderField: "Editor-Version")
        request.setValue("copilot/1.300.0", forHTTPHeaderField: "Editor-Plugin-Version")
    }

    private static func urlEncodedBody(_ values: [String: String]) -> Data {
        var components = URLComponents()
        components.queryItems = values.map { URLQueryItem(name: $0.key, value: $0.value) }
        return Data((components.percentEncodedQuery ?? "").utf8)
    }

    private static func send<T: Decodable>(_ request: URLRequest, allowOAuthPending: Bool = false) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PMTError.api("GitHub 响应无效。")
        }

        if allowOAuthPending, let decoded = try? JSONDecoder.github.decode(T.self, from: data) {
            return decoded
        }

        guard 200..<300 ~= http.statusCode else {
            if let decoded = try? JSONDecoder.github.decode(GitHubErrorResponse.self, from: data) {
                throw PMTError.api(decoded.errorDescription ?? decoded.message ?? decoded.error ?? "GitHub 请求失败。")
            }
            let body = String(data: data, encoding: .utf8) ?? "无响应内容"
            throw PMTError.api("GitHub 请求失败：HTTP \(http.statusCode) \(body)")
        }

        return try JSONDecoder.github.decode(T.self, from: data)
    }
}

private actor CopilotTokenCache {
    private var cache: [String: (token: String, expiresAt: Date)] = [:]

    func token(for accessToken: String) -> String? {
        guard let cached = cache[accessToken], cached.expiresAt > Date() else {
            return nil
        }
        return cached.token
    }

    func set(_ token: String, expiresAt: Date, for accessToken: String) {
        cache[accessToken] = (token, expiresAt)
    }
}

private struct DeviceCodeResponse: Decodable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let verificationUriComplete: String?
    let expiresIn: Int?
    let interval: Int?
}

private struct OAuthTokenResponse: Decodable {
    let accessToken: String?
    let error: String?
    let errorDescription: String?
}

private struct GitHubUserResponse: Decodable {
    let login: String
}

private struct CopilotTokenResponse: Decodable {
    let token: String
    let expiresAt: Int?
}

private struct CopilotModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
        let modelPickerEnabled: Bool?
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

private struct GitHubErrorResponse: Decodable {
    let message: String?
    let error: String?
    let errorDescription: String?
}

private extension JSONDecoder {
    static var github: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

private extension Array where Element == String {
    func removingDuplicates() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
