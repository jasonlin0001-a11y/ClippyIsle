import SwiftUI

@main
struct ClippyIsleApp: App {
    // 1. 初始化 Singleton (因為 init 是空的，這裡幾乎不耗時)
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showSplash = true
    @State private var showImportAlert = false
    @State private var importAlertMessage = ""
    
    init() {
        LaunchLogger.log("ClippyIsleApp.init() - START")
        // App init完成
        LaunchLogger.log("ClippyIsleApp.init() - END")
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    // 2. 注入環境變數供全 App 使用
                    .environmentObject(subscriptionManager)
                    // 3. 關鍵效能優化：在背景 Task 啟動監聽，完全不阻塞 Main Thread
                    .task(priority: .background) {
                        LaunchLogger.log("SubscriptionManager.start() - Task BEGIN")
                        subscriptionManager.start()
                        LaunchLogger.log("SubscriptionManager.start() - Task END")
                    }
                    .onAppear {
                        LaunchLogger.log("ClippyIsleApp.body.WindowGroup - onAppear")
                    }
                    .onOpenURL { url in
                        handleIncomingURL(url)
                    }
                    .alert("Import Result", isPresented: $showImportAlert) {
                        Button("OK") {}
                    } message: {
                        Text(importAlertMessage)
                    }
                
                // Splash Screen Overlay
                if showSplash {
                    SplashScreenView(isPresented: $showSplash)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Handle ccisle:// URL scheme for import
        if url.scheme == "ccisle" {
            Task { @MainActor in
                do {
                    let count = try ClipboardManager.shared.importFromURLScheme(url.absoluteString)
                    importAlertMessage = "Import successful!\nAdded \(count) new items."
                } catch {
                    importAlertMessage = "Import failed.\nError: \(error.localizedDescription)"
                }
                showImportAlert = true
            }
        }
    }
}