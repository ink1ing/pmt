import AppKit
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

        updateStatusBarIcon()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveConfig()
    }

    private func updateStatusBarIcon() {
        if !store.statusBarIconEnabled {
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
            return
        }

        if statusItem != nil {
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(systemSymbolName: "text.badge.star", accessibilityDescription: "PMT") {
            image.isTemplate = true
            item.button?.image = image
        } else {
            item.button?.title = "PMT"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "立即改写选中文本", action: #selector(rewriteNow), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "检查更新", action: #selector(checkForUpdates), keyEquivalent: "u"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
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
