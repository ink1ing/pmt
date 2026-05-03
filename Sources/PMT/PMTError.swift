import Foundation

enum PMTError: LocalizedError {
    case accessibilityMissing
    case noSelectedText
    case missingAPIKey
    case missingModel
    case invalidEndpoint
    case api(String)
    case keychain(String)
    case clipboard(String)

    var errorDescription: String? {
        switch self {
        case .accessibilityMissing:
            "需要开启辅助功能权限后才能读取并替换选中文本。"
        case .noSelectedText:
            "没有读取到选中文本。"
        case .missingAPIKey:
            "请先填写 API Key。"
        case .missingModel:
            "请先选择模型。"
        case .invalidEndpoint:
            "端点 URL 无效。"
        case .api(let message):
            message
        case .keychain(let message):
            message
        case .clipboard(let message):
            message
        }
    }
}
