# LaunchLogger Usage Guide

## Overview
The `LaunchLogger` class has been added to help you identify launch performance bottlenecks in ClippyIsle. This guide explains where logging has been added and how to interpret the results.

## What is LaunchLogger?

`LaunchLogger` is a simple utility class that tracks time elapsed since your app started. It prints timestamped log messages to help you identify which parts of your app initialization are taking the most time.

### Location
`ClippyIsle/Utilities/LaunchLogger.swift`

### Usage
```swift
LaunchLogger.log("Description of what's happening")
```

This will print:
```
⏱️ [+123 ms] Description of what's happening
```

Where `123 ms` is the time elapsed since app launch.

---

## Where Logs Have Been Added

### 1. ClippyIsleApp.swift

**In `init()`:**
```swift
init() {
    LaunchLogger.log("ClippyIsleApp.init() - START")
    // App init完成
    LaunchLogger.log("ClippyIsleApp.init() - END")
}
```

**In `body`:**
```swift
var body: some Scene {
    LaunchLogger.log("ClippyIsleApp.body - START")
    WindowGroup {
        ZStack {
            ContentView()
                .task(priority: .background) {
                    LaunchLogger.log("SubscriptionManager.start() - Task BEGIN")
                    subscriptionManager.start()
                    LaunchLogger.log("SubscriptionManager.start() - Task END")
                }
            // ...
        }
    }
    .onAppear {
        LaunchLogger.log("ClippyIsleApp.body.WindowGroup - onAppear")
    }
}
```

**What to look for:**
- Time between `ClippyIsleApp.init() - START` and `END` should be < 5ms
- Time from `ClippyIsleApp.body - START` to `ContentView.init() - START` shows SwiftUI setup overhead

---

### 2. SubscriptionManager.swift

**In `init()`:**
```swift
private init() {
    LaunchLogger.log("SubscriptionManager.init() - START")
    // Init完成
    LaunchLogger.log("SubscriptionManager.init() - END")
}
```

**In `start()`:**
```swift
func start() {
    LaunchLogger.log("SubscriptionManager.start() - BEGIN")
    // Spawn async tasks...
    LaunchLogger.log("SubscriptionManager.start() - END (async tasks spawned)")
}
```

**What to look for:**
- Init should be < 5ms (it's empty, as per performance best practice)
- `start()` should be < 10ms (just spawning tasks, not doing work)

---

### 3. ContentView.swift

**In `init()`:**
```swift
init() { 
    LaunchLogger.log("ContentView.init() - START")
    let manager = ClipboardManager()
    LaunchLogger.log("ContentView.init() - ClipboardManager created")
    manager.initializeData()
    LaunchLogger.log("ContentView.init() - ClipboardManager.initializeData() completed")
    _clipboardManager = StateObject(wrappedValue: manager)
    LaunchLogger.log("ContentView.init() - END")
}
```

**In `body`:**
```swift
var body: some View {
    LaunchLogger.log("ContentView.body - START")
    NavigationView { mainContent }
    // ...
}
```

**In `onAppear`:**
```swift
.onAppear {
    LaunchLogger.log("ContentView.onAppear - START")
    configureNavigationBarAppearance()
    checkActivityStatus()
    NotificationCenter.default.addObserver(...)
    LaunchLogger.log("ContentView.onAppear - END")
}
```

**What to look for:**
- **CRITICAL:** Time between "ClipboardManager created" and "initializeData() completed"
  - This is the **MAIN BOTTLENECK** if it's > 50ms
  - This is where synchronous I/O happens on the main thread
- Time from `ContentView.init() - START` to `END` is your total ContentView setup time

---

### 4. ClipboardManager.swift

**In `init()`:**
```swift
public init() {
    LaunchLogger.log("ClipboardManager.init() - START")
    // UserDefaults setup...
    LaunchLogger.log("ClipboardManager.init() - END")
}
```

**In `initializeData()`:**
```swift
public func initializeData() {
    LaunchLogger.log("ClipboardManager.initializeData() - START")
    guard didInitializeSuccessfully else { 
        LaunchLogger.log("ClipboardManager.initializeData() - SKIPPED (init failed)")
        return 
    }
    loadItems()
    LaunchLogger.log("ClipboardManager.initializeData() - loadItems() completed")
    cleanupItems()
    LaunchLogger.log("ClipboardManager.initializeData() - cleanupItems() completed")
    if UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") { 
        Task { 
            LaunchLogger.log("ClipboardManager.initializeData() - CloudSync Task spawned")
            await performCloudSync() 
        }
    }
    LaunchLogger.log("ClipboardManager.initializeData() - END")
}
```

**What to look for:**
- **CRITICAL:** Time for `loadItems()` - This does synchronous JSON decoding
- **CRITICAL:** Time for `cleanupItems()` - This does file system operations
- Both of these happen on the main thread during ContentView.init()!

---

### 5. LinkMetadataManager.swift

**In `fetchMetadata()`:**
```swift
func fetchMetadata(for url: URL) {
    LaunchLogger.log("LinkMetadataManager.fetchMetadata() - START for URL: \(url)")
    isLoading = true
    // ...
    Task {
        do {
            let fetchedMetadata = try await provider.startFetchingMetadata(for: url)
            // ...
            LaunchLogger.log("LinkMetadataManager.fetchMetadata() - SUCCESS for URL: \(url)")
        } catch {
            // ...
            LaunchLogger.log("LinkMetadataManager.fetchMetadata() - FAILED for URL: \(url)")
        }
    }
}
```

**What to look for:**
- If you see many of these logs during launch, it means URL previews are being fetched
- Each one is a network request that can slow down the UI

---

### 6. InlineLinkPreview.swift

**In `onAppear`:**
```swift
.onAppear {
    LaunchLogger.log("InlineLinkPreview.onAppear - START fetching metadata")
    metadataManager.fetchMetadata(for: url)
}
```

**What to look for:**
- How many inline previews are being created during launch
- Each one triggers a `LinkMetadataManager.fetchMetadata()` call

---

### 7. SpeechRecognizer (AudioManager.swift)

**In `init()`:**
```swift
init() {
    LaunchLogger.log("SpeechRecognizer.init() - START requesting authorization")
    SFSpeechRecognizer.requestAuthorization { authStatus in
        DispatchQueue.main.async {
            if authStatus != .authorized { 
                LaunchLogger.log("SpeechRecognizer.init() - Authorization DENIED")
            }
            else { 
                LaunchLogger.log("SpeechRecognizer.init() - Authorization GRANTED")
            }
        }
    }
    LaunchLogger.log("SpeechRecognizer.init() - END (async authorization request sent)")
}
```

**What to look for:**
- Time between "START" and "END" shows how long it takes to start the authorization request
- Time until "Authorization GRANTED/DENIED" shows the total authorization time

---

## How to Read the Logs

### Example Console Output

```
🚀 LaunchLogger: App start time initialized at 1234567890.123456
⏱️ [+0 ms] ClippyIsleApp.init() - START
⏱️ [+1 ms] SubscriptionManager.init() - START
⏱️ [+2 ms] SubscriptionManager.init() - END
⏱️ [+3 ms] ClippyIsleApp.init() - END
⏱️ [+5 ms] ClippyIsleApp.body - START
⏱️ [+8 ms] ContentView.init() - START
⏱️ [+10 ms] SpeechRecognizer.init() - START requesting authorization
⏱️ [+12 ms] SpeechRecognizer.init() - END (async authorization request sent)
⏱️ [+15 ms] ClipboardManager.init() - START
⏱️ [+18 ms] ClipboardManager.init() - END
⏱️ [+19 ms] ContentView.init() - ClipboardManager created
⏱️ [+20 ms] ClipboardManager.initializeData() - START
⏱️ [+125 ms] ClipboardManager.initializeData() - loadItems() completed    ⚠️ 105ms BLOCKING!
⏱️ [+135 ms] ClipboardManager.initializeData() - cleanupItems() completed
⏱️ [+137 ms] ClipboardManager.initializeData() - CloudSync Task spawned
⏱️ [+138 ms] ClipboardManager.initializeData() - END
⏱️ [+140 ms] ContentView.init() - ClipboardManager.initializeData() completed
⏱️ [+142 ms] ContentView.init() - END
⏱️ [+145 ms] ContentView.body - START
⏱️ [+250 ms] ContentView.onAppear - START
⏱️ [+255 ms] ContentView.onAppear - END
⏱️ [+260 ms] SubscriptionManager.start() - Task BEGIN
⏱️ [+262 ms] SubscriptionManager.start() - BEGIN
⏱️ [+265 ms] SubscriptionManager.start() - END (async tasks spawned)
⏱️ [+267 ms] SubscriptionManager.start() - Task END
⏱️ [+500 ms] ClippyIsleApp.body.WindowGroup - onAppear
```

### Interpreting the Results

1. **Look for large gaps between consecutive logs**
   - A gap > 50ms indicates blocking work
   
2. **Identify the culprit**
   - In the example above, `loadItems()` took 105ms (from 20ms to 125ms)
   - This is your main bottleneck!

3. **Calculate total blocking time**
   - From `ContentView.init() - START` to `ContentView.init() - END` = 134ms
   - Most of this (105ms) is in `loadItems()`

4. **Check for network activity during launch**
   - Look for `LinkMetadataManager.fetchMetadata()` logs
   - Each one is a network request

---

## What Times Are Good vs. Bad?

### ✅ Good Times

- App init: < 5ms
- Manager init (empty): < 5ms
- View body evaluation: < 10ms
- Spawning async tasks: < 10ms
- Total time to first frame: < 100ms

### ⚠️ Warning Times

- Any single operation: 50-100ms
- Total time to first frame: 100-200ms
- loadItems(): 30-100ms (depends on data size)

### ❌ Bad Times

- Any single operation: > 100ms
- Total time to first frame: > 200ms
- loadItems(): > 100ms
- Any synchronous network call during launch

---

## What to Do Next

1. **Run the app** and collect the logs
2. **Identify the largest gaps** in the timeline
3. **Refer to LAUNCH_PERFORMANCE_AUDIT.md** for specific fixes for each issue
4. **Implement Priority 1 fixes first** (moving ClipboardManager.initializeData() to async)
5. **Re-run with logs** to measure improvement

---

## Quick Fix Summary

### Most Important Fix (Will save 100-200ms)

Move `ClipboardManager.initializeData()` out of `ContentView.init()`:

```swift
// BEFORE (BLOCKING)
init() { 
    let manager = ClipboardManager()
    manager.initializeData()  // ❌ Blocks main thread
    _clipboardManager = StateObject(wrappedValue: manager)
}

// AFTER (NON-BLOCKING)
init() { 
    let manager = ClipboardManager()
    _clipboardManager = StateObject(wrappedValue: manager)
}

var body: some View {
    NavigationView { mainContent }
        .task(priority: .userInitiated) {
            clipboardManager.initializeData()  // ✅ Async, doesn't block
        }
}
```

This single change should eliminate the white screen lag!

---

## Additional Resources

- See `LAUNCH_PERFORMANCE_AUDIT.md` for complete audit results
- See inline code comments for explanations of what each log measures
- Use Xcode's Instruments (Time Profiler) for even more detailed analysis

---

## Questions?

If you see unexpected behavior or need help interpreting the logs, refer to:
1. The log statement locations in this guide
2. The blocking patterns identified in `LAUNCH_PERFORMANCE_AUDIT.md`
3. The code comments added with each log statement
