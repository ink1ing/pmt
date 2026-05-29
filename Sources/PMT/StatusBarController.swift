import AppKit

/// 菜单栏状态项：改写、流式开关、三预设快速切换、设置、更新、退出。
/// 菜单在每次展开前动态重建，以反映当前流式开关与激活预设。
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let store: ConfigStore
    private let onRewrite: () -> Void
    private let onOpenSettings: () -> Void

    init(store: ConfigStore, onRewrite: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.store = store
        self.onRewrite = onRewrite
        self.onOpenSettings = onOpenSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        statusItem.button?.title = "🤔"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let language = store.language
        menu.removeAllItems()

        menu.addItem(item(language.text(.rewriteNow), #selector(rewriteAction)))

        menu.addItem(.separator())
        let streaming = item(language.text(.streamingMode), #selector(toggleStreaming))
        streaming.state = store.streamingEnabled ? .on : .off
        menu.addItem(streaming)

        menu.addItem(.separator())
        let header = NSMenuItem(title: language.text(.preset), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for index in store.presets.indices {
            let model = store.presets[index].model.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = "\(language.text(.preset)) \(index + 1)" + (model.isEmpty ? "" : " · \(model)")
            let presetItem = item(title, #selector(selectPreset(_:)))
            presetItem.tag = index
            presetItem.state = index == store.activePresetIndex ? .on : .off
            menu.addItem(presetItem)
        }

        menu.addItem(.separator())
        menu.addItem(item(language.text(.settings), #selector(openSettingsAction)))
        menu.addItem(item(language.text(.checkForUpdates), #selector(checkUpdatesAction)))
        menu.addItem(.separator())
        menu.addItem(item(language.text(.quitApp), #selector(quitAction)))
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        return menuItem
    }

    @objc private func rewriteAction() {
        onRewrite()
    }

    @objc private func toggleStreaming() {
        store.streamingEnabled.toggle()
        store.saveConfig()
    }

    @objc private func selectPreset(_ sender: NSMenuItem) {
        store.switchPreset(to: sender.tag)
    }

    @objc private func openSettingsAction() {
        onOpenSettings()
    }

    @objc private func checkUpdatesAction() {
        UpdateManager.shared.checkForUpdates()
    }

    @objc private func quitAction() {
        store.saveConfig()
        NSApp.terminate(nil)
    }
}
