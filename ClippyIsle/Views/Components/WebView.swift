import SwiftUI
import WebKit

// MARK: - WebView
enum WebViewState: Equatable {
    case idle, loading(URLRequest), success(URL?), failed(Error)
    static func == (lhs: WebViewState, rhs: WebViewState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case let (.loading(lhsRequest), .loading(rhsRequest)): return lhsRequest == rhsRequest
        case let (.success(lhsURL), .success(rhsURL)): return lhsURL == rhsURL
        case let (.failed(lhsError), .failed(rhsError)): return lhsError.localizedDescription == rhsError.localizedDescription
        default: return false
        }
    }
}

struct WebView: UIViewRepresentable {
    @Binding var state: WebViewState
    let onTextExtracted: (String) -> Void
    let onWebViewCreated: (WKWebView) -> Void
    let onURLChanged: (URL?) -> Void
    // **NEW**: ID to associate with the manager
    let itemID: UUID 
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: WebView
        var lastRequest: URLRequest?

        init(_ parent: WebView) { self.parent = parent; super.init() }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "readPageHandler", let text = message.body as? String { parent.onTextExtracted(text) }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) { decisionHandler(.allow) }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { 
            parent.state = .success(webView.url)
            parent.onURLChanged(webView.url) 
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.code != 102 && nsError.code != -999 { parent.state = .failed(error) }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.code != 102 && nsError.code != -999 { parent.state = .failed(error) }
        }
    }
    
    func makeUIView(context: Context) -> WKWebView {
        // **MODIFIED**: Get the shared instance instead of creating new
        let webView = WebManager.shared.webView
        
        // Re-attach delegates (since they might have been overwritten by another view)
        webView.navigationDelegate = context.coordinator
        
        // Re-inject scripts if needed (simplified for stability)
        let js = "function onPlayerError(event){window.webkit.messageHandlers.onPlayerError.postMessage({'code':event.data});}"
        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
        
        // Ensure script handlers are registered safely
        let controller = webView.configuration.userContentController
        // Remove old handlers to avoid duplicates/crashes
        controller.removeScriptMessageHandler(forName: "readPageHandler")
        controller.add(context.coordinator, name: "readPageHandler")
        
        self.onWebViewCreated(webView)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if case .loading(let request) = state {
            if request != context.coordinator.lastRequest {
                context.coordinator.lastRequest = request
                uiView.customUserAgent = request.value(forHTTPHeaderField: "User-Agent")
                
                // **MODIFIED**: Use Manager to load
                WebManager.shared.load(request: request, for: itemID)
            }
        }
    }
}