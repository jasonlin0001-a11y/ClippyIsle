import SwiftUI

@main
struct ClippyIsleApp: App {
    // 1. 初始化 Singleton (因為 init 是空的，這裡幾乎不耗時)
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // 2. 注入環境變數供全 App 使用
                .environmentObject(subscriptionManager)
                // 3. 關鍵效能優化：在背景 Task 啟動監聽，完全不阻塞 Main Thread
                .task(priority: .background) {
                    subscriptionManager.start()
                }
        }
    }
}