import WebKit
import Combine
import AVFoundation

// MARK: - Global Web Manager
class WebManager: ObservableObject {
    static let shared = WebManager()
    
    // The single, persistent WebView instance
    let webView: WKWebView
    
    // Track which item is currently loaded to restore context
    @Published var currentItemID: UUID?
    @Published var isPlaying: Bool = false
    
    private init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        // Important: Allow background audio
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        
        self.webView = WKWebView(frame: .zero, configuration: config)
    }
    
    func load(request: URLRequest, for itemID: UUID) {
        // Only reload if it's a different URL or item
        if currentItemID != itemID || webView.url != request.url {
            currentItemID = itemID
            webView.load(request)
        }
    }
    
    func stopAndClear() {
        webView.stopLoading()
        webView.load(URLRequest(url: URL(string: "about:blank")!))
        currentItemID = nil
        isPlaying = false
        AudioManager.shared.deactivate()
    }
}