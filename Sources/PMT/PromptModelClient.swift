import Foundation

protocol PromptModelClient: Sendable {
    func listModels() async throws -> [String]
    func rewrite(text: String, model: String, systemPrompt: String, mode: RewriteMode) async throws -> String
    func testModelLatency(model: String, systemPrompt: String, mode: RewriteMode) async throws -> TimeInterval
}
