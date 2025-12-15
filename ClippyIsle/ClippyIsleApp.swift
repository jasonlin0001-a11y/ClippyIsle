import SwiftUI
import FirebaseCore
import FirebaseFirestore

@main
struct ClippyIsleApp: App {
    // 1. 初始化 Singleton (因為 init 是空的，這裡幾乎不耗時)
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var pendingShareManager = PendingShareManager.shared
    @State private var showSplash = true
    @State private var isAppReady = false
    
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
                ContentView(isAppReady: $isAppReady)
                    // 2. 注入環境變數供全 App 使用
                    .environmentObject(subscriptionManager)
                    .environmentObject(pendingShareManager)
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
                    SplashScreenView(isPresented: $showSplash, isAppReady: $isAppReady)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
        }
    }
    
    // MARK: - Deep Link Handling
    private func handleDeepLink(_ url: URL) {
        var shareId: String?
        
        // Handle Firebase Hosting URL: https://cc-isle.web.app/share?id=DOC_ID
        if url.scheme == "https" && url.host == "cc-isle.web.app" && url.path == "/share" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems,
               let idItem = queryItems.first(where: { $0.name == "id" }) {
                shareId = idItem.value
            }
        }
        // Handle legacy deep link: ccisle://import?id=DOC_ID
        else if url.scheme == "ccisle" && url.host == "import" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems,
               let idItem = queryItems.first(where: { $0.name == "id" }) {
                shareId = idItem.value
            }
        }
        
        guard let shareId = shareId else {
            print("⚠️ Unrecognized deep link or missing 'id' parameter: \(url)")
            return
        }
        
        print("📥 Loading shared items with ID: \(shareId)")
        
        // Download raw items data from Firebase
        FirebaseManager.shared.downloadItems(byShareId: shareId) { result in
            switch result {
            case .success(let itemsData):
                DispatchQueue.main.async {
                    // Parse items data and create ClipboardItem instances for preview
                    var pendingItems: [ClipboardItem] = []
                    
                    for itemData in itemsData {
                        // Parse raw data and create ClipboardItem instances
                        guard let content = itemData["content"] as? String,
                              let type = itemData["type"] as? String,
                              let _ = itemData["timestamp"] as? Timestamp else {
                            print("⚠️ Skipping invalid item data")
                            continue
                        }
                        
                        // Create item for preview (will create new ID on actual import)
                        let item = ClipboardItem(
                            content: content,
                            type: type,
                            filename: itemData["filename"] as? String,
                            timestamp: Date(),
                            isPinned: itemData["isPinned"] as? Bool ?? false,
                            displayName: itemData["displayName"] as? String,
                            isTrashed: false, // Don't import trashed items
                            tags: itemData["tags"] as? [String],
                            fileData: nil
                        )
                        
                        pendingItems.append(item)
                    }
                    
                    if pendingItems.isEmpty {
                        print("⚠️ No valid items found in shared data")
                    } else {
                        print("📥 Loaded \(pendingItems.count) shared item(s), showing selection dialog")
                        // Show selection dialog instead of auto-importing
                        self.pendingShareManager.setPendingItems(pendingItems)
                    }
                }
            case .failure(let error):
                print("❌ Failed to load shared items: \(error.localizedDescription)")
            }
        }
    }
}