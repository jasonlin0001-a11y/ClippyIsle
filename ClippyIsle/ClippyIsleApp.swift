import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

@main
struct ClippyIsleApp: App {
    // 1. 初始化 Singleton (因為 init 是空的，這裡幾乎不耗時)
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var pendingShareManager = PendingShareManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showSplash = true
    @State private var isAppReady = false
    
    // Password protection state for shared links
    @State private var pendingShareId: String?
    @State private var showPasswordPrompt = false
    @State private var passwordInput = ""
    @State private var showPasswordError = false
    @State private var pendingShareMetadata: ShareMetadata?
    
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
                    .environmentObject(authManager)
                    // 3. 關鍵效能優化：在背景 Task 啟動監聽，完全不阻塞 Main Thread
                    .task(priority: .background) {
                        LaunchLogger.log("SubscriptionManager.start() - Task BEGIN")
                        subscriptionManager.start()
                        LaunchLogger.log("SubscriptionManager.start() - Task END")
                    }
                    // 4. Anonymous Authentication on launch
                    .task(priority: .userInitiated) {
                        LaunchLogger.log("AuthenticationManager.signInAnonymously() - Task BEGIN")
                        do {
                            try await authManager.signInAnonymously()
                            LaunchLogger.log("AuthenticationManager.signInAnonymously() - Task END (success)")
                        } catch {
                            LaunchLogger.log("AuthenticationManager.signInAnonymously() - Task END (error: \(error.localizedDescription))")
                        }
                    }
                    .onAppear {
                        LaunchLogger.log("ClippyIsleApp.body.WindowGroup - onAppear")
                    }
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }
                    // Password prompt alert for protected shares
                    .alert("Password Required", isPresented: $showPasswordPrompt) {
                        SecureField("Enter password", text: $passwordInput)
                        Button("Cancel", role: .cancel) {
                            pendingShareId = nil
                            passwordInput = ""
                            pendingShareMetadata = nil
                        }
                        Button("Submit") {
                            submitPassword()
                        }
                    } message: {
                        if let metadata = pendingShareMetadata {
                            if let nickname = metadata.sharerNickname {
                                Text("This share from \(nickname) is password protected. Please enter the password to access \(metadata.itemCount) item(s).")
                            } else {
                                Text("This share is password protected. Please enter the password to access \(metadata.itemCount) item(s).")
                            }
                        } else {
                            Text("This share is password protected.")
                        }
                    }
                    // Password error alert
                    .alert("Incorrect Password", isPresented: $showPasswordError) {
                        Button("Try Again") {
                            passwordInput = ""
                            showPasswordPrompt = true
                        }
                        Button("Cancel", role: .cancel) {
                            pendingShareId = nil
                            passwordInput = ""
                            pendingShareMetadata = nil
                        }
                    } message: {
                        Text("The password you entered is incorrect. Please try again.")
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
    
    // MARK: - Password Submission
    private func submitPassword() {
        guard let shareId = pendingShareId else { return }
        downloadSharedItems(shareId: shareId, password: passwordInput)
        passwordInput = ""
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
        
        print("📥 Checking shared items with ID: \(shareId)")
        
        // First, check if the share requires a password
        FirebaseManager.shared.getShareMetadata(shareId: shareId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let metadata):
                    print("🔐 handleDeepLink: metadata.hasPassword=\(metadata.hasPassword)")
                    if metadata.hasPassword {
                        // Store the share ID and show password prompt
                        self.pendingShareId = shareId
                        self.pendingShareMetadata = metadata
                        self.showPasswordPrompt = true
                        print("🔐 Showing password prompt for share: \(shareId)")
                    } else {
                        // No password required, download directly
                        print("🔓 No password required, downloading directly: \(shareId)")
                        self.downloadSharedItems(shareId: shareId, password: nil)
                    }
                case .failure(let error):
                    print("❌ Failed to get share metadata: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Download Shared Items
    private func downloadSharedItems(shareId: String, password: String?) {
        let isPasswordProtected = password != nil
        print("📥 Loading shared items with ID: \(shareId), password provided: \(isPasswordProtected)")
        
        // Download raw items data from Firebase
        FirebaseManager.shared.downloadItems(byShareId: shareId, password: password) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let itemsData):
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
                    
                    // Clear pending state
                    self.pendingShareId = nil
                    self.pendingShareMetadata = nil
                    
                    if pendingItems.isEmpty {
                        print("⚠️ No valid items found in shared data")
                    } else {
                        // Add to notification center for user to select which items to import
                        // Password verification has already happened at this point
                        print("📥 Loaded \(pendingItems.count) shared item(s), adding to message center")
                        Task { @MainActor in
                            NotificationManager.shared.addNotification(items: pendingItems, source: .deepLink)
                        }
                    }
                    
                case .failure(let error):
                    // Check if it's a password error by examining the error code
                    let nsError = error as NSError
                    if nsError.domain == "FirebaseManager" && nsError.code == 403 {
                        // Incorrect password error
                        self.showPasswordError = true
                    } else {
                        print("❌ Failed to load shared items: \(error.localizedDescription)")
                        self.pendingShareId = nil
                        self.pendingShareMetadata = nil
                    }
                }
            }
        }
    }
}