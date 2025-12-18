//
//  ContentView.swift
//  ClippyIsle
//
//  Refactored Version (Split into multiple files)
//  User: jasonlin0001-a11y
//

import SwiftUI
import ActivityKit
import UniformTypeIdentifiers
import Combine
import AudioToolbox

// MARK: - Main ContentView
struct ContentView: View {
    enum PreviewState: Equatable { case idle, loading(ClipboardItem), loaded(ClipboardItem) }
    
    // Constants for consistent UI sizing
    private let bottomToolbarHeight: CGFloat = 50
    private var bottomToolbarPadding: CGFloat { bottomToolbarHeight + 30 } // toolbar height + margin

    @StateObject private var clipboardManager: ClipboardManager
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var speechRecognizer = SpeechRecognizer()
    
    // Binding to signal when app is ready (data loaded)
    @Binding var isAppReady: Bool
    
    // **NEW**: IAP Manager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var pendingShareManager: PendingShareManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showPaywall = false

    @State private var previewState: PreviewState = .idle
    @State private var isShowingSettings = false
    @State private var itemToRename: ClipboardItem? = nil
    @State private var newName = ""
    @State private var isShowingRenameAlert = false
    @State private var searchText = ""
    @State private var isTranscribing = false
    @State private var isShowingPinnedOnly = false
    @State private var isShowingTagSheet = false
    @State private var itemToTag: ClipboardItem? = nil
    @State private var selectedTagFilter: String? = nil
    @State private var itemToDelete: ClipboardItem?
    @State private var isShowingDeleteConfirm = false
    @State private var areActivitiesEnabled = false
    @State private var isSheetPresented = false
    @State private var lastTopItemID: UUID?
    
    // Track newly added item for highlighting
    @State private var newlyAddedItemID: UUID?
    
    // Track expanded inline preview item
    @State private var expandedPreviewItemID: UUID?
    
    // Timer for auto-stopping speech search
    @State private var silenceTimer: Timer?
    
    // State to control Audio Manager sheet
    @State private var isShowingAudioManager = false
    
    // Firebase share state
    @State private var isSharingFirebase = false
    @State private var firebaseShareURL: String?
    @State private var showFirebaseShareSheet = false
    @State private var showFirebaseSizeError = false
    
    // iPad fullscreen preview state
    @State private var isPreviewFullscreen = false
    
    // Message Center state
    @State private var isShowingMessageCenter = false
    @StateObject private var notificationManager = NotificationManager.shared

    @AppStorage("themeColorName") private var themeColorName: String = "green"
    
    // Custom Color Storage
    @AppStorage("customColorRed") private var customColorRed: Double = 0.0
    @AppStorage("customColorGreen") private var customColorGreen: Double = 0.478
    @AppStorage("customColorBlue") private var customColorBlue: Double = 1.0
    
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode.RawValue = AppearanceMode.system.rawValue
    @AppStorage("previewFontSize") private var previewFontSize: Double = 17.0
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.undoManager) private var undoManager
    
    init(isAppReady: Binding<Bool>) {
        self._isAppReady = isAppReady
        LaunchLogger.log("ContentView.init() - START")
        let manager = ClipboardManager()
        LaunchLogger.log("ContentView.init() - ClipboardManager created")
        // ⚠️ PERFORMANCE FIX: Removed blocking initializeData() call from init
        // Data initialization now happens asynchronously in .task modifier
        _clipboardManager = StateObject(wrappedValue: manager)
        LaunchLogger.log("ContentView.init() - END (data initialization deferred)")
    }
    
    var themeColor: Color {
        if themeColorName == "custom" {
            return Color(red: customColorRed, green: customColorGreen, blue: customColorBlue)
        }
        return ClippyIsleAttributes.ColorUtility.color(forName: themeColorName)
    }
    
    var preferredColorScheme: ColorScheme? { AppearanceMode(rawValue: appearanceMode)?.colorScheme }
    
    var filteredItems: [ClipboardItem] {
        var itemsToShow = clipboardManager.items.filter { !$0.isTrashed }
        if isShowingPinnedOnly { itemsToShow = itemsToShow.filter { $0.isPinned } }
        if let tag = selectedTagFilter { itemsToShow = itemsToShow.filter { $0.tags?.contains(tag) ?? false } }
        if searchText.isEmpty { return itemsToShow }
        return itemsToShow.filter {
            $0.content.localizedCaseInsensitiveContains(searchText) ||
            ($0.displayName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.tags?.contains { $0.localizedCaseInsensitiveContains(searchText) } ?? false)
        }
    }
    
    private var loadedItemBinding: Binding<ClipboardItem> {
        Binding(get: { if case .loaded(let item) = self.previewState { return item }; return ClipboardItem(content: "Error", type: "public.text") },
            set: { updatedItem in
                // Don't directly modify items array here - let updateAndSync handle it
                // Just update the preview state
                if case .loaded = self.previewState { self.previewState = .loaded(updatedItem) }
            }
        )
    }

    var body: some View {
        NavigationView { mainContent }
        .navigationViewStyle(.stack).tint(themeColor).preferredColorScheme(preferredColorScheme)
        .task(priority: .userInitiated) {
            // ✅ PERFORMANCE FIX: Initialize data asynchronously after UI rendering
            // Note: Runs on MainActor but doesn't block initial view rendering
            LaunchLogger.log("ContentView.task - ClipboardManager.initializeData() - START")
            clipboardManager.initializeData()
            LaunchLogger.log("ContentView.task - ClipboardManager.initializeData() - END")
            // Signal that app is ready
            isAppReady = true
        }
        .onAppear {
            LaunchLogger.log("ContentView.onAppear - START")
            configureNavigationBarAppearance()
            checkActivityStatus()
            NotificationCenter.default.addObserver(forName: .didRequestUndo, object: nil, queue: .main) { _ in undoManager?.undo() }
            LaunchLogger.log("ContentView.onAppear - END")
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                checkActivityStatus()
                clipboardManager.cloudKitManager.checkAccountStatus()
                
                // Check for pending notifications from Share Extension
                notificationManager.checkForPendingNotifications()
                
                // Reload items from UserDefaults to pick up items added via Share Extension
                let oldIDs = Set(clipboardManager.items.lazy.map { $0.id })
                clipboardManager.loadItems()
                
                if !isSheetPresented {
                    if (speechManager.isSpeaking || speechManager.isPaused),
                       let currentItemID = speechManager.currentItemID,
                       let item = clipboardManager.items.first(where: { $0.id == currentItemID }) {
                        previewState = .loading(item)
                    }
                    else if let webItemID = WebManager.shared.currentItemID,
                            let item = clipboardManager.items.first(where: { $0.id == webItemID }) {
                        previewState = .loading(item)
                    }
                }
                
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    if previewState == .idle {
                        await MainActor.run { clipboardManager.checkClipboard() }
                        try? await Task.sleep(for: .milliseconds(500))
                        await MainActor.run {
                            if let newItem = clipboardManager.items.first(where: { !oldIDs.contains($0.id) }) {
                                highlightAndScroll(to: newItem.id)
                            }
                        }
                    }
                }
                
            case .background:
                let isWebPlaying = WebManager.shared.currentItemID != nil
                if !speechManager.isSpeaking && !isWebPlaying {
                    if isTranscribing { stopTranscription() }
                    AudioManager.shared.deactivate()
                }
                clipboardManager.sortAndSave()
                
            default:
                break
            }
        }
        .onChange(of: previewState) { oldState, newState in
            if case .loading(let itemToLoad) = newState {
                Task {
                    var loadedItem = itemToLoad
                    if loadedItem.fileData == nil, let filename = itemToLoad.filename { loadedItem.fileData = clipboardManager.loadFileData(filename: filename) }
                    if case .loading(let currentItem) = previewState, currentItem.id == loadedItem.id { previewState = .loaded(loadedItem) }
                }
            }
            if newState == .idle && oldState != .idle { clipboardManager.sortAndSave() }
            if newState != .idle && !isSheetPresented { isSheetPresented = true }
        }
        .onChange(of: clipboardManager.isLiveActivityOn) { _, newValue in Task { if newValue { await clipboardManager.startActivity() } else { await clipboardManager.endActivity() } } }
        .onChange(of: themeColorName) { _, newColor in if clipboardManager.isLiveActivityOn { clipboardManager.updateActivity(newColorName: newColor) } }
        .onChange(of: speechRecognizer.transcript) { _, newText in
            if isTranscribing {
                searchText = newText
                silenceTimer?.invalidate()
                silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in stopTranscription() }
            }
        }
        
        .sheet(isPresented: $isShowingTagSheet) { TagFilterView(clipboardManager: clipboardManager, selectedTag: $selectedTagFilter) }
        .sheet(isPresented: .init(get: { horizontalSizeClass == .compact && isShowingSettings }, set: { isShowingSettings = $0 })) {
            SettingsView(themeColorName: $themeColorName, speechManager: speechManager, clipboardManager: clipboardManager)
                .environmentObject(authManager)
        }
        .fullScreenCover(isPresented: .init(get: { horizontalSizeClass == .regular && isShowingSettings }, set: { isShowingSettings = $0 })) {
            SettingsView(themeColorName: $themeColorName, speechManager: speechManager, clipboardManager: clipboardManager)
                .environmentObject(authManager)
        }
        .sheet(isPresented: $isShowingAudioManager) {
            NavigationView {
                AudioFileManagerView(clipboardManager: clipboardManager, speechManager: speechManager, onOpenItem: { item in
                    // Open the item in preview
                    isShowingAudioManager = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        previewState = .loading(item)
                    }
                })
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { isShowingAudioManager = false }
                                .foregroundStyle(themeColor)
                        }
                    }
            }
            .tint(themeColor)
        }
        
        .sheet(item: $itemToTag) { item in TagEditView(item: Binding(get: { item }, set: { itemToTag = $0 }), clipboardManager: clipboardManager) }
        // iPad preview: sheet in normal mode, fullScreenCover in fullscreen mode
        // iPhone preview: always sheet
        // Note: onDismiss handles user-initiated dismissal (swipe down, etc.)
        // The setter should only dismiss when not transitioning between presentation styles
        .sheet(isPresented: .init(
            get: { isSheetPresented && (horizontalSizeClass == .compact || !isPreviewFullscreen) },
            set: { newValue in
                // Only dismiss if user actually dismissed (not transitioning to fullscreen)
                if !newValue && !isPreviewFullscreen {
                    dismissPreview()
                }
            }
        ), onDismiss: {
            // Only dismiss if not transitioning to fullscreen
            if !isPreviewFullscreen {
                dismissPreview()
            }
        }) {
            previewSheetContent(isFullscreen: false, onToggleFullscreen: { isPreviewFullscreen = true })
        }
        .fullScreenCover(isPresented: .init(
            get: { isSheetPresented && horizontalSizeClass == .regular && isPreviewFullscreen },
            set: { newValue in
                // Only dismiss if user actually dismissed (not transitioning back to sheet)
                if !newValue && isPreviewFullscreen {
                    dismissPreview()
                }
            }
        ), onDismiss: {
            // Only dismiss if still in fullscreen mode (user dismissed fullscreen)
            if isPreviewFullscreen {
                dismissPreview()
            }
        }) {
            previewSheetContent(isFullscreen: true, onToggleFullscreen: { isPreviewFullscreen = false })
        }
        .alert("Rename Item", isPresented: $isShowingRenameAlert) {
            TextField("Enter new name", text: $newName).submitLabel(.done)
            Button("Save") { if let item = itemToRename { clipboardManager.renameItem(item: item, newName: newName) }; isShowingRenameAlert = false }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Please enter a new name for the clipboard item.") }
        .alert("Confirm Deletion", isPresented: $isShowingDeleteConfirm, presenting: itemToDelete) { item in
            Button("Delete", role: .destructive) { clipboardManager.moveItemToTrash(item: item) }
            Button("Cancel", role: .cancel) {}
        } message: { item in Text("Are you sure you want to move “\(item.displayName ?? item.content.prefix(20).description)...” to the trash?") }
        
        // **NEW**: Attach Paywall Sheet
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        // Firebase share sheet
        .sheet(isPresented: $showFirebaseShareSheet) {
            if let urlString = firebaseShareURL {
                ActivityView(activityItems: [urlString])
            }
        }
        // Firebase size error alert
        .alert("Size Limit Exceeded", isPresented: $showFirebaseSizeError) {
            Button("OK") {}
        } message: {
            Text("The item exceeds the 900KB limit for Firebase sharing. Please use JSON export instead.")
        }
        // Shared items import dialog
        .sheet(isPresented: $pendingShareManager.showImportDialog) {
            SharedItemsImportView(
                clipboardManager: clipboardManager,
                pendingItems: pendingShareManager.pendingItems,
                isPresented: $pendingShareManager.showImportDialog
            )
            .onDisappear {
                pendingShareManager.clearPendingItems()
            }
        }
        // Message Center sheet
        .sheet(isPresented: $isShowingMessageCenter) {
            MessageCenterView(
                notificationManager: notificationManager,
                clipboardManager: clipboardManager
            )
        }
    }
    
    private func stopTranscription() {
        isTranscribing = false
        speechRecognizer.stopTranscribing()
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    private var mainContent: some View {
        ZStack {
            // Global gradient background
            LinearGradient(
                gradient: Gradient(colors: [themeColor.opacity(0.4), Color.black]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if clipboardManager.dataLoadError != nil { dataErrorView }
                else { ZStack(alignment: .bottom) { listContent; bottomToolbar.padding(.bottom, 8) } }
            }
        }
        .navigationTitle(navigationTitle).navigationBarTitleDisplayMode(selectedTagFilter == nil ? .large : .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if selectedTagFilter != nil { 
                    Button { selectedTagFilter = nil } label: { 
                        Text("Clear")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeColor)
                            .clipShape(Capsule())
                    }
                }
                else { 
                    Button { clipboardManager.isLiveActivityOn.toggle() } label: { 
                        Image(systemName: "c.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(clipboardManager.isLiveActivityOn ? Color.green : Color.red) 
                    }
                    .disabled(!areActivitiesEnabled) 
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Message Center button with badge
                Button { isShowingMessageCenter = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(themeColor)
                            .clipShape(Capsule())
                        
                        // Badge for unread count
                        if notificationManager.unreadCount > 0 {
                            Text("\(notificationManager.unreadCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 8, y: -4)
                        }
                    }
                }
                
                Button { isShowingTagSheet = true } label: {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(themeColor)
                        .clipShape(Capsule())
                }
                
                Button { isShowingAudioManager = true } label: {
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(themeColor)
                        .clipShape(Capsule())
                }
                
                Button { isShowingSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(themeColor)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    private var navigationTitle: String { selectedTagFilter.map { "Tag: \($0)" } ?? "CC Isle" }
    private var dataErrorView: some View {
        VStack(spacing: 15) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 50)).foregroundColor(.orange)
            Text("Data Read Failed").font(.title2).fontWeight(.bold)
            Text("The app encountered an error while reading data. To protect your existing data, all save functions have been temporarily disabled.\nYour original data has not been lost.\n\nPlease try force-quitting and restarting the app. If the problem persists, consider using 'Clear All Data' in the settings page.").font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
        }.padding()
    }
    
    private var listContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(filteredItems) { item in
                        VStack(spacing: 0) {
                            ClipboardItemRow(
                                item: item,
                                themeColor: themeColor,
                                isHighlighted: item.id == newlyAddedItemID,
                                clipboardManager: clipboardManager,
                                copyAction: { copyItemToClipboard(item: item) }, 
                                previewAction: { previewState = .loading(item) },
                                createDragItem: { createDragItem(for: item) }, 
                                togglePinAction: { clipboardManager.togglePin(for: item) },
                                deleteAction: { itemToDelete = item; isShowingDeleteConfirm = true },
                                renameAction: { itemToRename = item; newName = item.displayName ?? ""; isShowingRenameAlert = true },
                                // **MODIFIED**: Tag Limit Logic
                                tagAction: {
                                    // Check if user is Pro OR if total unique tags < 10
                                    if subscriptionManager.isPro || clipboardManager.allTags.count < 10 {
                                        itemToTag = item
                                    } else {
                                        showPaywall = true
                                    }
                                },
                                shareAction: { shareItem(item: item) },
                                linkPreviewAction: {
                                    // Toggle inline preview for URL items
                                    if item.type == UTType.url.identifier, URL(string: item.content) != nil {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            if expandedPreviewItemID == item.id {
                                                expandedPreviewItemID = nil
                                            } else {
                                                expandedPreviewItemID = item.id
                                            }
                                        }
                                    }
                                },
                                onTagLongPress: { tag in
                                    // Toggle filter: if the tag is already filtered, clear it; otherwise, set it
                                    if selectedTagFilter == tag {
                                        selectedTagFilter = nil
                                    } else {
                                        selectedTagFilter = tag
                                    }
                                }
                            )
                            
                            // Show inline preview if this item is expanded
                            if expandedPreviewItemID == item.id, 
                               item.type == UTType.url.identifier,
                               let url = URL(string: item.content) {
                                InlineLinkPreview(url: url)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }
                        // Card styling
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(themeColor.opacity(0.15))
                                )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                        .id(item.id)
                        // Swipe actions using context menu as fallback for ScrollView
                        .contextMenu {
                            Button { shareItem(item: item) } label: { Label("Share", systemImage: "square.and.arrow.up") }
                            Button { clipboardManager.togglePin(for: item) } label: { Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin") }
                            Divider()
                            Button { itemToRename = item; newName = item.displayName ?? ""; isShowingRenameAlert = true } label: { Label("Rename", systemImage: "pencil") }
                            Button {
                                if subscriptionManager.isPro || clipboardManager.allTags.count < 10 {
                                    itemToTag = item
                                } else {
                                    showPaywall = true
                                }
                            } label: { Label("Tag", systemImage: "tag") }
                            Divider()
                            Button(role: .destructive) { itemToDelete = item; isShowingDeleteConfirm = true } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, bottomToolbarPadding)
            }
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    if isTranscribing {
                        stopTranscription()
                    }
                }
            )
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .refreshable { await clipboardManager.performCloudSync() }
            .onChange(of: filteredItems) { items in if let first = items.first, first.id != lastTopItemID { withAnimation { proxy.scrollTo(first.id, anchor: .top) }; lastTopItemID = first.id } }
            .onChange(of: newlyAddedItemID) { oldID, newID in
                if let id = newID {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if newlyAddedItemID == id { withAnimation { newlyAddedItemID = nil } }
                    }
                }
            }
        }
    }
    
    private func highlightAndScroll(to id: UUID) { newlyAddedItemID = id }
    
    // Helper method to handle preview dismissal
    private func dismissPreview() {
        isSheetPresented = false
        previewState = .idle
        isPreviewFullscreen = false
    }

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass").foregroundColor(.white.opacity(0.7)).padding(.leading, 12)
            TextField("Search...", text: $searchText)
                .padding(.horizontal, 8)
                .submitLabel(.search)
                .foregroundColor(.white)
            if !searchText.isEmpty { 
                Button { searchText = ""; hideKeyboard() } label: { 
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6)) 
                }
                .padding(.trailing, 8) 
            }
            
            Button {
                if isTranscribing {
                    stopTranscription()
                } else {
                    isTranscribing = true
                    speechRecognizer.startTranscribing()
                }
            } label: {
                Image(systemName: "mic.fill")
                    .foregroundColor(isTranscribing ? .red : .white.opacity(0.7))
            }
            .padding(.trailing, 8)
            
            Rectangle().frame(width: 1, height: 20).foregroundColor(.white.opacity(0.3)).padding(.horizontal, 4)
            Menu {
                Button {
                    let oldIDs = Set(clipboardManager.items.map { $0.id })
                    clipboardManager.addNewItem(content: String(localized: "New Item"), type: UTType.text.identifier)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if let newItem = clipboardManager.items.first(where: { !oldIDs.contains($0.id) }) { highlightAndScroll(to: newItem.id) }
                    }
                } label: { Label("New Item", systemImage: "square.and.pencil") }
                
                Button {
                    let oldIDs = Set(clipboardManager.items.map { $0.id })
                    clipboardManager.checkClipboard(isManual: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if let newItem = clipboardManager.items.first(where: { !oldIDs.contains($0.id) }) { highlightAndScroll(to: newItem.id) }
                    }
                } label: { Label("Add from Clipboard", systemImage: "doc.on.clipboard") }
            } label: { 
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(themeColor)
                    .clipShape(Circle())
            }
            .padding(.trailing, 12)
        }
        .frame(height: bottomToolbarHeight)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [themeColor.opacity(0.6), Color.black.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .padding(.horizontal, 22)
    }
    
    @ViewBuilder private func previewSheetContent(isFullscreen: Bool, onToggleFullscreen: @escaping () -> Void) -> some View {
        if case .loaded = previewState {
            NavigationView {
                PreviewView(item: loadedItemBinding, clipboardManager: clipboardManager, speechManager: speechManager, fontSize: $previewFontSize, isFullscreen: isFullscreen, onToggleFullscreen: onToggleFullscreen, isIPad: horizontalSizeClass == .regular)
                    .background(Color(UIColor.systemBackground))
            }
            .navigationViewStyle(.stack)
            .tint(themeColor)
            .preferredColorScheme(preferredColorScheme)
        }
        else { ProgressView("Loading...") }
    }
    
    private func hideKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    
    func copyItemToClipboard(item: ClipboardItem) {
        if item.type == UTType.png.identifier, let filename = item.filename, let data = clipboardManager.loadFileData(filename: filename), let img = UIImage(data: data) { UIPasteboard.general.image = img }
        else if item.type == UTType.url.identifier, let url = URL(string: item.content) { UIPasteboard.general.url = url }
        else { UIPasteboard.general.string = item.content }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    func configureNavigationBarAppearance() {
        let roundedFont = UIFont.systemFont(ofSize: 34, weight: .bold).withRoundedDesign()
        let appearance = UINavigationBarAppearance()
        appearance.largeTitleTextAttributes = [.font: roundedFont]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    func checkActivityStatus() {
        Task {
            let enabled = await ActivityAuthorizationInfo().areActivitiesEnabled; self.areActivitiesEnabled = enabled
            if enabled { await clipboardManager.ensureLiveActivityIsRunningIfNeeded() } else { await clipboardManager.endActivity() }
        }
    }
    func shareItem(item: ClipboardItem) {
        // Check size limit (900KB) before Firebase sharing
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode([item]),
           data.count > 900 * 1024 {
            showFirebaseSizeError = true
            return
        }
        
        // Use Firebase sharing instead of JSON
        isSharingFirebase = true
        FirebaseManager.shared.shareItems([item]) { result in
            DispatchQueue.main.async {
                self.isSharingFirebase = false
                switch result {
                case .success(let shareURL):
                    self.firebaseShareURL = shareURL
                    self.showFirebaseShareSheet = true
                case .failure(let error):
                    print("Firebase share failed: \(error.localizedDescription)")
                }
            }
        }
    }
    func createDragItem(for item: ClipboardItem) -> NSItemProvider {
        if item.type == UTType.png.identifier, let filename = item.filename, let data = clipboardManager.loadFileData(filename: filename), let uiImage = UIImage(data: data) {
            let provider = NSItemProvider(); provider.registerObject(uiImage, visibility: .all)
            provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in completion(data, nil); return nil }; return provider
        } else if item.type == UTType.url.identifier, let url = URL(string: item.content) { return NSItemProvider(object: url as NSURL) }
        else { return NSItemProvider(object: item.content as NSString) }
    }
}

extension Notification.Name { static let didRequestUndo = Notification.Name("didRequestUndo") }

extension UIFont {
    func withRoundedDesign() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

extension NSItemProvider {
    func loadDataRepresentation(forTypeIdentifier typeIdentifier: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            _ = self.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error { continuation.resume(throwing: error) }
                else if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: NSError(domain: "NSItemProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data was returned."])) }
            }
        }
    }
    func loadItem(forTypeIdentifier typeIdentifier: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            self.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: item) }
            }
        }
    }
}

extension NSTextStorage {
    func ranges(for attachment: NSTextAttachment) -> [NSRange] {
        var ranges = [NSRange](); var searchRange = NSRange(location: 0, length: self.length)
        while searchRange.location < self.length {
            let foundRange = self.range(of: attachment, in: searchRange)
            if foundRange.location == NSNotFound { break }
            ranges.append(foundRange); let newLocation = foundRange.location + foundRange.length; searchRange = NSRange(location: newLocation, length: self.length - newLocation)
        }
        return ranges
    }
    func range(of attachment: NSTextAttachment, in range: NSRange) -> NSRange {
        var foundRange = NSRange(location: NSNotFound, length: 0)
        self.enumerateAttribute(.attachment, in: range) { value, attrRange, stop in
            if let foundAttachment = value as? NSTextAttachment, foundAttachment == attachment { foundRange = attrRange; stop.pointee = true }
        }
        return foundRange
    }
}