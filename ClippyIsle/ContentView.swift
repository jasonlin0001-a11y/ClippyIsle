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
    private let badgeOffsetX: CGFloat = 10
    private let badgeOffsetY: CGFloat = -8
    
    // Navigation bar icon sizing
    private let navIconWidth: CGFloat = 36
    private let navIconHeight: CGFloat = 28
    private let navIconFontSize: CGFloat = 14

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
    @State private var isVoiceMemoMode = false  // Track if voice transcription is for memo (vs search)
    @State private var voiceMemoTranscript = ""  // Store voice memo transcript separately
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
    
    // Feed tab selection for paged view
    @State private var selectedFeedTab: FeedTab = .discovery
    
    // Timer for auto-stopping speech search
    @State private var silenceTimer: Timer?
    
    // State to control Audio Manager sheet
    @State private var isShowingAudioManager = false
    
    // State to control search field focus (for radial menu Search action)
    @FocusState private var isSearchFieldFocused: Bool
    
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
    
    // Create Post sheet state
    @State private var showCreatePostSheet = false

    @AppStorage("themeColorName") private var themeColorName: String = "green"
    
    // Custom Color Storage
    @AppStorage("customColorRed") private var customColorRed: Double = 0.0
    @AppStorage("customColorGreen") private var customColorGreen: Double = 0.478
    @AppStorage("customColorBlue") private var customColorBlue: Double = 1.0
    
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode.RawValue = AppearanceMode.system.rawValue
    @AppStorage("previewFontSize") private var previewFontSize: Double = 17.0
    
    // List display settings
    @AppStorage("listDisplayStyle") private var listDisplayStyle: Int = ListDisplayStyle.feed.rawValue
    @AppStorage("showLinkPreview") private var showLinkPreview: Bool = true
    
    // Firebase password settings
    @AppStorage("firebasePasswordEnabled") private var firebasePasswordEnabled: Bool = false
    @AppStorage("firebasePassword") private var firebasePassword: String = ""
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.undoManager) private var undoManager
    @Environment(\.colorScheme) private var colorScheme
    
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
        .searchable(text: $searchText, prompt: "Search...")
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
                if isVoiceMemoMode {
                    // Store transcript for voice memo
                    voiceMemoTranscript = newText
                } else {
                    // Store transcript for search
                    searchText = newText
                }
                silenceTimer?.invalidate()
                silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in 
                    if isVoiceMemoMode {
                        // Auto-save voice memo after silence
                        saveVoiceMemo()
                    } else {
                        stopTranscription() 
                    }
                }
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
        // Create Post sheet with link preview integration
        .sheet(isPresented: $showCreatePostSheet) {
            CreatePostView(themeColor: themeColor)
        }
    }
    
    private func stopTranscription() {
        isTranscribing = false
        isVoiceMemoMode = false
        speechRecognizer.stopTranscribing()
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    private func saveVoiceMemo() {
        stopTranscription()
        let transcriptToSave = voiceMemoTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !transcriptToSave.isEmpty {
            trackAndHighlightNewItem {
                clipboardManager.addNewItem(content: transcriptToSave, type: UTType.text.identifier)
            }
        }
        voiceMemoTranscript = ""
    }
    
    private var mainContent: some View {
        ZStack {
            // Adaptive global gradient background
            if colorScheme == .dark {
                // Dark mode: theme color at top to black at bottom
                LinearGradient(
                    gradient: Gradient(colors: [themeColor.opacity(0.4), Color.black]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            } else {
                // Light mode: light gray at top to white at bottom
                LinearGradient(
                    gradient: Gradient(colors: [Color(UIColor.systemGray6), Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                if clipboardManager.dataLoadError != nil { dataErrorView }
                else { 
                    // Paged feed with Discovery and Following tabs
                    MainFeedView(
                        selectedTab: $selectedFeedTab,
                        themeColor: themeColor
                    ) {
                        // Discovery tab content - real Firestore data from creator_posts
                        DiscoveryFeedView(themeColor: themeColor)
                    } followingContent: {
                        // Following tab content - local clipboard items with floating search bar
                        ZStack(alignment: .bottom) { 
                            listContent
                            
                            // Floating Search Bar
                            VStack {
                                Spacer()
                                bottomToolbar
                                    .padding(.bottom, 10)
                            }
                            .background(Color.clear)
                        }
                    }
                }
            }
            
            // Radial Menu FAB - positioned relative to full screen, not scroll content
            RadialMenuView(
                themeColor: themeColor,
                onVoiceMemo: {
                    // Open microphone for voice-to-text memo
                    if isTranscribing && isVoiceMemoMode {
                        // Stop and save voice memo
                        saveVoiceMemo()
                    } else {
                        // Start voice memo transcription
                        voiceMemoTranscript = ""
                        isVoiceMemoMode = true
                        isTranscribing = true
                        speechRecognizer.transcript = ""  // Clear previous transcript
                        speechRecognizer.startTranscribing()
                    }
                },
                onNewItem: {
                    // Open Create Post view with link preview
                    showCreatePostSheet = true
                },
                onPasteFromClipboard: {
                    trackAndHighlightNewItem {
                        clipboardManager.checkClipboard(isManual: true)
                    }
                }
            )
            
            // Voice Memo Recording Indicator
            if isVoiceMemoMode && isTranscribing {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .opacity(0.8)
                            Text("Recording Voice Memo...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        if !voiceMemoTranscript.isEmpty {
                            Text(voiceMemoTranscript)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .padding(.horizontal)
                        }
                        Button(action: saveVoiceMemo) {
                            HStack {
                                Image(systemName: "stop.circle.fill")
                                Text("Stop & Save")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.red)
                            .cornerRadius(20)
                        }
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.8))
                    )
                    .padding(.bottom, 120)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVoiceMemoMode)
            }
        }
        .navigationTitle(selectedTagFilter != nil ? navigationTitle : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if selectedTagFilter != nil { 
                    Button("Clear") { selectedTagFilter = nil }
                        .buttonStyle(.borderedProminent)
                        .tint(themeColor)
                        .clipShape(Capsule())
                }
                else { 
                    // Live Activity button only (tab picker moved to custom header)
                    Button { clipboardManager.isLiveActivityOn.toggle() } label: { 
                        Image(systemName: "c.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(clipboardManager.isLiveActivityOn ? Color.green : Color.red) 
                    }
                    .disabled(!areActivitiesEnabled)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                // Unified capsule container for navigation icons
                let hasUnreadNotifications = notificationManager.unreadCount > 0
                HStack(spacing: 4) {
                    // Message Center button with badge (uniform style - no individual background)
                    Button { isShowingMessageCenter = true } label: {
                        ZStack {
                            Image(systemName: "tray.fill")
                                .font(.system(size: navIconFontSize, weight: .semibold))
                                .foregroundColor(themeColor)
                            
                            // Badge for unread count - centered on the button
                            if hasUnreadNotifications {
                                Text("\(notificationManager.unreadCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 14, minHeight: 14)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                        }
                        .frame(width: navIconWidth, height: navIconHeight)
                    }
                    
                    // Tag button
                    navIconButton(systemName: "tag.fill") { isShowingTagSheet = true }
                    
                    // Audio Manager button
                    navIconButton(systemName: "waveform") { isShowingAudioManager = true }
                    
                    // Settings button
                    navIconButton(systemName: "gearshape.fill") { isShowingSettings = true }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // Helper function for navigation bar icon buttons
    @ViewBuilder
    private func navIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: navIconFontSize, weight: .semibold))
                .foregroundColor(themeColor)
                .frame(width: navIconWidth, height: navIconHeight)
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
            List {
                ForEach(filteredItems) { item in
                    VStack(spacing: 0) {
                        ClipboardItemRow(
                            item: item,
                            themeColor: themeColor,
                            isHighlighted: item.id == newlyAddedItemID,
                            clipboardManager: clipboardManager,
                            displayStyle: ListDisplayStyle(rawValue: listDisplayStyle) ?? .feed,
                            showLinkPreview: showLinkPreview,
                            copyAction: { copyItemToClipboard(item: item) }, 
                            previewAction: { previewState = .loading(item) },
                            createDragItem: { createDragItem(for: item) }, 
                            togglePinAction: { clipboardManager.togglePin(for: item) },
                            deleteAction: { itemToDelete = item; isShowingDeleteConfirm = true },
                            renameAction: { itemToRename = item; newName = item.displayName ?? ""; isShowingRenameAlert = true },
                            // **MODIFIED**: Tag Limit Logic
                            tagAction: { openTagSheet(for: item) },
                            shareAction: { shareItem(item: item) },
                            speakAction: {
                                // Text-to-speech: play/pause toggle
                                let isCurrentItem = speechManager.currentItemID == item.id
                                if isCurrentItem && speechManager.isSpeaking {
                                    // Currently speaking this item - pause
                                    speechManager.pause()
                                } else if isCurrentItem && speechManager.isPaused {
                                    // Paused on this item - resume
                                    speechManager.resume()
                                } else {
                                    // Start playing this item (stops any other playback)
                                    // Check if local audio file exists - prefer playing audio file if available
                                    let hasLocalAudio = speechManager.hasAudioFile(for: item.id, url: nil)
                                    speechManager.preferLocalFile = hasLocalAudio
                                    let title = item.displayName ?? String(item.content.prefix(30))
                                    speechManager.play(text: item.content, title: title, itemID: item.id)
                                }
                            },
                            isSpeakingThisItem: speechManager.currentItemID == item.id && (speechManager.isSpeaking || speechManager.isPaused),
                            isSpeechPaused: speechManager.currentItemID == item.id && speechManager.isPaused,
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
                            },
                            onLinkTitleFetched: { title in
                                // Auto-rename item to fetched title if name wasn't manually set
                                // A name is considered "manually set" if displayName is not nil
                                if item.displayName == nil {
                                    clipboardManager.renameItem(item: item, newName: title)
                                }
                            }
                        )
                        
                        // Show inline preview if this item is expanded (only in compact mode or when linkPreviewAction is triggered)
                        if expandedPreviewItemID == item.id, 
                           item.type == UTType.url.identifier,
                           let url = URL(string: item.content),
                           listDisplayStyle == ListDisplayStyle.compact.rawValue {
                            InlineLinkPreview(url: url)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    // Card styling
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        // Adaptive card background
                        Group {
                            if colorScheme == .dark {
                                // Dark mode: deep grey with theme tint
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(UIColor.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(themeColor.opacity(0.15))
                                    )
                            } else {
                                // Light mode: clean white background
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                            }
                        }
                    )
                    .shadow(
                        color: colorScheme == .dark ? .black.opacity(0.3) : .black.opacity(0.1),
                        radius: colorScheme == .dark ? 5 : 4,
                        x: 0,
                        y: 2
                    )
                    .id(item.id)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    // Right swipe: Pin and Share actions (matches Tag Management style - text only, no icons)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button("Share") {
                            shareItem(item: item)
                        }
                        .tint(Color(UIColor.systemBlue).opacity(0.55))
                        Button(item.isPinned ? "Unpin" : "Pin") {
                            clipboardManager.togglePin(for: item)
                        }
                        .tint(Color(UIColor.systemBlue).opacity(0.55))
                    }
                    // Left swipe: Rename, Tag, Delete actions (matches Tag Management style - text only, no icons)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            itemToDelete = item
                            isShowingDeleteConfirm = true
                        }
                        Button("Tag") {
                            openTagSheet(for: item)
                        }
                        .tint(Color(UIColor.systemBlue).opacity(0.55))
                        Button("Rename") {
                            itemToRename = item
                            newName = item.displayName ?? ""
                            isShowingRenameAlert = true
                        }
                        .tint(Color(UIColor.systemBlue).opacity(0.55))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                // Add space for bottom toolbar
                Color.clear.frame(height: bottomToolbarPadding)
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
    
    // Delay constant for item highlight after adding new items
    private let itemAddHighlightDelay: Double = 0.2
    
    // Helper method to track old items and highlight newly added ones
    private func trackAndHighlightNewItem(action: () -> Void) {
        let oldIDs = Set(clipboardManager.items.map { $0.id })
        action()
        DispatchQueue.main.asyncAfter(deadline: .now() + itemAddHighlightDelay) {
            if let newItem = clipboardManager.items.first(where: { !oldIDs.contains($0.id) }) {
                highlightAndScroll(to: newItem.id)
            }
        }
    }
    
    // Helper method to handle tag action with Pro check
    private func openTagSheet(for item: ClipboardItem) {
        if subscriptionManager.isPro || clipboardManager.allTags.count < 10 {
            itemToTag = item
        } else {
            showPaywall = true
        }
    }
    
    // Helper method to handle preview dismissal
    private func dismissPreview() {
        isSheetPresented = false
        previewState = .idle
        isPreviewFullscreen = false
    }

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                .padding(.leading, 12)
            TextField("Search...", text: $searchText)
                .focused($isSearchFieldFocused)
                .padding(.horizontal, 8)
                .submitLabel(.search)
                .foregroundColor(colorScheme == .dark ? .white : .primary)
            if !searchText.isEmpty { 
                Button { searchText = ""; hideKeyboard() } label: { 
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .gray) 
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
                    .foregroundColor(isTranscribing ? .red : (colorScheme == .dark ? .white.opacity(0.7) : .gray))
            }
            .padding(.trailing, 12)
        }
        .frame(height: bottomToolbarHeight)
        .background(bottomToolbarBackground)
        .shadow(
            color: colorScheme == .dark ? .black.opacity(0.3) : .black.opacity(0.1),
            radius: colorScheme == .dark ? 8 : 4,
            y: 4
        )
        .padding(.horizontal, 22)
    }
    
    @ViewBuilder
    private var bottomToolbarBackground: some View {
        // Semi-transparent glass capsule with 50% opacity
        Capsule()
            .fill(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.5))
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
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
        
        // Get password if enabled
        let password: String? = firebasePasswordEnabled && !firebasePassword.isEmpty ? firebasePassword : nil
        print("🔐 shareItem: firebasePasswordEnabled=\(firebasePasswordEnabled), hasPassword=\(password != nil)")
        
        // Use Firebase sharing instead of JSON
        isSharingFirebase = true
        FirebaseManager.shared.shareItems([item], password: password) { result in
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