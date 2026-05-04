import Foundation
import Sparkle
import AppKit

@MainActor
final class UpdateManager: NSObject, SPUUpdaterDelegate {
    static let shared = UpdateManager()

    private var updaterController: SPUStandardUpdaterController!
    private var isAutomaticPromptCheck = false
    private var isPresentingAutomaticPrompt = false

    override private init() {
        super.init()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    func checkForUpdatesOnLaunch() {
        guard !isAutomaticPromptCheck, !updaterController.updater.sessionInProgress else {
            return
        }

        isAutomaticPromptCheck = true
        updaterController.updater.checkForUpdateInformation()
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        guard isAutomaticPromptCheck, !isPresentingAutomaticPrompt else {
            return
        }

        isPresentingAutomaticPrompt = true
        let version = item.displayVersionString
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "发现新版本 \(version)"
        alert.informativeText = releaseNotes(from: item)
        alert.addButton(withTitle: "更新")
        alert.addButton(withTitle: "稍后")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        isAutomaticPromptCheck = false
        isPresentingAutomaticPrompt = false

        if response == .alertFirstButtonReturn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.updaterController.checkForUpdates(nil)
            }
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        isAutomaticPromptCheck = false
        isPresentingAutomaticPrompt = false
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        isAutomaticPromptCheck = false
        isPresentingAutomaticPrompt = false
    }

    private func releaseNotes(from item: SUAppcastItem) -> String {
        let rawNotes = item.itemDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawNotes, !rawNotes.isEmpty else {
            return "是否现在更新到 PMT \(item.displayVersionString)？"
        }

        let cleaned = rawNotes
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "是否现在更新到 PMT \(item.displayVersionString)？" : cleaned
    }
}
