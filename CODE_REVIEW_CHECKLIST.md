# Code Review Checklist for Launch Performance 🔍

This checklist helps you identify common blocking patterns that can cause white screen lag and slow app launches.

---

## ✅ Quick Checklist

Use this checklist when adding new features or reviewing existing code:

### 🚫 Heavy init() - Are there blocking operations in init?

- [ ] **No CoreData fetches in init()**
  - ❌ `init() { fetchedResultsController.performFetch() }`
  - ✅ `init() { }` + `.task { await fetchData() }`

- [ ] **No UserDefaults heavy reads in init()**
  - ❌ `init() { let data = UserDefaults.standard.data(forKey: "largeData"); decode(data) }`
  - ✅ `init() { }` + `.task { await loadSettings() }`

- [ ] **No File System operations in init()**
  - ❌ `init() { let files = FileManager.default.contentsOfDirectory(...) }`
  - ✅ `init() { }` + `.task { await loadFiles() }`

- [ ] **No JSON decoding in init()**
  - ❌ `init() { let items = try JSONDecoder().decode(...) }`
  - ✅ `init() { }` + `.task { await decodeJSON() }`

- [ ] **No network calls in init()**
  - ❌ `init() { URLSession.shared.dataTask(...).resume() }`
  - ✅ `init() { }` + `.task { await fetchFromAPI() }`

---

### 🌐 Synchronous Networking - Are there blocking network calls?

- [ ] **All network calls use async/await**
  - ❌ `URLSession.shared.dataTask(...)`
  - ✅ `try await URLSession.shared.data(for: request)`

- [ ] **No synchronous API calls in View body or init()**
  - ❌ `var body: some View { let data = fetchDataSync(); ... }`
  - ✅ `var body: some View { content.task { await fetchData() } }`

- [ ] **Background priority for non-critical fetches**
  - ❌ `.task { await fetchMetadata() }`
  - ✅ `.task(priority: .background) { await fetchMetadata() }`

---

### 🖼️ Asset Decoding - Are large assets loaded synchronously?

- [ ] **No large JSON files loaded in init() or body**
  - ❌ `let json = Bundle.main.url(...); let data = try Data(contentsOf: json)`
  - ✅ `.task { let data = try await Task.detached { try Data(contentsOf: json) }.value }`

- [ ] **No large images decoded on main thread**
  - ❌ `let image = UIImage(contentsOfFile: path)`
  - ✅ `Task.detached { UIImage(contentsOfFile: path) }`

- [ ] **No synchronous image processing during init**
  - ❌ `init() { processImages() }`
  - ✅ `.task { await processImages() }`

---

### 📱 View Lifecycle - Are operations in the right place?

- [ ] **Heavy work NOT in init()**
  - ❌ `init() { setupComplexState(); loadData(); processingLoop() }`
  - ✅ `init() { }` + `.onAppear { setupComplexState() }` + `.task { await loadData() }`

- [ ] **Heavy work NOT in body**
  - ❌ `var body: some View { let processed = processData(); return Text(processed) }`
  - ✅ `@State var processed: String` + `.task { processed = await processData() }`

- [ ] **Async work uses .task or .onAppear, not init**
  - ❌ `init() { Task { await fetchData() } }`
  - ✅ `.task { await fetchData() }`

---

### 🔧 Manager & Singleton Patterns

- [ ] **Manager init() is empty or minimal**
  - ❌ `init() { loadConfig(); connectToDatabase(); fetchUsers() }`
  - ✅ `init() { }` + `func start() async { ... }`

- [ ] **Managers defer work to start() or setup() methods**
  - ❌ `static let shared = Manager() // init does heavy work`
  - ✅ `static let shared = Manager() // init is empty` + `manager.start()` in `.task`

- [ ] **Authorization requests are lazy**
  - ❌ `init() { AVCaptureDevice.requestAccess(...) }`
  - ✅ `func requestAccessIfNeeded() async { ... }` (called when feature is used)

---

### 📊 Data Loading Patterns

- [ ] **UserDefaults reads are small or deferred**
  - ❌ `init() { let items = userDefaults.array(forKey: "items") as? [Item] }`
  - ✅ `.task { await loadItems() }`

- [ ] **Large data sets load asynchronously**
  - ❌ `init() { self.items = loadThousandsOfItems() }`
  - ✅ `@State var items = []` + `.task { items = await loadThousandsOfItems() }`

- [ ] **Database queries are async**
  - ❌ `init() { self.users = realm.objects(User.self) }`
  - ✅ `.task { users = await fetchUsers() }`

---

## 🎯 Specific Patterns to Avoid

### ❌ Anti-Pattern 1: Heavy ContentView.init()
```swift
// BAD
struct ContentView: View {
    @StateObject private var manager: DataManager
    
    init() {
        let mgr = DataManager()
        mgr.loadData()      // ❌ BLOCKS MAIN THREAD
        mgr.processData()    // ❌ BLOCKS MAIN THREAD
        _manager = StateObject(wrappedValue: mgr)
    }
}
```

```swift
// GOOD
struct ContentView: View {
    @StateObject private var manager = DataManager()
    
    var body: some View {
        content
            .task(priority: .userInitiated) {
                await manager.loadData()    // ✅ ASYNC
                await manager.processData()  // ✅ ASYNC
            }
    }
}
```

---

### ❌ Anti-Pattern 2: Synchronous Manager Init
```swift
// BAD
class DataManager {
    init() {
        let data = UserDefaults.standard.data(forKey: "items")
        self.items = try! JSONDecoder().decode([Item].self, from: data!)
        // ❌ This blocks whoever creates the manager
    }
}
```

```swift
// GOOD
class DataManager {
    init() {
        // Empty - fast!
    }
    
    func loadData() async {
        guard let data = UserDefaults.standard.data(forKey: "items") else { return }
        let items = try await Task.detached {
            try JSONDecoder().decode([Item].self, from: data)
        }.value
        await MainActor.run { self.items = items }
    }
}
```

---

### ❌ Anti-Pattern 3: Network Calls in View Lifecycle
```swift
// BAD
struct ProfileView: View {
    @State private var user: User?
    
    init() {
        // ❌ Network call during init
        fetchUser { user in
            self.user = user
        }
    }
}
```

```swift
// GOOD
struct ProfileView: View {
    @State private var user: User?
    
    var body: some View {
        content
            .task {
                user = await fetchUser()  // ✅ Async, after UI appears
            }
    }
}
```

---

### ❌ Anti-Pattern 4: Large Asset Loading
```swift
// BAD
struct MapView: View {
    let mapData: [Location]
    
    init() {
        // ❌ Loading 10MB JSON file synchronously
        let url = Bundle.main.url(forResource: "cities", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        self.mapData = try! JSONDecoder().decode([Location].self, from: data)
    }
}
```

```swift
// GOOD
struct MapView: View {
    @State private var mapData: [Location] = []
    
    var body: some View {
        content
            .task(priority: .userInitiated) {
                // ✅ Load in background
                let url = Bundle.main.url(forResource: "cities", withExtension: "json")!
                let data = try await Task.detached {
                    try Data(contentsOf: url)
                }.value
                mapData = try await Task.detached {
                    try JSONDecoder().decode([Location].self, from: data)
                }.value
            }
    }
}
```

---

## 🔬 How to Use This Checklist

### For New Features
1. Before implementing, review this checklist
2. Design your feature with async-first approach
3. Place heavy operations in `.task` modifiers, not `init()`

### For Existing Code
1. Search for patterns like:
   - `init() {` with more than 5 lines
   - `UserDefaults.standard.data`
   - `JSONDecoder().decode`
   - `FileManager.default.contentsOfDirectory`
   - `URLSession.shared.dataTask`
2. Check each against this checklist
3. Refactor blocking operations to async

### During Code Review
1. Look for the red flags in this checklist
2. Ask: "Could this block the main thread?"
3. Suggest moving to `.task` or making it async

---

## 📊 Performance Targets

Use these as guidelines:

| Operation | Target Time |
|-----------|-------------|
| View init() | < 10ms |
| Manager init() | < 5ms |
| App launch to first frame | < 100ms |
| Data loading (async) | < 500ms |

---

## 🚨 Red Flags

If you see these during launch, investigate immediately:

- ⚠️ Any init() taking > 10ms
- ⚠️ Any synchronous file I/O
- ⚠️ Any synchronous network call
- ⚠️ Any JSON decoding in init()
- ⚠️ Any database query in init()
- ⚠️ Large UserDefaults reads in init()

---

## ✅ Best Practices Summary

1. **Keep init() empty** - Create instances fast
2. **Defer to .task** - Load data after UI appears
3. **Use async/await** - Never block the main thread
4. **Priority matters** - Use `.background` for non-critical work
5. **Test with LaunchLogger** - Measure, don't guess

---

## 📚 Related Documentation

- **LaunchLogger Usage:** See `LAUNCHLOGGER_USAGE.md` for timing your code
- **Performance Audit:** See `LAUNCH_PERFORMANCE_AUDIT.md` for detailed analysis
- **Fix Applied:** See `LAUNCH_PERFORMANCE_FIX_APPLIED.md` for the fix example

---

## 💡 Quick Tips

- **Empty init() = Fast launch** 🚀
- **Heavy work in .task = Smooth launch** ✅
- **Async > Sync** for everything non-trivial
- **Measure with LaunchLogger** before and after changes
- **User sees UI first, data second** = Good UX

---

## 🎓 Remember

> "The fastest code is the code that doesn't run during app launch."

Move everything possible to:
1. `.task` modifiers (runs after view appears)
2. `.onAppear` (runs when view appears)
3. User interaction (runs when user taps)

Never put it in:
1. `init()` ❌
2. `body` computed property ❌
3. Singleton initialization ❌

---

This checklist helps you avoid the #1 cause of slow app launches: **synchronous I/O on the main thread during initialization**. Follow these guidelines to keep your launches fast! 🚀
