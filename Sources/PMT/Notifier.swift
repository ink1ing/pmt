import Foundation
import UserNotifications

final class Notifier: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = Notifier()
    private var didConfigureNotificationCenter = false

    private override init() {
        super.init()
    }

    func error(_ message: String) {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            NSLog("PMT error: %@", message)
            return
        }

        configureNotificationCenterIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "PMT"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func configureNotificationCenterIfNeeded() {
        guard !didConfigureNotificationCenter else { return }
        didConfigureNotificationCenter = true
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
