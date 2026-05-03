import AppKit
import Foundation
import IOKit.hid
import UserNotifications

enum PermissionManager {
    static func accessibilityStatus() -> String {
        AXIsProcessTrusted() ? "辅助功能权限已开启" : "辅助功能权限未开启"
    }

    static func requestAccessibilityAccess() -> String {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        return granted ? "辅助功能权限已开启" : "已请求辅助功能权限，请在系统设置中允许 PMT"
    }

    static func inputMonitoringStatus() -> String {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            return "输入监控权限已开启"
        case kIOHIDAccessTypeDenied:
            return "输入监控权限已关闭"
        case kIOHIDAccessTypeUnknown:
            return "输入监控权限尚未确定"
        default:
            return "输入监控权限状态未知"
        }
    }

    static func requestInputMonitoringAccess() -> String {
        let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        return granted ? "输入监控权限已开启" : "已请求输入监控权限，请在系统设置中允许 PMT 后重启应用"
    }

    static func keyboardPermissionSummary() -> String {
        "\(accessibilityStatus())；\(inputMonitoringStatus())"
    }

    static func openAccessibilitySettings() {
        openSettingsURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openInputMonitoringSettings() {
        openSettingsURL("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    static func openPrivacySettings() {
        openSettingsURL("x-apple.systempreferences:com.apple.preference.security")
    }

    static func openNotificationSettings() {
        openSettingsURL("x-apple.systempreferences:com.apple.preference.notifications")
    }

    static func notificationStatus() async -> String {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return "通知权限检查需要通过 PMT.app 运行"
        }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "通知权限已开启"
        case .denied:
            return "通知权限已关闭"
        case .notDetermined:
            return "通知权限尚未请求"
        @unknown default:
            return "通知权限状态未知"
        }
    }

    private static func openSettingsURL(_ rawValue: String) {
        guard let url = URL(string: rawValue) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
