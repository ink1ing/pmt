import Foundation

/// Telegram Bot API：发送消息与自动获取 Chat ID。
enum TelegramClient {
    static func sendMessage(token rawToken: String, chatID rawChatID: String, text: String) async throws {
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let chatID = rawChatID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !chatID.isEmpty else {
            throw PMTError.api("请先填写 Telegram Bot Token 和 Chat ID。")
        }
        guard let url = URL(string: "https://api.telegram.org/bot\(token)/sendMessage") else {
            throw PMTError.api("Telegram URL 无效。")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(TelegramSendMessageRequest(chatID: chatID, text: text))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? "无响应内容"
            throw PMTError.api("Telegram 推送失败：\(body)")
        }
    }

    static func fetchChatID(token rawToken: String) async throws -> String {
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw PMTError.api("请先填写 Telegram Bot Token。")
        }
        guard let url = URL(string: "https://api.telegram.org/bot\(token)/getUpdates") else {
            throw PMTError.api("Telegram URL 无效。")
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw PMTError.api("Telegram 请求失败，请检查 Bot Token。")
        }
        let decoded = try JSONDecoder().decode(GetUpdatesResponse.self, from: data)
        guard let chatID = decoded.result.compactMap({ $0.message?.chat.id }).last else {
            throw PMTError.api("未读取到对话，请先在 Telegram 给机器人发送一条消息。")
        }
        return String(chatID)
    }

    private struct GetUpdatesResponse: Decodable {
        struct Update: Decodable {
            struct Message: Decodable {
                struct Chat: Decodable { let id: Int64 }
                let chat: Chat
            }
            let message: Message?
        }
        let result: [Update]
    }
}
