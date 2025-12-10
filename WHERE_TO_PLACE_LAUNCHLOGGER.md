# WHERE to Place LaunchLogger Calls 📍

This guide tells you **exactly where** to place `LaunchLogger.log()` calls in your SwiftUI app to audit launch performance.

---

## 🎯 Quick Reference

Place logs at these critical points:

1. **App Entry Point** (`ClippyIsleApp.swift`)
2. **Subscription/IAP Manager** (if you have one)
3. **Main ContentView** (your root view)
4. **Data Managers** (ClipboardManager, CoreData, etc.)
5. **New Features** (any views/managers added recently)

---

## 1️⃣ ClippyIsleApp.swift (App Entry Point)

**Location:** Your `@main` App struct

### Where to Log:
```swift
@main
struct ClippyIsleApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    init() {
        LaunchLogger.log("ClippyIsleApp.init() - START")  // 👈 Place here
        // Your init code...
        LaunchLogger.log("ClippyIsleApp.init() - END")    // 👈 And here
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subscriptionManager)
                .task(priority: .background) {
                    LaunchLogger.log("SubscriptionManager.start() - Task BEGIN")  // 👈 Here
                    subscriptionManager.start()
                    LaunchLogger.log("SubscriptionManager.start() - Task END")    // 👈 Here
                }
                .onAppear {
                    LaunchLogger.log("ClippyIsleApp.body.WindowGroup - onAppear")  // 👈 Here
                }
        }
    }
}
```

### Why These Locations?
- **init() START/END:** Measures App initialization time
- **Task BEGIN/END:** Tracks when background tasks start
- **onAppear:** Shows when UI becomes visible

---

## 2️⃣ SubscriptionManager (or IAP Manager)

**Location:** Your subscription/IAP management class

### Where to Log:
```swift
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isPro: Bool = false
    @Published var products: [Product] = []
    
    private init() {
        LaunchLogger.log("SubscriptionManager.init() - START")  // 👈 Place here
        // Your init code (should be empty for performance!)
        LaunchLogger.log("SubscriptionManager.init() - END")    // 👈 And here
    }
    
    func start() {
        LaunchLogger.log("SubscriptionManager.start() - BEGIN")  // 👈 Place here
        
        // Spawn async tasks
        updateListenerTask = Task.detached(priority: .background) {
            for await result in StoreKit.Transaction.updates {
                await self.handle(transactionVerification: result)
            }
        }
        
        LaunchLogger.log("SubscriptionManager.start() - END (async tasks spawned)")  // 👈 Here
    }
}
```

### Why These Locations?
- **init() START/END:** Ensures manager init is fast (<5ms)
- **start() BEGIN/END:** Tracks async task spawning time

---

## 3️⃣ ContentView (Main View)

**Location:** Your main/root view

### Where to Log:
```swift
struct ContentView: View {
    @StateObject private var clipboardManager: ClipboardManager
    @StateObject private var speechManager = SpeechManager()
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    init() {
        LaunchLogger.log("ContentView.init() - START")  // 👈 Place here
        
        let manager = ClipboardManager()
        LaunchLogger.log("ContentView.init() - ClipboardManager created")  // 👈 After creation
        
        // ⚠️ DO NOT CALL initializeData() here - it blocks!
        _clipboardManager = StateObject(wrappedValue: manager)
        
        LaunchLogger.log("ContentView.init() - END")  // 👈 At the end
    }
    
    var body: some View {
        NavigationView { mainContent }
            .task(priority: .userInitiated) {
                LaunchLogger.log("ContentView.task - ClipboardManager.initializeData() - START")  // 👈 Here
                clipboardManager.initializeData()
                LaunchLogger.log("ContentView.task - ClipboardManager.initializeData() - END")    // 👈 Here
            }
            .onAppear {
                LaunchLogger.log("ContentView.onAppear - START")  // 👈 Place here
                configureNavigationBarAppearance()
                checkActivityStatus()
                // ... other setup
                LaunchLogger.log("ContentView.onAppear - END")    // 👈 And here
            }
    }
}
```

### Why These Locations?
- **init() START/END:** Critical for measuring view initialization
- **After manager creation:** Shows manager creation time
- **task START/END:** Tracks async data loading
- **onAppear START/END:** Shows when view setup happens

---

## 4️⃣ ClipboardManager (Data Manager)

**Location:** Your data management class

### Where to Log:
```swift
@MainActor
class ClipboardManager: ObservableObject {
    @Published var items: [ClipboardItem] = []
    
    public init() {
        LaunchLogger.log("ClipboardManager.init() - START")  // 👈 Place here
        
        // UserDefaults setup, etc.
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            LaunchLogger.log("ClipboardManager.init() - FAILED (App Group error)")  // 👈 Error case
            return
        }
        self.userDefaults = defaults
        
        LaunchLogger.log("ClipboardManager.init() - END")  // 👈 And here
    }
    
    public func initializeData() {
        LaunchLogger.log("ClipboardManager.initializeData() - START")  // 👈 Place here
        
        guard didInitializeSuccessfully else { 
            LaunchLogger.log("ClipboardManager.initializeData() - SKIPPED (init failed)")  // 👈 Skip case
            return 
        }
        
        loadItems()
        LaunchLogger.log("ClipboardManager.initializeData() - loadItems() completed")  // 👈 After each step
        
        cleanupItems()
        LaunchLogger.log("ClipboardManager.initializeData() - cleanupItems() completed")  // 👈 After each step
        
        if UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") { 
            Task { 
                LaunchLogger.log("ClipboardManager.initializeData() - CloudSync Task spawned")  // 👈 Task spawn
                await performCloudSync() 
            }
        }
        
        LaunchLogger.log("ClipboardManager.initializeData() - END")  // 👈 And here
    }
}
```

### Why These Locations?
- **init() START/END:** Measures manager creation time
- **initializeData() START/END:** Tracks data loading time
- **After each operation:** Identifies which step is slow (loadItems, cleanupItems, etc.)

---

## 5️⃣ New Features - LinkMetadataManager

**Location:** Your new feature managers

### Where to Log:
```swift
@MainActor
class LinkMetadataManager: ObservableObject {
    @Published var metadata: LPLinkMetadata?
    @Published var isLoading: Bool = false
    
    func fetchMetadata(for url: URL) {
        LaunchLogger.log("LinkMetadataManager.fetchMetadata() - START for URL: \(url)")  // 👈 Place here
        
        isLoading = true
        
        Task {
            do {
                let fetchedMetadata = try await provider.startFetchingMetadata(for: url)
                self.metadata = fetchedMetadata
                self.isLoading = false
                LaunchLogger.log("LinkMetadataManager.fetchMetadata() - SUCCESS for URL: \(url)")  // 👈 Success case
            } catch {
                self.error = error
                self.isLoading = false
                LaunchLogger.log("LinkMetadataManager.fetchMetadata() - FAILED for URL: \(url)")  // 👈 Error case
            }
        }
    }
}
```

### Why These Locations?
- **fetchMetadata() START:** Shows when network fetches begin
- **SUCCESS/FAILED:** Tracks fetch completion and failures
- Helps identify if new features are causing network storms during launch

---

## 6️⃣ New Features - InlineLinkPreview

**Location:** Your new UI components

### Where to Log:
```swift
struct InlineLinkPreview: View {
    let url: URL
    @StateObject private var metadataManager = LinkMetadataManager()
    
    var body: some View {
        VStack {
            // Preview content...
        }
        .onAppear {
            LaunchLogger.log("InlineLinkPreview.onAppear - START fetching metadata")  // 👈 Place here
            metadataManager.fetchMetadata(for: url)
        }
    }
}
```

### Why This Location?
- **onAppear:** Shows when inline previews start loading
- Helps identify if too many previews are loading during launch

---

## 7️⃣ SpeechRecognizer (Authorization Patterns)

**Location:** Any class that requests permissions

### Where to Log:
```swift
class SpeechRecognizer: ObservableObject {
    init() {
        LaunchLogger.log("SpeechRecognizer.init() - START requesting authorization")  // 👈 Place here
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus != .authorized { 
                    LaunchLogger.log("SpeechRecognizer.init() - Authorization DENIED")  // 👈 Denied case
                } else { 
                    LaunchLogger.log("SpeechRecognizer.init() - Authorization GRANTED")  // 👈 Granted case
                }
            }
        }
        
        LaunchLogger.log("SpeechRecognizer.init() - END (async authorization request sent)")  // 👈 And here
    }
}
```

### Why These Locations?
- **START/END:** Measures authorization request time
- **GRANTED/DENIED:** Shows when user responds

---

## 📋 Complete Launch Timeline Example

When you place logs correctly, you'll see output like this:

```
🚀 LaunchLogger: App start time initialized at 1234567890.123456
⏱️ [+0 ms] ClippyIsleApp.init() - START
⏱️ [+1 ms] SubscriptionManager.init() - START
⏱️ [+2 ms] SubscriptionManager.init() - END
⏱️ [+3 ms] ClippyIsleApp.init() - END
⏱️ [+5 ms] ContentView.init() - START
⏱️ [+7 ms] SpeechRecognizer.init() - START requesting authorization
⏱️ [+9 ms] SpeechRecognizer.init() - END (async authorization request sent)
⏱️ [+11 ms] ClipboardManager.init() - START
⏱️ [+14 ms] ClipboardManager.init() - END
⏱️ [+15 ms] ContentView.init() - ClipboardManager created
⏱️ [+16 ms] ContentView.init() - END (data initialization deferred)
⏱️ [+20 ms] ContentView.onAppear - START
⏱️ [+25 ms] ContentView.onAppear - END
⏱️ [+30 ms] ContentView.task - ClipboardManager.initializeData() - START
⏱️ [+32 ms] ClipboardManager.initializeData() - START
⏱️ [+102 ms] ClipboardManager.initializeData() - loadItems() completed
⏱️ [+112 ms] ClipboardManager.initializeData() - cleanupItems() completed
⏱️ [+114 ms] ClipboardManager.initializeData() - CloudSync Task spawned
⏱️ [+115 ms] ClipboardManager.initializeData() - END
⏱️ [+116 ms] ContentView.task - ClipboardManager.initializeData() - END
⏱️ [+200 ms] SubscriptionManager.start() - Task BEGIN
⏱️ [+202 ms] SubscriptionManager.start() - BEGIN
⏱️ [+205 ms] SubscriptionManager.start() - END (async tasks spawned)
⏱️ [+207 ms] SubscriptionManager.start() - Task END
```

---

## 🎯 General Rules

### Always Log:
1. **Start/End of init()** in all managers
2. **Start/End of body** in main views
3. **Start/End of onAppear** in root views
4. **Before/After major operations** (loadItems, fetchMetadata, etc.)
5. **Task/async boundaries** (when spawning background work)

### Never Log:
1. Inside tight loops (will spam console)
2. In every view's body (too much noise)
3. In computed properties that get called frequently
4. In gesture handlers (not relevant to launch)

---

## 🔍 What to Look For

After adding logs, run your app and look for:

1. **Large gaps between consecutive logs** (> 50ms = problem!)
2. **Heavy operations during init** (should be < 10ms)
3. **Network calls before 100ms mark** (should be deferred)
4. **Total time to first frame** (should be < 100ms)

---

## 💡 Pro Tips

### Tip 1: Log Hierarchically
```swift
// Good: Shows hierarchy
LaunchLogger.log("ClipboardManager.initializeData() - START")
LaunchLogger.log("ClipboardManager.initializeData() - loadItems() completed")
LaunchLogger.log("ClipboardManager.initializeData() - END")

// Bad: Unclear hierarchy
LaunchLogger.log("Starting initialization")
LaunchLogger.log("Loaded items")
LaunchLogger.log("Done")
```

### Tip 2: Use Descriptive Names
```swift
// Good: Clear what's happening
LaunchLogger.log("SubscriptionManager.start() - Task BEGIN")

// Bad: Vague
LaunchLogger.log("Starting")
```

### Tip 3: Log State Changes
```swift
// Good: Shows the outcome
LaunchLogger.log("SpeechRecognizer.init() - Authorization GRANTED")

// Bad: Just shows the attempt
LaunchLogger.log("Requested authorization")
```

---

## 📚 Related Documents

- **Using LaunchLogger:** See `LAUNCHLOGGER_USAGE.md`
- **Code Review Checklist:** See `CODE_REVIEW_CHECKLIST.md`
- **Performance Audit:** See `LAUNCH_PERFORMANCE_AUDIT.md`
- **Fix Applied:** See `LAUNCH_PERFORMANCE_FIX_APPLIED.md`

---

## ✅ Checklist: Did I Log Correctly?

- [ ] Logged at App init START/END
- [ ] Logged at ContentView init START/END
- [ ] Logged at Manager init START/END
- [ ] Logged at async task boundaries
- [ ] Logged major operations (loadItems, etc.)
- [ ] Logged before/after network calls
- [ ] Logs show hierarchical structure
- [ ] Log messages are descriptive

---

## 🎉 Summary

**The Golden Rule:** Log at boundaries where work happens or transitions from sync to async.

Place logs at:
- **init() START/END** (all managers and views)
- **Major operations** (loadItems, fetchData, etc.)
- **Async boundaries** (.task, Task.detached)
- **State transitions** (success, failure, granted, denied)

This gives you a complete timeline of your app's launch process! 🚀
