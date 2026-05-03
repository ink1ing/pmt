@preconcurrency import AppKit

@MainActor
final class FrontmostAppTracker {
    private let ownProcessIdentifier = NSRunningApplication.current.processIdentifier
    private var observer: NSObjectProtocol?
    private(set) var lastExternalApplication: NSRunningApplication?

    init(store: ConfigStore) {
        lastExternalApplication = Self.externalFrontmostApplication(ownProcessIdentifier: ownProcessIdentifier)
        if let app = lastExternalApplication {
            store.addLog("记录当前目标 App：\(Self.displayName(for: app))")
        }

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak store] notification in
            guard let self,
                  let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  application.processIdentifier != self.ownProcessIdentifier else {
                return
            }
            Task { @MainActor in
                self.lastExternalApplication = application
                store?.addLog("记录目标 App：\(Self.displayName(for: application))")
            }
        }
    }

    func currentExternalApplication() -> NSRunningApplication? {
        Self.externalFrontmostApplication(ownProcessIdentifier: ownProcessIdentifier) ?? lastExternalApplication
    }

    static func displayName(for application: NSRunningApplication?) -> String {
        guard let application else {
            return "未知 App"
        }
        return application.localizedName ?? application.bundleIdentifier ?? "PID \(application.processIdentifier)"
    }

    private static func externalFrontmostApplication(ownProcessIdentifier: pid_t) -> NSRunningApplication? {
        let app = NSWorkspace.shared.frontmostApplication
        guard app?.processIdentifier != ownProcessIdentifier else {
            return nil
        }
        return app
    }
}
