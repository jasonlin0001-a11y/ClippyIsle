import SwiftUI
import AVFoundation
import Combine
import MediaPlayer
import CryptoKit

class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    nonisolated(unsafe) private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var playerTimer: Timer?
    
    private var currentSpeakingText: String?
    // Made public(set) so views can read it but only manager sets it, or internal is fine
    @Published var currentTitle: String = ""
    
    // Cache progress per unique ID (Item ID or Item+URL)
    private var progressCache: [String: TimeInterval] = [:]
    
    @Published var isSpeaking: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentItemID: UUID?
    
    @Published var currentPlayingURL: URL?
    
    @Published var speechRate: Double = 0.5 {
        didSet {
            if let player = audioPlayer, player.isPlaying {
                player.rate = Float(speechRate * 2.0)
            }
        }
    }
    @Published var highlightedRange: NSRange?
    @Published var elapsedTime: TimeInterval = 0
    @Published var duration: TimeInterval = 1
    @Published var forceLanguage: String? = nil
    @Published var preferLocalFile: Bool = true 
    
    private var webTextCache: [String: String] = [:]
    private let fileManager = FileManager.default
    
    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio Session Error: \(error)")
        }
    }
    
    // MARK: - Helper: Generate Unique Key
    private func getUniqueKey(itemID: UUID, url: URL?) -> String {
        guard let url = url else { return itemID.uuidString }
        let urlString = url.absoluteString
        let urlHash = SHA256.hash(data: Data(urlString.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        return "\(itemID.uuidString)_\(urlHash.prefix(16))"
    }

    // MARK: - Public API
    
    func setWebText(_ text: String, for itemID: UUID, url: URL? = nil) {
        let key = getUniqueKey(itemID: itemID, url: url)
        webTextCache[key] = text
    }
    
    func getWebText(for itemID: UUID, url: URL? = nil) -> String? {
        let key = getUniqueKey(itemID: itemID, url: url)
        return webTextCache[key]
    }
    
    func removeWebText(for itemID: UUID, url: URL? = nil) {
        let key = getUniqueKey(itemID: itemID, url: url)
        webTextCache.removeValue(forKey: key)
    }

    func play(text: String, title: String, itemID: UUID, url: URL? = nil, fromLocation: Int? = nil) {
        stop()
        currentItemID = itemID
        currentPlayingURL = url
        currentSpeakingText = text
        currentTitle = title
        
        setupAudioSession()
        
        let startTime = Double(fromLocation ?? 0)
        
        if preferLocalFile, let fileURL = getLocalAudioFileURL(for: itemID, url: url), fileManager.fileExists(atPath: fileURL.path) {
            playLocalFile(url: fileURL, fromTime: startTime)
        } else {
            playTTS(text: text)
        }
        
        updateNowPlayingInfo()
    }
    
    // **NEW**: Method for AudioFileManagerView to play arbitrary files
    func playExistingFile(url: URL, title: String) {
        stop()
        
        // Set a temporary ID so the UI knows something is playing
        let tempID = UUID()
        currentItemID = tempID
        currentTitle = title
        currentSpeakingText = "Audio File Preview" // Placeholder
        
        setupAudioSession()
        
        // Directly play the file
        playLocalFile(url: url, fromTime: 0)
        
        updateNowPlayingInfo()
    }
    
    func stop() {
        if let id = currentItemID {
            let key = getUniqueKey(itemID: id, url: currentPlayingURL)
            progressCache[key] = elapsedTime
        }
        
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        if let player = audioPlayer {
            player.stop()
            audioPlayer = nil
            playerTimer?.invalidate()
            playerTimer = nil
        }
        
        isSpeaking = false
        isPaused = false
        highlightedRange = nil
        currentItemID = nil
        currentPlayingURL = nil
        elapsedTime = 0
        currentSpeakingText = nil
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        AudioManager.shared.deactivate()
    }

    func pause() {
        if let id = currentItemID {
            let key = getUniqueKey(itemID: id, url: currentPlayingURL)
            progressCache[key] = elapsedTime
        }
        
        if synthesizer.isSpeaking {
            if synthesizer.pauseSpeaking(at: .immediate) { isPaused = true; isSpeaking = false }
        } else if let player = audioPlayer, player.isPlaying {
            player.pause()
            isPaused = true; isSpeaking = false
            playerTimer?.invalidate()
        }
        updateNowPlayingInfo()
    }

    func resume() {
        setupAudioSession()
        if synthesizer.isPaused {
            if synthesizer.continueSpeaking() { isSpeaking = true; isPaused = false }
        } else if let player = audioPlayer, !player.isPlaying {
            player.play()
            startPlayerTimer()
            isSpeaking = true; isPaused = false
        }
        updateNowPlayingInfo()
    }
    
    func seek(to time: TimeInterval) {
        if let player = audioPlayer {
            player.currentTime = time
            elapsedTime = time
            updateHighlightForFilePlayback(currentTime: time, duration: player.duration)
            updateNowPlayingInfo()
        }
    }
    
    func handleRateChange() { }

    func getProgress(for itemID: UUID, url: URL? = nil) -> Int? {
        let key = getUniqueKey(itemID: itemID, url: url)
        if let cachedTime = progressCache[key] { return Int(cachedTime) }
        return nil
    }
    
    // MARK: - Audio File Generation
    
    func hasAudioFile(for itemID: UUID, url: URL? = nil) -> Bool {
        guard let fileURL = getLocalAudioFileURL(for: itemID, url: url) else { return false }
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    func deleteAudioFile(for itemID: UUID, url: URL? = nil) {
        guard let fileURL = getLocalAudioFileURL(for: itemID, url: url) else { return }
        try? fileManager.removeItem(at: fileURL)
        let key = getUniqueKey(itemID: itemID, url: url)
        progressCache.removeValue(forKey: key)
        print("🗑️ Deleted local audio file for key: \(key)")
    }
    
    func generateAudioFile(text: String, itemID: UUID, url: URL? = nil) async throws {
        guard let fileURL = getLocalAudioFileURL(for: itemID, url: url) else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: forceLanguage ?? "zh-TW")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        var output: AVAudioFile?
        return try await withCheckedThrowingContinuation { continuation in
            synthesizer.write(utterance) { buffer in
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }
                do {
                    if output == nil {
                        output = try AVAudioFile(forWriting: fileURL, settings: pcmBuffer.format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
                    }
                    try output?.write(from: pcmBuffer)
                } catch {
                    continuation.resume(throwing: error); return
                }
            }
             continuation.resume()
        }
    }
    
    private func getLocalAudioFileURL(for itemID: UUID, url: URL? = nil) -> URL? {
        guard let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let folder = cacheDir.appendingPathComponent("LocalAudio")
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        
        let uniqueFilename = getUniqueKey(itemID: itemID, url: url)
        return folder.appendingPathComponent("\(uniqueFilename).caf")
    }

    // MARK: - Internal Playback Logic
    
    private func playLocalFile(url: URL, fromTime: Double) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.enableRate = true
            audioPlayer?.rate = Float(speechRate > 0.6 ? 1.5 : (speechRate < 0.4 ? 0.75 : 1.0))
            audioPlayer?.currentTime = fromTime
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            duration = audioPlayer?.duration ?? 1
            isSpeaking = true
            isPaused = false
            startPlayerTimer()
        } catch {
            print("Failed to play local file: \(error)")
        }
    }
    
    private func startPlayerTimer() {
        playerTimer?.invalidate()
        playerTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.elapsedTime = player.currentTime
            self.updateHighlightForFilePlayback(currentTime: player.currentTime, duration: player.duration)
            
            if let id = self.currentItemID {
                let key = self.getUniqueKey(itemID: id, url: self.currentPlayingURL)
                self.progressCache[key] = self.elapsedTime
            }
            
            if Int(player.currentTime) % 5 == 0 { self.updateNowPlayingInfo() }
        }
    }
    
    private func updateHighlightForFilePlayback(currentTime: TimeInterval, duration: TimeInterval) {
        guard let text = currentSpeakingText, !text.isEmpty, duration > 0 else { return }
        let rawPercentage = currentTime / duration
        let adjustedPercentage = rawPercentage > 0.9 ? 1.0 : rawPercentage
        let estimatedLocation = Int(Double(text.count) * adjustedPercentage)
        let clampedLocation = min(max(0, estimatedLocation), text.count - 1)
        
        let nsText = text as NSString
        var paraStart = 0
        var paraEnd = 0
        nsText.getParagraphStart(&paraStart, end: &paraEnd, contentsEnd: nil, for: NSRange(location: clampedLocation, length: 0))
        
        let distanceToParaEnd = paraEnd - clampedLocation
        if distanceToParaEnd < 5 && paraEnd < text.count {
             var nextParaStart = 0
             var nextParaEnd = 0
             nsText.getParagraphStart(&nextParaStart, end: &nextParaEnd, contentsEnd: nil, for: NSRange(location: paraEnd, length: 0))
             if nextParaEnd > nextParaStart {
                 paraStart = nextParaStart
                 paraEnd = nextParaEnd
             }
        }
        let newRange = NSRange(location: paraStart, length: paraEnd - paraStart)
        if highlightedRange != newRange { highlightedRange = newRange }
    }
    
    private func playTTS(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        if let forced = forceLanguage {
            utterance.voice = AVSpeechSynthesisVoice(language: forced)
        } else {
             if let lang = NSLinguisticTagger.dominantLanguage(for: text) {
                 if lang == "zh" || lang.starts(with: "zh-") { utterance.voice = AVSpeechSynthesisVoice(language: "zh-TW") }
                 else { utterance.voice = AVSpeechSynthesisVoice(language: lang) }
             } else { utterance.voice = AVSpeechSynthesisVoice(language: "zh-TW") }
        }
        utterance.rate = Float(speechRate)
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        self.duration = Double(text.count) * 0.2 
        synthesizer.speak(utterance)
        isSpeaking = true
        isPaused = false
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] _ in self?.resume(); return .success }
        commandCenter.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
                return .success
            }
            return .commandFailed
        }
    }
    
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentTitle
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isSpeaking ? (audioPlayer?.rate ?? 1.0) : 0.0
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // MARK: - Delegates
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { stop() }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let nsText = utterance.speechString as NSString
        var paraStart = 0
        var paraEnd = 0
        nsText.getParagraphStart(&paraStart, end: &paraEnd, contentsEnd: nil, for: characterRange)
        let newRange = NSRange(location: paraStart, length: paraEnd - paraStart)
        if highlightedRange != newRange { highlightedRange = newRange }
        
        let progress = Double(characterRange.location) / Double(utterance.speechString.count)
        elapsedTime = progress * duration
        if let id = currentItemID {
            let key = getUniqueKey(itemID: id, url: currentPlayingURL)
            progressCache[key] = elapsedTime
        }
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { 
        if let id = currentItemID { 
            let key = getUniqueKey(itemID: id, url: currentPlayingURL)
            progressCache.removeValue(forKey: key)
        }
        stop() 
    }
}