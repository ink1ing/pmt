import AppKit
import Foundation

/// 建议子系统：本地历史记录、定时调度、模型生成、Telegram 推送。
/// 配置项仍由 ConfigStore 持有，本引擎通过 store 读取并写回运行时状态。
@MainActor
final class AdviceEngine {
    private unowned let store: ConfigStore
    private let maxAdviceHistoryCount = 240
    private var adviceTimer: Timer?
    private var isGeneratingAdvice = false

    init(store: ConfigStore) {
        self.store = store
    }

    func start() {
        adviceTimer?.invalidate()
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.runScheduledIfNeeded()
            }
        }
        adviceTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func recordInput(_ text: String, source: String) {
        guard store.adviceEnabled else {
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            return
        }

        let limited = String(trimmed.prefix(4_000))
        let entry = AdviceHistoryEntry(source: source, text: limited)

        do {
            try FileManager.default.createDirectory(
                at: adviceSupportDirectory,
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            var data = try encoder.encode(entry)
            data.append(0x0A)

            if FileManager.default.fileExists(atPath: adviceHistoryURL.path) {
                let handle = try FileHandle(forWritingTo: adviceHistoryURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: adviceHistoryURL, options: .atomic)
            }

            pruneAdviceHistoryIfNeeded()
            store.addLog(store.language == .zhHans ? "已记录本地建议历史：\(limited.count) 个字符" : "Local advice history recorded: \(limited.count) chars")
        } catch {
            store.addLog(store.language == .zhHans ? "本地建议历史写入失败：\(error.localizedDescription)" : "Advice history write failed: \(error.localizedDescription)")
        }
    }

    func generateNow() async {
        guard !isGeneratingAdvice else {
            store.addLog(store.language == .zhHans ? "建议生成仍在执行，忽略重复触发" : "Advice generation is already running")
            return
        }

        isGeneratingAdvice = true
        store.isBusy = true
        store.statusMessage = store.language == .zhHans ? "正在生成建议..." : "Generating advice..."
        store.addLog(store.statusMessage)
        defer {
            isGeneratingAdvice = false
            store.isBusy = false
        }

        do {
            let entries = try recentAdviceHistory(limit: 80)
            guard !entries.isEmpty else {
                throw PMTError.api(store.language == .zhHans ? "暂无可分析的本地历史。" : "No local history to analyze yet.")
            }

            let advice = try await store.modelClient().rewrite(
                text: adviceUserPayload(from: entries),
                model: store.selectedModel,
                systemPrompt: adviceSystemPrompt,
                mode: .custom
            )
            let entry = "\(reportHeader())\n\(normalizeReport(advice))"
            try appendReport(entry)
            if store.telegramPushEnabled {
                try await sendTelegramMessage(entry)
            }

            store.lastAdviceGeneratedAt = Date()
            store.saveConfig()
            store.statusMessage = store.language == .zhHans ? "建议已生成" : "Advice generated"
            store.addLog(store.language == .zhHans ? "建议已写入：\(resolvedAdviceFileURL.path)" : "Advice written: \(resolvedAdviceFileURL.path)")
        } catch {
            store.statusMessage = error.localizedDescription
            store.addLog(store.language == .zhHans ? "建议生成失败：\(error.localizedDescription)" : "Advice generation failed: \(error.localizedDescription)")
            Notifier.shared.error(error.localizedDescription)
        }
    }

    private func runScheduledIfNeeded() async {
        guard store.adviceEnabled, store.adviceFrequency != .manual, !isGeneratingAdvice else {
            return
        }

        let now = Date()
        guard isAdviceDue(now: now) else {
            return
        }

        await generateNow()
    }

    private func isAdviceDue(now: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let scheduledMinutes = store.adviceHour * 60 + store.adviceMinute

        guard currentMinutes >= scheduledMinutes else {
            return false
        }

        guard let lastAdviceGeneratedAt = store.lastAdviceGeneratedAt else {
            return true
        }

        return shouldGenerateAdvice(since: lastAdviceGeneratedAt, now: now)
    }

    private func shouldGenerateAdvice(since lastDate: Date, now: Date) -> Bool {
        let calendar = Calendar.current
        switch store.adviceFrequency {
        case .manual:
            return false
        case .daily:
            return !calendar.isDate(lastDate, inSameDayAs: now)
        case .weekly:
            let lastWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: lastDate)
            let currentWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            return lastWeek.yearForWeekOfYear != currentWeek.yearForWeekOfYear ||
                lastWeek.weekOfYear != currentWeek.weekOfYear
        }
    }

    private var adviceSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "PMT", directoryHint: .isDirectory)
    }

    private var adviceHistoryURL: URL {
        adviceSupportDirectory.appending(path: "advice-history.jsonl")
    }

    private var resolvedAdviceFileURL: URL {
        let expanded = (store.adviceFilePath as NSString).expandingTildeInPath
        if expanded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: AppConfig.defaultAdviceFilePath)
        }
        return URL(fileURLWithPath: expanded)
    }

    private func recentAdviceHistory(limit: Int) throws -> [AdviceHistoryEntry] {
        guard FileManager.default.fileExists(atPath: adviceHistoryURL.path) else {
            return []
        }

        let data = try Data(contentsOf: adviceHistoryURL)
        let text = String(data: data, encoding: .utf8) ?? ""
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = text
            .split(separator: "\n")
            .compactMap { line -> AdviceHistoryEntry? in
                guard let lineData = String(line).data(using: .utf8) else {
                    return nil
                }
                return try? decoder.decode(AdviceHistoryEntry.self, from: lineData)
            }
        return Array(entries.suffix(limit))
    }

    private func pruneAdviceHistoryIfNeeded() {
        guard let entries = try? recentAdviceHistory(limit: maxAdviceHistoryCount + 20),
              entries.count > maxAdviceHistoryCount else {
            return
        }

        let kept = Array(entries.suffix(maxAdviceHistoryCount))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = kept.compactMap { entry -> Data? in
            guard var encoded = try? encoder.encode(entry) else {
                return nil
            }
            encoded.append(0x0A)
            return encoded
        }.reduce(Data(), +)
        try? data.write(to: adviceHistoryURL, options: .atomic)
    }

    private var adviceSystemPrompt: String {
        """
        你是用户的提示词质量分析师。你会收到该用户最近写给 AI 的多条原始提示词或语音输入（含时间与来源）。请评估其撰写提示词的习惯，产出一份浓缩、可直接执行的改进总结。

        核心原则：
        - 提示词不是越详细越好，该详细则详细、该简略则简略；只在存在真实且重复出现的问题时才给建议。
        - 若用户的提示词已足够清晰有效，直接说明无需调整，绝不为凑数编造建议。

        输出结构：
        - 第一行：一句话总评，指出整体水平与当前最该改进的一个方向（或写明“本期无需调整”）。
        - 随后用“1. 2. 3.”列出改进项；每条先点明观察到的重复模式，再给出下次可立即照做的具体改法，必要时附一个极简改写线索。

        约束：
        - \(store.adviceDetail.targetDescription)
        - 各条建议相互独立、不得主题重叠，重叠则合并为一条。
        - 禁止空泛建议（例如只说“要更具体”却不给出具体做法）。
        - 不复述原文、不泄露隐私内容、不解释分析过程、不寒暄客套。
        - 按影响力从高到低排序，超出上限的低价值项直接舍弃。
        - 保持精炼；不使用 Markdown 标题、加粗、代码块或引用，列表仅用“1. 2.” 数字编号。
        - 输出语言：\(store.language == .zhHans ? "简体中文" : "English")。

        只输出这份总结本身。
        """
    }

    private func adviceUserPayload(from entries: [AdviceHistoryEntry]) -> String {
        let formatter = ISO8601DateFormatter()
        let body = entries.map { entry in
            "[\(formatter.string(from: entry.timestamp))][\(entry.source)] \(entry.text)"
        }.joined(separator: "\n")
        return String(body.suffix(12_000))
    }

    private func normalizeReport(_ text: String) -> String {
        var report = text
            .replacingOccurrences(of: #"[*_`>]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^#{1,6}[ \t]*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        report = report.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(report.prefix(1200))
    }

    private func reportHeader() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let title = store.language == .zhHans ? "PMT 提示词评价" : "PMT Prompt Review"
        return "\(title) · \(formatter.string(from: Date()))"
    }

    private func appendReport(_ entry: String) throws {
        let fileURL = resolvedAdviceFileURL
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let existing = (try? String(contentsOf: fileURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let combined = existing.isEmpty ? entry : "\(entry)\n\n----------\n\n\(existing)"
        try String(combined.prefix(20_000)).write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func sendTelegramMessage(_ message: String) async throws {
        let token = store.telegramBotToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let chatID = store.telegramChatID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !chatID.isEmpty else {
            throw PMTError.api(store.language == .zhHans ? "请先填写 Telegram Bot Token 和 Chat ID。" : "Set Telegram Bot Token and Chat ID first.")
        }

        guard let url = URL(string: "https://api.telegram.org/bot\(token)/sendMessage") else {
            throw PMTError.api("Telegram URL 无效。")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(TelegramSendMessageRequest(chatID: chatID, text: message))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? "无响应内容"
            throw PMTError.api("Telegram 推送失败：\(body)")
        }
        store.addLog(store.language == .zhHans ? "Telegram 建议推送完成" : "Telegram advice pushed")
    }
}
