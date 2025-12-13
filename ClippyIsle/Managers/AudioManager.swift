import Foundation
import AVFoundation
import Speech
import MediaPlayer
import Combine // 必須加入，修正 ObservableObject 錯誤
import SwiftUI // 建議加入，修正潛在的 UI 相關引用

// MARK: - Audio Manager
class AudioManager {
    static let shared = AudioManager()
    private var lastScenario: AudioScenario?

    private init() {}

    enum AudioScenario {
        case speechPlayback
        case webViewPlayback
        case speechRecognition
        case idle
    }

    func setup(for scenario: AudioScenario) {
        let session = AVAudioSession.sharedInstance()
        do {
            if lastScenario == .webViewPlayback && scenario == .speechPlayback {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            }
            
            switch scenario {
            case .speechPlayback:
                try session.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetoothA2DP, .allowAirPlay])
            case .webViewPlayback:
                try session.setCategory(.playback, mode: .moviePlayback, options: [])
            case .speechRecognition:
                try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            case .idle:
                try session.setActive(false, options: .notifyOthersOnDeactivation)
                lastScenario = nil
                return
            }
            try session.setActive(true)
            lastScenario = scenario
        } catch {
            print("❌ AudioManager: 為 \(scenario) 設定 audio session 失敗。錯誤: \(error.localizedDescription)")
        }
    }

    func deactivate() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            lastScenario = nil
            print("✅ AudioManager: Audio session 已停用且 NowPlayingInfo 已清除。")
        } catch {
            print("❌ AudioManager: 停用 audio session 失敗。錯誤: \(error.localizedDescription)")
        }
    }
}

// MARK: - Speech Recognizer
class SpeechRecognizer: ObservableObject {
    @Published var transcript: String = ""
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-TW"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        LaunchLogger.log("SpeechRecognizer.init() - START requesting authorization")
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus != .authorized { 
                    print("❌ 語音辨識權限未授權。")
                    LaunchLogger.log("SpeechRecognizer.init() - Authorization DENIED")
                }
                else { 
                    print("✅ 語音辨識權限已授權。")
                    LaunchLogger.log("SpeechRecognizer.init() - Authorization GRANTED")
                }
            }
        }
        LaunchLogger.log("SpeechRecognizer.init() - END (async authorization request sent)")
    }
    
    func startTranscribing() {
        guard !audioEngine.isRunning else { stopTranscribing(); return }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("❌ 無法開始，語音辨識權限未授權。")
            return
        }
        
        do {
            AudioManager.shared.setup(for: .speechRecognition)
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else { fatalError("無法建立辨識請求") }
            recognitionRequest.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                if let result {
                    DispatchQueue.main.async { self?.transcript = result.bestTranscription.formattedString }
                }
                if error != nil { self?.stopTranscribing() }
            }

            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            print("🎙️ 語音辨識已啟動...")

        } catch {
            print("❌ 語音辨識啟動失敗: \(error)")
            stopTranscribing()
        }
    }

    func stopTranscribing() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        
        AudioManager.shared.deactivate()
        print("🛑 語音辨識已停止。")
    }
}