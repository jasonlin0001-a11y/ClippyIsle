import SwiftUI
import FirebaseCore

@main
struct ClippyIsleApp: App {
    // 1. 初始化 Singleton (因為 init 是空的，這裡幾乎不耗時)
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showSplash = true
    
    init() {
        LaunchLogger.log("ClippyIsleApp.init() - START")
        // Configure Firebase
        FirebaseApp.configure()
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
                        handleDeepLink(url)
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
    
    // MARK: - Deep Link Handling
    private func handleDeepLink(_ url: URL) {
        // Check if this is our import URL scheme: ccisle://import?id=DOC_ID
        guard url.scheme == "ccisle",
              url.host == "import" else {
            print("⚠️ Unrecognized deep link: \(url)")
            return
        }
        
        // Extract the 'id' query parameter
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let idItem = queryItems.first(where: { $0.name == "id" }),
              let shareId = idItem.value else {
            print("⚠️ No 'id' parameter found in deep link")
            return
        }
        
        print("📥 Importing shared items with ID: \(shareId)")
        
        // Download items from Firebase
        FirebaseManager.shared.downloadItems(byShareId: shareId) { result in
            switch result {
            case .success(let items):
                DispatchQueue.main.async {
                    // Save each item to ClipboardManager
                    let clipboardManager = ClipboardManager.shared
                    for item in items {
                        clipboardManager.addNewItem(content: item.content, type: item.type, fileData: item.fileData)
                    }
                    print("✅ Successfully imported \(items.count) item(s)")
                }
            case .failure(let error):
                print("❌ Failed to import items: \(error.localizedDescription)")
            }
        }
    }
}