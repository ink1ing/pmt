import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ConfigStore()
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var rewriter: SelectionRewriter?
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
        frontmostAppTracker = FrontmostAppTracker(store: store)
        hotkeyMonitor = GlobalHotkeyMonitor(store: store) { [weak self] targetApplication in
            let resolvedTarget = targetApplication ?? self?.frontmostAppTracker?.currentExternalApplication()
            self?.rewriter?.rewriteSelection(targetApplication: resolvedTarget)
        }
        hotkeyMonitor?.start()

        bindStatusBarIconSetting()
        ensureStatusBarIcon(retryDelays: [0.1, 0.5, 1.5])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveConfig()
    }

    private func bindStatusBarIconSetting() {
        store.$statusBarIconEnabled
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.updateStatusBarIcon()
            }
            .store(in: &cancellables)
    }

    private func ensureStatusBarIcon(retryDelays delays: [TimeInterval]) {
        updateStatusBarIcon()
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.updateStatusBarIcon()
            }
        }
    }

    private func updateStatusBarIcon() {
        if !store.statusBarIconEnabled {
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
            return
        }

        if statusItem?.button == nil {
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }

        guard let item = statusItem, let button = item.button else {
            store.addLog("状态栏图标创建失败：未获得状态栏按钮")
            return
        }

        item.length = NSStatusItem.variableLength
        button.imagePosition = .imageLeading
        button.title = "PMT"
        if let image = NSImage(systemSymbolName: "text.badge.star", accessibilityDescription: "PMT") {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            button.image = image
        } else {
            button.image = nil
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "立即改写选中文本", action: #selector(rewriteNow), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "检查更新", action: #selector(checkForUpdates), keyEquivalent: "u"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
    }

    @objc private func openSettings() {
        showSettings()
    }

    @objc private func rewriteNow() {
        let targetApplication = frontmostAppTracker?.lastExternalApplication
        store.addLog("通过状态栏菜单触发改写，目标：\(FrontmostAppTracker.displayName(for: targetApplication))")
        rewriter?.rewriteSelection(targetApplication: targetApplication)
    }

    @objc private func checkForUpdates() {
        store.addLog("通过状态栏菜单检查更新")
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

        let view = SettingsView(store: store) { [weak self] in
            self?.hotkeyMonitor?.start()
            self?.updateStatusBarIcon()
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
