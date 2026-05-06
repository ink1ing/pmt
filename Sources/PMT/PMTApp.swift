import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ConfigStore()
    private var floatingIcon: FloatingRewriteIcon?
    private var settingsWindow: NSWindow?
    private var rewriter: SelectionRewriter?
    private var dictationWorkflow: DictationWorkflow?
    private var hotkeyMonitor: GlobalHotkeyMonitor?
    private var frontmostAppTracker: FrontmostAppTracker?
    private let updateManager = UpdateManager.shared
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Bundle.main.bundleURL.pathExtension == "app" {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }

        rewriter = SelectionRewriter(store: store)
        dictationWorkflow = DictationWorkflow(store: store)
        frontmostAppTracker = FrontmostAppTracker(store: store)
        floatingIcon = FloatingRewriteIcon(
            onRewrite: { [weak self] in
                self?.rewriteFromFloatingIcon()
            },
            onOpenSettings: { [weak self] in
                self?.showSettings()
            }
        )
        hotkeyMonitor = GlobalHotkeyMonitor(
            store: store,
            onRewriteTrigger: { [weak self] targetApplication in
                let resolvedTarget = targetApplication ?? self?.frontmostAppTracker?.currentExternalApplication()
                self?.rewriter?.rewriteSelection(targetApplication: resolvedTarget)
            },
            onDictationTrigger: { [weak self] targetApplication in
                let resolvedTarget = targetApplication ?? self?.frontmostAppTracker?.currentExternalApplication()
                self?.dictationWorkflow?.toggle(targetApplication: resolvedTarget)
            }
        )
        hotkeyMonitor?.start()

        bindFloatingIconSetting()
        ensureFloatingIcon(retryDelays: [0.1, 0.5, 1.5])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.showSettings()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.updateManager.checkForUpdatesOnLaunch()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveConfig()
    }

    private func bindFloatingIconSetting() {
        store.$statusBarIconEnabled
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.updateFloatingIcon()
            }
            .store(in: &cancellables)
    }

    private func ensureFloatingIcon(retryDelays delays: [TimeInterval]) {
        updateFloatingIcon()
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.updateFloatingIcon()
            }
        }
    }

    private func updateFloatingIcon() {
        if !store.statusBarIconEnabled {
            floatingIcon?.hide()
            store.floatingIconVisible = false
            return
        }

        floatingIcon?.show()
        store.floatingIconVisible = floatingIcon?.isVisible == true
    }

    @objc private func openSettings() {
        showSettings()
    }

    @objc private func rewriteNow() {
        let targetApplication = frontmostAppTracker?.lastExternalApplication
        store.addLog("通过菜单触发改写，目标：\(FrontmostAppTracker.displayName(for: targetApplication))")
        rewriter?.rewriteSelection(targetApplication: targetApplication)
    }

    private func rewriteFromFloatingIcon() {
        let targetApplication = frontmostAppTracker?.currentExternalApplication()
        store.addLog("通过悬浮图标触发改写，目标：\(FrontmostAppTracker.displayName(for: targetApplication))")
        rewriter?.rewriteSelection(targetApplication: targetApplication)
    }

    @objc private func checkForUpdates() {
        store.addLog("检查更新")
        updateManager.checkForUpdates()
    }

    @objc private func quit() {
        hotkeyMonitor?.stop()
        NSApp.terminate(nil)
    }

    private func showSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.orderFrontRegardless()
            return
        }

        let view = SettingsView(store: store, dictationWorkflow: dictationWorkflow) { [weak self] in
            self?.hotkeyMonitor?.start()
            self?.updateFloatingIcon()
        }
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "PMT"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow == settingsWindow {
            store.saveConfig()
            settingsWindow = nil
        }
    }
}
