import WebKit
import Combine
import AVFoundation

// MARK: - Global Web Manager
class WebManager: ObservableObject {
    static let shared = WebManager()
    
    // Track which item is currently loaded to restore context
    @Published var currentItemID: UUID?
    @Published var isPlaying: Bool = false
    
    // ✅ PERFORMANCE FIX: Lazy initialization - WKWebView only created when accessed
    private var _webView: WKWebView?
    var webView: WKWebView {
        if let existingWebView = _webView {
            return existingWebView
        }
        
        LaunchLogger.log("WebManager.webView - LAZY INIT START")
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        // Important: Allow background audio
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        
        let newWebView = WKWebView(frame: .zero, configuration: config)
        _webView = newWebView
        LaunchLogger.log("WebManager.webView - LAZY INIT END")
        return newWebView
    }
    
    private init() {
        LaunchLogger.log("WebManager.init() - START (empty init)")
        // ⚠️ PERFORMANCE FIX: Empty init - WKWebView NOT created here
        // WebView will be lazily created only when first accessed
        LaunchLogger.log("WebManager.init() - END")
    }
    
    func load(request: URLRequest, for itemID: UUID) {
        LaunchLogger.log("WebManager.load() - START for itemID: \(itemID)")
        // Only reload if it's a different URL or item
        if currentItemID != itemID || webView.url != request.url {
            currentItemID = itemID
            webView.load(request)
        }
        LaunchLogger.log("WebManager.load() - END")
    }
    
    func stopAndClear() {
        LaunchLogger.log("WebManager.stopAndClear() - START")
        // Only access webView if it was already created
        guard let existingWebView = _webView else {
            LaunchLogger.log("WebManager.stopAndClear() - SKIPPED (webView never created)")
            currentItemID = nil
            isPlaying = false
            return
        }
        
        existingWebView.stopLoading()
        existingWebView.load(URLRequest(url: URL(string: "about:blank")!))
        currentItemID = nil
        isPlaying = false
        AudioManager.shared.deactivate()
        LaunchLogger.log("WebManager.stopAndClear() - END")
    }
}