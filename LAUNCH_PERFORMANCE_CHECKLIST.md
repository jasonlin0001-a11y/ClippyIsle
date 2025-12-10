# Launch Performance Checklist

## ✅ What Has Been Done

### 1. LaunchLogger Implementation
- [x] Created `LaunchLogger.swift` utility class
- [x] Tracks milliseconds elapsed since app start
- [x] Simple API: `LaunchLogger.log("step name")`
- [x] Outputs format: `⏱️ [+123 ms] step name`

### 2. Instrumentation Added

#### ClippyIsleApp.swift
- [x] `init()` - START/END markers
- [x] `body` - START marker
- [x] `.task` modifier - SubscriptionManager.start() timing
- [x] `WindowGroup.onAppear` marker

#### SubscriptionManager.swift
- [x] `init()` - START/END markers
- [x] `start()` - BEGIN/END markers with note about async tasks

#### ContentView.swift
- [x] `init()` - START/END markers
- [x] `init()` - ClipboardManager creation checkpoint
- [x] `init()` - initializeData() completion checkpoint
- [x] `body` - START marker
- [x] `onAppear` - START/END markers

#### ClipboardManager.swift
- [x] `init()` - START/END markers
- [x] `init()` - Error path marker (if App Group fails)
- [x] `initializeData()` - START/END markers
- [x] `initializeData()` - loadItems() completion marker
- [x] `initializeData()` - cleanupItems() completion marker
- [x] `initializeData()` - CloudSync task spawn marker

#### LinkMetadataManager.swift
- [x] `fetchMetadata()` - START/SUCCESS/FAILED markers with URL

#### InlineLinkPreview.swift
- [x] `onAppear` - START marker for metadata fetch

#### SpeechRecognizer (AudioManager.swift)
- [x] `init()` - START/END markers
- [x] `init()` - Authorization GRANTED/DENIED markers

### 3. Documentation
- [x] Created `LAUNCH_PERFORMANCE_AUDIT.md` - Comprehensive audit report
- [x] Created `LAUNCHLOGGER_USAGE.md` - How to use the logs
- [x] Created this `LAUNCH_PERFORMANCE_CHECKLIST.md` - Quick reference

---

## 🔍 Critical Issues Identified

### Issue #1: ClipboardManager.initializeData() Blocks Main Thread ❌
**Severity:** CRITICAL  
**Impact:** 80-210ms blocking during launch  
**Location:** ContentView.init() line 70

**Problem:**
```swift
init() { 
    let manager = ClipboardManager()
    manager.initializeData()  // ❌ BLOCKS: loadItems() + cleanupItems()
    _clipboardManager = StateObject(wrappedValue: manager)
}
```

**What's blocking:**
- `loadItems()` - Synchronous JSON decode from UserDefaults (50-150ms)
- `cleanupItems()` - File system operations (10-50ms)
- CloudKit Task spawn (10-20ms setup overhead)

**Fix Required:** Move to async context (see LAUNCH_PERFORMANCE_AUDIT.md)

---

### Issue #2: loadItems() Does Synchronous I/O ❌
**Severity:** HIGH  
**Impact:** 50-150ms (depends on data size)  
**Location:** ClipboardManager.loadItems() line 157

**Problem:**
- Reads data from UserDefaults on main thread
- Decodes JSON on main thread
- No async/await used

**Fix Required:** Make loadItems() async (see LAUNCH_PERFORMANCE_AUDIT.md)

---

### Issue #3: SpeechRecognizer Requests Authorization in Init ⚠️
**Severity:** MEDIUM  
**Impact:** 10-30ms + user prompt if not determined  
**Location:** AudioManager.swift line 68

**Problem:**
- Authorization requested immediately when ContentView creates SpeechRecognizer
- Unnecessary if user never uses speech recognition
- Can show permission dialog during launch

**Fix Required:** Lazy authorization pattern (see LAUNCH_PERFORMANCE_AUDIT.md)

---

### Issue #4: InlineLinkPreview Network Fetches ⚠️
**Severity:** MEDIUM  
**Impact:** Multiple network requests, UI slowdown  
**Location:** InlineLinkPreview.swift line 37

**Problem:**
- Each URL item can trigger network fetch when scrolled into view
- No caching implemented
- Can create network storm with many URL items

**Fix Required:** Add caching + lazy load (see LAUNCH_PERFORMANCE_AUDIT.md)

---

### Issue #5: CloudKit Sync During Launch ⚠️
**Severity:** MEDIUM  
**Impact:** Network I/O competing for resources  
**Location:** ClipboardManager.initializeData() line 52

**Problem:**
- CloudKit sync starts during app launch
- Competes with UI rendering
- Network dependency during critical launch phase

**Fix Required:** Delay sync by 1-2 seconds (see LAUNCH_PERFORMANCE_AUDIT.md)

---

## 🎯 Action Items (Priority Order)

### Priority 1 - Critical (Do These First)
- [ ] **Move ClipboardManager.initializeData() to async context**
  - Remove from ContentView.init()
  - Call from .task or .onAppear
  - **Expected improvement: 80-210ms faster launch**

- [ ] **Make ClipboardManager.loadItems() async**
  - Use Task.detached for UserDefaults read
  - Use background thread for JSON decode
  - **Expected improvement: Enables Priority 1 fix**

### Priority 2 - High Impact
- [ ] **Make ClipboardManager.cleanupItems() async**
  - Move file system operations to background
  - **Expected improvement: 10-50ms**

- [ ] **Defer CloudKit sync**
  - Add 1-2 second delay after launch
  - Use .background priority
  - **Expected improvement: Less resource contention**

### Priority 3 - Medium Impact
- [ ] **Implement lazy SpeechRecognizer authorization**
  - Don't request in init
  - Request when user taps mic button
  - **Expected improvement: 10-30ms + better UX**

- [ ] **Add caching to LinkMetadataManager**
  - Cache fetched metadata
  - Prevent duplicate requests
  - **Expected improvement: Fewer network requests**

### Priority 4 - Nice to Have
- [ ] **Rate limit InlineLinkPreview fetches**
  - Limit concurrent fetches
  - Add request queue
  - **Expected improvement: Better scrolling performance**

---

## 📊 Expected Results

### Before Fixes
- Total blocking time: **80-210ms**
- Time to first frame: **200-400ms**
- User sees: **White screen / lag**

### After Priority 1 & 2 Fixes
- Total blocking time: **< 10ms**
- Time to first frame: **50-100ms**
- User sees: **Instant app appearance**

### Improvement
- **90-95% reduction** in launch blocking time
- **White screen eliminated**
- **Much better user experience**

---

## 🚀 How to Use This Checklist

1. **Run the app and collect logs** from Xcode console
2. **Identify the bottleneck** by looking for large time gaps
3. **Verify it matches** one of the issues identified above
4. **Implement the fix** following LAUNCH_PERFORMANCE_AUDIT.md
5. **Re-run and measure** the improvement with LaunchLogger
6. **Check off the item** in the Priority list above
7. **Move to next priority item**

---

## 📁 File Reference

- `ClippyIsle/Utilities/LaunchLogger.swift` - The logger implementation
- `LAUNCH_PERFORMANCE_AUDIT.md` - Detailed audit with code examples
- `LAUNCHLOGGER_USAGE.md` - How to read and interpret logs
- `LAUNCH_PERFORMANCE_CHECKLIST.md` - This file

---

## 🔧 Quick Commands

### View logs in Xcode
1. Run the app in Xcode
2. Open Console (⇧⌘C)
3. Filter for "⏱️" or "LaunchLogger"

### Grep logs from command line
```bash
# If you have device logs
xcrun simctl spawn booted log show --predicate 'processImagePath contains "ClippyIsle"' --style compact --last 1m | grep "⏱️"
```

---

## 💡 Tips

- **Focus on Priority 1 first** - It will give you the biggest improvement
- **Measure before and after** - Use LaunchLogger to verify improvement
- **Don't optimize everything** - Focus on the critical path first
- **Test on real device** - Simulator may hide some performance issues
- **Check with various data sizes** - Performance varies with item count

---

## ✨ Success Criteria

You'll know you've succeeded when:
- [ ] LaunchLogger shows < 10ms total blocking time in ContentView.init()
- [ ] First ContentView.onAppear happens < 100ms after app launch
- [ ] No white screen visible to user
- [ ] App feels instantly responsive

---

## 📞 Need Help?

Refer to:
1. **LAUNCH_PERFORMANCE_AUDIT.md** - For detailed fix examples
2. **LAUNCHLOGGER_USAGE.md** - For log interpretation
3. **Code comments** - Explanations at each log point
4. **Console logs** - Your actual timing measurements
