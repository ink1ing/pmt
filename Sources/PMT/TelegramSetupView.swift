import SwiftUI

/// 独立的 Telegram 接入引导页：分步说明 + 必要提示 + 自动获取 Chat ID + 测试发送。
struct TelegramSetupView: View {
    @ObservedObject var store: ConfigStore
    @Environment(\.dismiss) private var dismiss

    private var language: AppLanguage { store.language }
    private var tokenEmpty: Bool {
        store.telegramBotToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.text(.telegramSetupTitle)).font(.headline)
            Text(language.text(.telegramSetupIntro))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text(language.text(.telegramStep1))
                Text(language.text(.telegramStep2))
                Text(language.text(.telegramStep3))
            }
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)

            SecureField(language.text(.telegramBotToken), text: $store.telegramBotToken)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                TextField(language.text(.telegramChatID), text: $store.telegramChatID)
                    .textFieldStyle(.roundedBorder)
                Button(language.text(.telegramFetchChatID)) {
                    Task { await store.fetchTelegramChatID() }
                }
                .disabled(store.isBusy || tokenEmpty)
            }

            Text(language.text(.telegramHint))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !store.statusMessage.isEmpty {
                Text(store.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button(language.text(.telegramSendTest)) {
                    Task { await store.sendTelegramTest() }
                }
                .disabled(store.isBusy || tokenEmpty)
                Spacer()
                Button(language.text(.done)) {
                    store.saveConfig()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
