import Foundation

struct TelegramSendMessageRequest: Encodable {
    let chatID: String
    let text: String

    enum CodingKeys: String, CodingKey {
        case chatID = "chat_id"
        case text
    }
}
