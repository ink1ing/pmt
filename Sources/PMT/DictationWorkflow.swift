import AppKit
import AVFoundation
import CoreML
import Foundation
import WhisperKit

@MainActor
final class DictationWorkflow {
    private let store: ConfigStore
    private let activityIndicator = RewriteActivityIndicator()
    private var isRecording = false
    private var isProcessing = false
    private var targetApplication: NSRunningApplication?
    private let recorder = DictationRecorder()
    private let transcriber: LocalWhisperTranscriber

    init(store: ConfigStore) {
        self.store = store
        self.transcriber = LocalWhisperTranscriber(store: store)
    }

    func toggle(targetApplication: NSRunningApplication?) {
        guard store.previewEnabled else {
            store.addLog("语音预览功能未启用")
            return
        }

        guard Self.isAppleSilicon else {
            let message = store.language == .zhHans ? "语音预览仅支持 M 芯片 Mac。" : "Dictation preview requires Apple Silicon."
            store.statusMessage = message
            store.addLog(message)
            return
        }

        if isRecording {
            stopAndProcess()
        } else if isProcessing {
            store.addLog("语音整理仍在执行，忽略触发")
        } else {
            start(targetApplication: targetApplication)
        }
    }

    func prepareModel() {
        guard Self.isAppleSilicon else {
            store.whisperModelStatus = store.language == .zhHans ? "仅支持 M 芯片" : "Apple Silicon only"
            return
        }

        Task {
            do {
                updatePreparationProgress(
                    status: store.language == .zhHans ? "开始准备 Whisper 模型..." : "Preparing Whisper model...",
                    download: 0,
                    preparation: 0
                )
                store.whisperModelStatus = store.language == .zhHans ? "准备中..." : "Preparing..."
                try await transcriber.prepare(
                    model: store.whisperModel,
                    metalAccelerationEnabled: store.whisperMetalAccelerationEnabled
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.updatePreparationProgress(progress)
                    }
                }
                store.whisperModelStatus = store.language == .zhHans ? "已准备" : "Ready"
                updatePreparationProgress(
                    status: store.language == .zhHans ? "模型已准备完成" : "Model is ready",
                    download: 1,
                    preparation: 1
                )
                store.statusMessage = store.language == .zhHans ? "Whisper 模型已准备" : "Whisper model is ready"
                store.addLog(store.statusMessage)
            } catch {
                store.whisperModelStatus = store.language == .zhHans ? "准备失败" : "Preparation failed"
                updatePreparationProgress(
                    status: store.language == .zhHans ? "模型准备失败" : "Model preparation failed",
                    download: store.whisperDownloadProgress,
                    preparation: store.whisperPreparationProgress
                )
                store.statusMessage = error.localizedDescription
                store.addLog("Whisper 模型准备失败：\(error.localizedDescription)")
                Notifier.shared.error(error.localizedDescription)
            }
        }
    }

    func deleteCurrentModel() {
        guard Self.isAppleSilicon else {
            store.whisperModelStatus = store.language == .zhHans ? "仅支持 M 芯片" : "Apple Silicon only"
            return
        }

        Task {
            do {
                updatePreparationProgress(
                    status: store.language == .zhHans ? "正在删除模型..." : "Deleting model...",
                    download: 0,
                    preparation: 0
                )
                let removedCount = try await transcriber.deleteModel(store.whisperModel)
                store.whisperModelStatus = store.language == .zhHans ? "未准备" : "Not ready"
                store.whisperDownloadProgress = 0
                store.whisperPreparationProgress = 0
                store.whisperPreparationStatus = store.language == .zhHans ? "模型已删除" : "Model deleted"
                store.statusMessage = store.language == .zhHans ? "已删除当前模型" : "Current model deleted"
                store.addLog("\(store.statusMessage)：\(removedCount) 个目录")
            } catch {
                store.statusMessage = error.localizedDescription
                store.whisperPreparationStatus = store.language == .zhHans ? "模型删除失败" : "Model deletion failed"
                store.addLog("Whisper 模型删除失败：\(error.localizedDescription)")
                Notifier.shared.error(error.localizedDescription)
            }
        }
    }

    private func start(targetApplication: NSRunningApplication?) {
        Task {
            do {
                guard try await requestMicrophoneAccess() else {
                    throw PMTError.api(store.language == .zhHans ? "需要开启麦克风权限。" : "Microphone permission is required.")
                }

                self.targetApplication = targetApplication
                let url = try recorder.start()
                isRecording = true
                activityIndicator.show(symbol: "👂")
                DictationSoundPlayer.shared.playStart()
                store.statusMessage = store.language == .zhHans ? "正在听写..." : "Dictating..."
                store.addLog("开始语音听写：\(url.lastPathComponent)")
            } catch {
                activityIndicator.hide()
                store.statusMessage = error.localizedDescription
                store.addLog("语音听写启动失败：\(error.localizedDescription)")
                Notifier.shared.error(error.localizedDescription)
            }
        }
    }

    private func stopAndProcess() {
        isRecording = false
        isProcessing = true
        activityIndicator.show(symbol: "✍️")
        store.statusMessage = store.language == .zhHans ? "正在整理语音..." : "Processing dictation..."

        Task {
            defer {
                Task { @MainActor in
                    self.activityIndicator.hide()
                    self.isProcessing = false
                }
            }

            do {
                let audioURL = try recorder.stop()
                DictationSoundPlayer.shared.playEnd()
                defer { try? FileManager.default.removeItem(at: audioURL) }
                store.addLog("录音结束，开始本地转写：\(audioURL.lastPathComponent)")
                let transcript = try await transcriber.transcribe(
                    audioURL: audioURL,
                    model: store.whisperModel,
                    metalAccelerationEnabled: store.whisperMetalAccelerationEnabled,
                    languageCode: whisperLanguageCode
                )
                store.addLog("本地转写完成：\(transcript.count) 个字符")

                let organized: String
                if shouldBypassRewrite(for: transcript) {
                    organized = transcript
                    store.addLog("语音内容较短，跳过远程结构化改写")
                } else {
                    store.addLog("开始请求远程模型进行结构化改写：\(store.selectedModel.isEmpty ? "未选择模型" : store.selectedModel)")
                    organized = try await store.rewrite(text: transcript)
                    store.addLog("远程模型结构化改写完成：\(organized.count) 个字符")
                }
                try await activateTargetApplication(targetApplication)
                try paste(organized)
                store.statusMessage = store.language == .zhHans ? "语音内容已插入" : "Dictation inserted"
            } catch {
                store.statusMessage = error.localizedDescription
                store.addLog("语音听写失败：\(error.localizedDescription)")
                Notifier.shared.error(error.localizedDescription)
            }
        }
    }

    private func shouldBypassRewrite(for text: String) -> Bool {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !$0.isWhitespace }
        return normalized.count < 8
    }

    private func paste(_ text: String) throws {
        let snapshot = ClipboardSnapshot()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw PMTError.clipboard("无法写入剪贴板。")
        }
        Keyboard.pressCommandKey(9)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            snapshot.restore()
            store.addLog("已恢复原剪贴板")
        }
    }

    private func activateTargetApplication(_ application: NSRunningApplication?) async throws {
        guard let application else {
            return
        }
        application.activate(options: [])
        try await Task.sleep(nanoseconds: 240_000_000)
    }

    private func requestMicrophoneAccess() async throws -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private var whisperLanguageCode: String {
        store.language == .zhHans ? "zh" : "en"
    }

    private func updatePreparationProgress(_ progress: WhisperPreparationProgress) {
        updatePreparationProgress(
            status: localizedPreparationStatus(progress.stage),
            download: progress.downloadProgress,
            preparation: progress.preparationProgress
        )
    }

    private func updatePreparationProgress(status: String, download: Double, preparation: Double) {
        store.whisperPreparationStatus = status
        store.whisperDownloadProgress = min(max(download, 0), 1)
        store.whisperPreparationProgress = min(max(preparation, 0), 1)
    }

    private func localizedPreparationStatus(_ stage: WhisperPreparationStage) -> String {
        switch (store.language, stage) {
        case (.zhHans, .downloadStarting):
            return "正在检查并下载模型..."
        case (.english, .downloadStarting):
            return "Checking and downloading model..."
        case (.zhHans, .downloading):
            return "正在下载模型..."
        case (.english, .downloading):
            return "Downloading model..."
        case (.zhHans, .downloaded):
            return "模型下载完成"
        case (.english, .downloaded):
            return "Model downloaded"
        case (.zhHans, .preparing):
            return "正在加载模型..."
        case (.english, .preparing):
            return "Loading model..."
        case (.zhHans, .ready):
            return "模型已准备完成"
        case (.english, .ready):
            return "Model is ready"
        }
    }

    static var isAppleSilicon: Bool {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }
        return machine == "arm64"
    }
}

private enum WhisperPreparationStage: Sendable {
    case downloadStarting
    case downloading
    case downloaded
    case preparing
    case ready
}

private struct WhisperPreparationProgress: Sendable {
    let stage: WhisperPreparationStage
    let downloadProgress: Double
    let preparationProgress: Double
}

private final class DictationRecorder {
    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var outputURL: URL?

    func start() throws -> URL {
        if engine.isRunning {
            try engine.stopRecording()
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PMT-Dictation-\(UUID().uuidString)")
            .appendingPathExtension("caf")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            do {
                try file.write(from: buffer)
            } catch {
                NSLog("PMT: 录音写入失败 %@", error.localizedDescription)
            }
        }

        audioFile = file
        outputURL = url
        engine.prepare()
        try engine.start()
        return url
    }

    func stop() throws -> URL {
        try engine.stopRecording()
        guard let outputURL else {
            throw PMTError.api("没有可用录音文件。")
        }
        audioFile = nil
        self.outputURL = nil
        return outputURL
    }
}

private extension AVAudioEngine {
    func stopRecording() throws {
        inputNode.removeTap(onBus: 0)
        stop()
    }
}

private actor LocalWhisperTranscriber {
    private var whisperKit: WhisperKit?
    private var loadedModel = ""
    private var loadedMetalAccelerationEnabled = true

    init(store: ConfigStore) {
    }

    func prepare(
        model rawModel: String,
        metalAccelerationEnabled: Bool,
        progressHandler: (@Sendable (WhisperPreparationProgress) -> Void)? = nil
    ) async throws {
        let model = rawModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "base" : rawModel
        if whisperKit != nil,
           loadedModel == model,
           loadedMetalAccelerationEnabled == metalAccelerationEnabled {
            progressHandler?(WhisperPreparationProgress(stage: .ready, downloadProgress: 1, preparationProgress: 1))
            return
        }

        let baseURL = try modelBaseURL()
        progressHandler?(WhisperPreparationProgress(stage: .downloadStarting, downloadProgress: 0, preparationProgress: 0))
        let modelFolder = try await WhisperKit.download(
            variant: model,
            downloadBase: baseURL
        ) { progress in
            progressHandler?(
                WhisperPreparationProgress(
                    stage: .downloading,
                    downloadProgress: progress.fractionCompleted,
                    preparationProgress: 0
                )
            )
        }
        progressHandler?(WhisperPreparationProgress(stage: .downloaded, downloadProgress: 1, preparationProgress: 0))

        let computeOptions = ModelComputeOptions(
            melCompute: metalAccelerationEnabled ? .cpuAndGPU : .cpuOnly,
            audioEncoderCompute: metalAccelerationEnabled ? .cpuAndGPU : .cpuOnly,
            textDecoderCompute: metalAccelerationEnabled ? .cpuAndGPU : .cpuOnly
        )
        progressHandler?(WhisperPreparationProgress(stage: .preparing, downloadProgress: 1, preparationProgress: 0.1))
        let kit = try await WhisperKit(
            downloadBase: baseURL,
            modelFolder: modelFolder.path,
            computeOptions: computeOptions,
            verbose: false,
            prewarm: false,
            load: false,
            download: false
        )
        progressHandler?(WhisperPreparationProgress(stage: .preparing, downloadProgress: 1, preparationProgress: 0.45))
        try await kit.loadModels()
        progressHandler?(WhisperPreparationProgress(stage: .ready, downloadProgress: 1, preparationProgress: 1))
        whisperKit = kit
        loadedModel = model
        loadedMetalAccelerationEnabled = metalAccelerationEnabled
    }

    func transcribe(audioURL: URL, model: String, metalAccelerationEnabled: Bool, languageCode: String) async throws -> String {
        try await prepare(model: model, metalAccelerationEnabled: metalAccelerationEnabled)
        guard let kit = whisperKit else {
            throw PMTError.api("Whisper 模型未加载。")
        }
        let results = try await kit.transcribe(
            audioPath: audioURL.path,
            decodeOptions: DecodingOptions(
                task: .transcribe,
                language: languageCode,
                skipSpecialTokens: true,
                withoutTimestamps: true
            )
        )
        let text = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw PMTError.api("没有识别到语音内容。")
        }
        return text
    }

    func deleteModel(_ rawModel: String) async throws -> Int {
        let model = rawModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "base" : rawModel
        if loadedModel == model {
            await whisperKit?.unloadModels()
            whisperKit = nil
            loadedModel = ""
        }

        let baseURL = try modelBaseURL()
        let candidates = try deletionCandidates(for: model, under: baseURL)
        var removedCount = 0
        for url in candidates {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                removedCount += 1
            }
        }
        return removedCount
    }

    private func modelBaseURL() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let url = appSupport.appendingPathComponent("PMT/WhisperModels", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func deletionCandidates(for model: String, under baseURL: URL) throws -> [URL] {
        let normalizedModel = model.lowercased()
        let modelRoot = baseURL.appendingPathComponent("models", isDirectory: true)
        guard FileManager.default.fileExists(atPath: modelRoot.path) else {
            return []
        }

        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: modelRoot,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var candidates: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: resourceKeys)
            guard values.isDirectory == true else {
                continue
            }

            let folderName = url.lastPathComponent.lowercased()
            if folderName == "whisper-\(normalizedModel)" ||
                folderName == "openai_whisper-\(normalizedModel)" {
                candidates.append(url)
                enumerator.skipDescendants()
            }
        }

        return candidates
    }
}
