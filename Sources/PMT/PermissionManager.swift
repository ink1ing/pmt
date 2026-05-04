import AppKit
import Foundation
import IOKit.hid

enum PermissionManager {
    static var hasAccessibilityAccess: Bool {
        AXIsProcessTrusted()
    }

    static var hasInputMonitoringAccess: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    static func accessibilityStatus(language: AppLanguage) -> String {
        switch (language, AXIsProcessTrusted()) {
        case (.zhHans, true): "辅助功能权限已开启"
        case (.zhHans, false): "辅助功能权限未开启"
        case (.english, true): "Accessibility permission is enabled"
        case (.english, false): "Accessibility permission is disabled"
        }
    }

    static func requestAccessibilityAccess(language: AppLanguage) -> String {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        switch (language, granted) {
        case (.zhHans, true): return "辅助功能权限已开启"
        case (.zhHans, false): return "已请求辅助功能权限，请在系统设置中允许 PMT"
        case (.english, true): return "Accessibility permission is enabled"
        case (.english, false): return "Accessibility permission requested. Allow PMT in System Settings"
        }
    }

    static func inputMonitoringStatus(language: AppLanguage) -> String {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            return language == .zhHans ? "输入监控权限已开启" : "Input Monitoring is enabled"
        case kIOHIDAccessTypeDenied:
            return language == .zhHans ? "输入监控权限已关闭" : "Input Monitoring is disabled"
        case kIOHIDAccessTypeUnknown:
            return language == .zhHans ? "输入监控权限尚未确定" : "Input Monitoring status is unknown"
        default:
            return language == .zhHans ? "输入监控权限状态未知" : "Input Monitoring status is unknown"
        }
    }

    static func requestInputMonitoringAccess(language: AppLanguage) -> String {
        let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        if !granted {
            openInputMonitoringSettings()
        }
        switch (language, granted) {
        case (.zhHans, true): return "输入监控权限已开启"
        case (.zhHans, false): return "已请求输入监控权限，请在系统设置中允许 PMT 后重启应用"
        case (.english, true): return "Input Monitoring is enabled"
        case (.english, false): return "Input Monitoring requested. Allow PMT in System Settings and restart the app"
        }
    }

    static func keyboardPermissionSummary(language: AppLanguage) -> String {
        let separator = "\n"
        return "\(accessibilityStatus(language: language))\(separator)\(inputMonitoringStatus(language: language))"
    }

    static func openAccessibilitySettings() {
        openSettingsURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openInputMonitoringSettings() {
        openSettingsURL("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    private static func openSettingsURL(_ rawValue: String) {
        guard let url = URL(string: rawValue) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
