import SwiftUI

@main
struct ClippyIsleApp: App {
    // 1. 初始化 Singleton (因為 init 是空的，這裡幾乎不耗時)
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showSplash = true
    
    // Deep link handling state
    @State private var showPasswordPrompt = false
    @State private var inputPassword = ""
    @State private var pendingEncryptedData = ""
    @State private var pendingShareID = ""
    @State private var passwordErrorMessage: String?
    
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
                
                // Splash Screen Overlay
                if showSplash {
                    SplashScreenView(isPresented: $showSplash)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .alert("Password Required", isPresented: $showPasswordPrompt) {
                SecureField("Enter Password", text: $inputPassword)
                    .autocorrectionDisabled(true)
                    .textContentType(.password)
                Button("Unlock") {
                    unlockEncryptedShare()
                }
                Button("Cancel", role: .cancel) {
                    inputPassword = ""
                    pendingEncryptedData = ""
                    pendingShareID = ""
                }
            } message: {
                if let error = passwordErrorMessage {
                    Text("This share is password protected.\n\n\(error)")
                } else {
                    Text("This share is password protected. Please enter the password to access the shared items.")
                }
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        // Parse URL format: clippyisle://share/{shareID}
        guard url.scheme == "clippyisle",
              url.host == "share" else {
            print("⚠️ Invalid deep link format: \(url)")
            return
        }
        
        let shareID = url.pathComponents.dropFirst().joined(separator: "/")
        guard !shareID.isEmpty else {
            print("⚠️ No share ID found in URL: \(url)")
            return
        }
        
        print("📥 Processing deep link for share ID: \(shareID)")
        pendingShareID = shareID
        
        // Download items from Firebase
        FirebaseManager.shared.downloadItems(shareID: shareID) { result in
            switch result {
            case .success(let itemDicts):
                // Successfully downloaded unencrypted data
                saveSharedItems(itemDicts)
                
            case .failure(let error):
                if case ShareError.passwordRequired(let encryptedData) = error {
                    // Password is required, show password prompt
                    pendingEncryptedData = encryptedData
                    passwordErrorMessage = nil
                    showPasswordPrompt = true
                } else {
                    // Other error occurred
                    print("❌ Failed to download shared items: \(error.localizedDescription)")
                    passwordErrorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func unlockEncryptedShare() {
        guard !inputPassword.isEmpty else {
            passwordErrorMessage = "Please enter a password."
            showPasswordPrompt = true
            return
        }
        
        let result = FirebaseManager.shared.decryptSharedData(pendingEncryptedData, password: inputPassword)
        
        switch result {
        case .success(let itemDicts):
            saveSharedItems(itemDicts)
            // Clear state
            inputPassword = ""
            pendingEncryptedData = ""
            pendingShareID = ""
            passwordErrorMessage = nil
            
        case .failure(let error):
            // Show error and keep prompt open
            passwordErrorMessage = error.localizedDescription
            showPasswordPrompt = true
        }
    }
    
    private func saveSharedItems(_ itemDicts: [[String: Any]]) {
        let clipboardManager = ClipboardManager.shared
        var addedCount = 0
        
        for dict in itemDicts {
            // Parse the dictionary to create ClipboardItem
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let content = dict["content"] as? String,
                  let type = dict["type"] as? String,
                  let timestampInterval = dict["timestamp"] as? TimeInterval else {
                continue
            }
            
            let timestamp = Date(timeIntervalSince1970: timestampInterval)
            let isPinned = dict["isPinned"] as? Bool ?? false
            let isTrashed = dict["isTrashed"] as? Bool ?? false
            let displayName = dict["displayName"] as? String
            let filename = dict["filename"] as? String
            let tags = dict["tags"] as? [String]
            
            let item = ClipboardItem(
                id: id,
                content: content,
                type: type,
                filename: filename,
                timestamp: timestamp,
                isPinned: isPinned,
                displayName: displayName,
                isTrashed: isTrashed,
                tags: tags
            )
            
            // Check if item already exists
            if !clipboardManager.items.contains(where: { $0.id == item.id }) {
                clipboardManager.items.insert(item, at: 0)
                addedCount += 1
            }
        }
        
        if addedCount > 0 {
            clipboardManager.sortAndSave()
            print("✅ Added \(addedCount) shared items to clipboard")
        } else {
            print("ℹ️ No new items were added (all items already exist)")
        }
    }
        }
    }
}