import Foundation

/// OpenAI 兼容 chat/completions 的 SSE 流式解析，逐增量回调。
enum ChatStreaming {
    struct Chunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable { let content: String? }
            let delta: Delta
        }
        let choices: [Choice]
    }

    static func run(_ request: URLRequest, yield: @escaping @Sendable (String) -> Void) async throws {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PMTError.api("流式响应无效。")
        }
        guard 200..<300 ~= http.statusCode else {
            throw PMTError.api("流式请求失败：HTTP \(http.statusCode)")
        }

        var received = false
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(Chunk.self, from: data),
                  let delta = chunk.choices.first?.delta.content,
                  !delta.isEmpty else { continue }
            received = true
            yield(delta)
        }
        if !received {
            throw PMTError.api("模型没有返回可用内容。")
        }
    }
}
