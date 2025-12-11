import SwiftUI
import WebKit
import UniformTypeIdentifiers
import AVFoundation

struct PreviewView: View {
    @Binding var item: ClipboardItem
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var speechManager: SpeechManager
    @AppStorage("showSpeechSubtitles") private var showSpeechSubtitles: Bool = true
    @Binding var fontSize: Double
    @State private var draftItem: ClipboardItem?
    @Environment(\.dismiss) var dismiss
    
    // **NEW**: IAP Manager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showPaywall = false
    
    enum WebDisplayMode: String, CaseIterable, Identifiable { case web = "Web"; case text = "Text"; var id: Self { self } }
    
    @State private var isShowingResumeAlert = false
    @State private var sliderValue: Double = 0
    @State private var isSeeking: Bool = false
    @FocusState private var isImageTextFieldFocused: Bool
    @State private var isTextEditing = false
    @State private var keepScreenOn = false
    @State private var webDisplayMode: WebDisplayMode = .web
    @State private var isPlayerVisible: Bool = false
    
    @State private var webViewState: WebViewState = .idle
    @State private var extractedWebText: String?
    @State private var isExtractingText = false
    @State private var shouldAutoPlayAfterExtraction = false
    @State private var currentWebURL: URL?
    
    @State private var isGeneratingAudio: Bool = false
    @State private var hasLocalAudio: Bool = false
    @State private var isShowingDeleteAudioAlert: Bool = false
    
    @State private var showSaveAlert = false

    private var isYouTubeItem: Bool { extractYouTubeVideoID(from: item.content) != nil }
    private var isFacebookItem: Bool { item.content.contains("facebook.com") }
    private var isTwitterItem: Bool { item.content.contains("twitter.com") || item.content.contains("x.com") }
    private var isWebItem: Bool {
        let isURL = item.type == UTType.url.identifier || (item.type == UTType.text.identifier && item.content.starts(with: "http"))
        return isURL && !isYouTubeItem && !isFacebookItem && !isTwitterItem
    }
    private var isTextOrRichText: Bool { item.type == UTType.text.identifier || item.type == UTType.rtfd.identifier || item.type == UTType.pdf.identifier }
    private var isImageItem: Bool { item.type == UTType.png.identifier }
    
    private var extractedTextClipboardItem: Binding<ClipboardItem> {
        Binding(get: { ClipboardItem(content: self.extractedWebText ?? "", type: UTType.text.identifier) },
                set: { newItem in self.extractedWebText = newItem.content })
    }
    private var navigationTitle: String {
        if let displayName = item.displayName, !displayName.isEmpty { return displayName }
        let trimmedContent = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedContent.isEmpty ? String(localized: "Item Preview") : String(trimmedContent.prefix(30))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Refactored: Use extracted view to simplify body
            contentPreview
            
            // Refactored: Extracted media controls logic
            mediaControlsOrEmpty
        }
        .animation(.default, value: isTextEditing)
        .animation(.default, value: isImageTextFieldFocused)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            #if os(iOS)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            #endif
        }
        .onAppear {
            self.draftItem = item
            if let url = URL(string: item.content), currentWebURL == nil { currentWebURL = url }
            self.hasLocalAudio = speechManager.hasAudioFile(for: item.id, url: currentWebURL)
            if self.hasLocalAudio { speechManager.preferLocalFile = true }
            setupInitialWebViewState()
        }
        .onDisappear {
            // Removed problematic saveProgress call to fix compiler error
            if let draft = draftItem, hasContentChanged(draft: draft, original: item) { item = draft; clipboardManager.updateAndSync(item: item) }
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.down").font(.body.weight(.semibold))
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if isYouTubeItem || isFacebookItem || isTwitterItem || isWebItem {
                    let urlToOpen = currentWebURL ?? URL(string: item.content)
                    if let url = urlToOpen {
                        Button(action: {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #elseif os(macOS)
                            NSWorkspace.shared.open(url)
                            #endif
                        }) { Image(systemName: "safari") }
                    }
                }
                Button("Done") {
                    stopMediaAndCleanup()
                    if let draft = draftItem, hasContentChanged(draft: draft, original: item) { item = draft; clipboardManager.updateAndSync(item: item) }
                    dismiss()
                }
            }
        }
        .alert("Resume Playback?", isPresented: $isShowingResumeAlert) {
            Button("Resume") {
                let savedProgress = speechManager.getProgress(for: item.id, url: currentWebURL) ?? 0
                playSpeech(fromLocation: savedProgress)
            }
            Button("Restart") { playSpeech(fromLocation: 0) }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Would you like to continue from where you left off?") }
        .alert("Delete Audio File?", isPresented: $isShowingDeleteAudioAlert) {
            Button("Delete", role: .destructive) { deleteAudioFile() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This will remove the generated speech file for this page.") }
        .alert("Saved", isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text("Content has been added as a new item.") }
        // **NEW**: Attach Paywall Sheet
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle(Text(navigationTitle))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: keepScreenOn) { _, newValue in
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = newValue
            #endif
        }
        .onChange(of: webDisplayMode) { _, newValue in
            if newValue == .web { loadWebView() }
            else if newValue == .text {
                if extractedWebText == nil || extractedWebText?.isEmpty == true {
                    if let cached = speechManager.getWebText(for: item.id, url: currentWebURL) { extractedWebText = cached }
                    else { triggerTextExtraction(autoPlay: false) }
                }
            }
        }
        .onChange(of: item.id) { _, _ in
            self.draftItem = item
            self.currentWebURL = URL(string: item.content)
            self.extractedWebText = nil
            self.hasLocalAudio = speechManager.hasAudioFile(for: item.id, url: currentWebURL)
            if self.hasLocalAudio { speechManager.preferLocalFile = true }
            setupInitialWebViewState()
            if speechManager.isSpeaking { speechManager.stop() }
        }
        .onReceive(speechManager.$elapsedTime) { newTime in if !isSeeking { sliderValue = newTime } }
    }
    
    // **NEW**: Extracted View Builder to fix compiler complexity error
    @ViewBuilder
    private var contentPreview: some View {
        Group {
            if isImageItem {
                if Binding($draftItem) != nil {
                    ImagePreviewEditor(draftItem: Binding($draftItem)!, originalItem: $item, clipboardManager: clipboardManager, fontSize: $fontSize)
                } else {
                    ProgressView()
                }
            } else if isYouTubeItem || isFacebookItem || isTwitterItem || isWebItem {
                webPreviewContainer
            } else if isTextOrRichText {
                if Binding($draftItem) != nil {
                    EditableTextView(item: Binding($draftItem)!, highlightedRange: (showSpeechSubtitles && speechManager.currentItemID == item.id) ? speechManager.highlightedRange : nil, fontSize: fontSize, clipboardManager: clipboardManager, isEditing: $isTextEditing).padding()
                }
            } else {
                otherFilePreviewContent
            }
        }
    }
    
    // **NEW**: Extracted media controls check to fix compiler complexity error
    @ViewBuilder
    private var mediaControlsOrEmpty: some View {
        let isMediaItem = (isYouTubeItem || isFacebookItem || isTwitterItem || isWebItem || isTextOrRichText) && !isImageItem
        if isMediaItem && !isTextEditing && !isImageTextFieldFocused {
            mediaPlayerControls
                .padding()
                .background(.thinMaterial)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
    
    private func stopMediaAndCleanup() {
        speechManager.stop()
        WebManager.shared.stopAndClear()
    }
    
    private func hasContentChanged(draft: ClipboardItem, original: ClipboardItem) -> Bool {
        return draft.content != original.content || draft.type != original.type || draft.isPinned != original.isPinned ||
               draft.isTrashed != original.isTrashed || draft.displayName != original.displayName || draft.tags != original.tags || draft.filename != original.filename
    }
    
    private func setupInitialWebViewState() {
        if isYouTubeItem || isFacebookItem || isTwitterItem || isWebItem {
            if let cachedText = speechManager.getWebText(for: item.id, url: currentWebURL) { extractedWebText = cachedText }
            if speechManager.isSpeaking && speechManager.currentItemID == item.id { webDisplayMode = .text }
            else { webDisplayMode = .web; loadWebView() }
        }
    }

    private func loadWebView() {
        if WebManager.shared.currentItemID == item.id { webViewState = .success(WebManager.shared.webView.url); return }
        let targetURL = currentWebURL ?? URL(string: item.content)
        guard let urlString = targetURL?.absoluteString, let url = getWebViewURL(from: urlString) else {
            webViewState = .failed(NSError(domain: "PreviewView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])); return
        }
        var request = URLRequest(url: url)
        if isYouTubeItem { request.setValue("https://www.youtube-nocookie.com/", forHTTPHeaderField: "Referer") }
        if isFacebookItem { request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15", forHTTPHeaderField: "User-Agent") }
        else { request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent") }
        webViewState = .loading(request)
    }

    @ViewBuilder private var webPreviewContainer: some View {
        ZStack {
            WebView(state: $webViewState, onTextExtracted: handleExtractedText, onWebViewCreated: { _ in }, onURLChanged: { newURL in
                if self.currentWebURL != newURL {
                    self.currentWebURL = newURL
                    self.extractedWebText = nil
                    self.hasLocalAudio = self.speechManager.hasAudioFile(for: self.item.id, url: newURL)
                    if self.hasLocalAudio { self.speechManager.preferLocalFile = true }
                    if self.speechManager.isSpeaking || self.speechManager.isPaused { self.speechManager.stop() }
                }
            }, itemID: item.id)
            .opacity(webDisplayMode == .web ? 1 : 0)
            
            if case .loading = webViewState, webDisplayMode == .web { ProgressView() }
            else if case .failed = webViewState, webDisplayMode == .web {
                if !isTwitterItem { fallbackView.background(Color(UIColor.systemBackground)) }
            }

            if webDisplayMode == .text { webTextPreview.background(Color(UIColor.systemBackground)) }
        }
    }
    
    @ViewBuilder private var webTextPreview: some View {
        Group {
            if let text = extractedWebText, !text.isEmpty {
                let highlight = (showSpeechSubtitles && speechManager.currentItemID == item.id) ? speechManager.highlightedRange : nil
                EditableTextView(item: extractedTextClipboardItem, highlightedRange: highlight, fontSize: fontSize, clipboardManager: clipboardManager, isEditing: $isTextEditing).padding()
            } else if isExtractingText {
                VStack { ProgressView(); Text("Extracting text from page...").font(.caption).foregroundColor(.secondary).padding(.top, 8) }
            } else {
                if let cached = speechManager.getWebText(for: item.id, url: currentWebURL), !cached.isEmpty { ProgressView() } else { fallbackView }
            }
        }
    }

    private func handleExtractedText(_ text: String) {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.extractedWebText = cleanedText
        self.isExtractingText = false
        
        speechManager.setWebText(cleanedText, for: item.id, url: currentWebURL)
        self.hasLocalAudio = speechManager.hasAudioFile(for: item.id, url: currentWebURL)
        
        if shouldAutoPlayAfterExtraction {
            if let progress = speechManager.getProgress(for: item.id, url: currentWebURL), progress > 0 {
                isShowingResumeAlert = true
            }
            else { playSpeech(fromLocation: nil) }
        }
        shouldAutoPlayAfterExtraction = false
    }
    
    private var fallbackView: some View {
         VStack(alignment: .leading, spacing: 15) {
             Text("Cannot Load Preview").font(.headline)
             Text("Could not load the content for reading aloud or preview.").font(.body).foregroundColor(.secondary)
             if let url = URL(string: item.content) { Link(destination: url) { Text(item.content).foregroundColor(.accentColor).underline() } }
             Spacer()
         }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
     }
    
    private var otherFilePreviewContent: some View {
        Button(action: shareItem) {
            VStack {
                Spacer()
                Image(systemName: itemIcon(for: item.type)).font(.system(size: 80, weight: .light)).foregroundColor(.secondary)
                Text(item.content).font(.title3).fontWeight(.bold).padding(.top, 10)
                Text(UTType(item.type)?.localizedDescription ?? item.type).font(.caption).foregroundColor(.secondary)
                Text("Tap to Open").font(.callout).foregroundColor(Color.accentColor).padding(.top, 20)
                Spacer()
            }.frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
    }
    
    @ViewBuilder private var mediaPlayerControls: some View {
        if isPlayerVisible {
            VStack(spacing: 12) {
                topControlsRow
                Slider(value: $sliderValue, in: 0...max(1, speechManager.duration), onEditingChanged: { editing in isSeeking = editing; if !editing { speechManager.seek(to: sliderValue) } })
                HStack { Text(formatTime(sliderValue)); Spacer(); Text(formatTime(speechManager.duration)) }.font(.caption).foregroundColor(.secondary)
                
                HStack(spacing: 24) {
                    Button(action: { speechManager.seek(to: max(0, speechManager.elapsedTime - 5)) }) {
                        Image(systemName: "gobackward.5").font(.system(size: 24))
                    }
                    Button(action: { switchItem(offset: -1) }) {
                        Image(systemName: "backward.end.fill").font(.system(size: 28))
                    }.disabled(!canSwitchItem(offset: -1))
                    Button(action: toggleSpeech) {
                        let isPlayingThisItem = speechManager.currentItemID == item.id && speechManager.isSpeaking
                        Image(systemName: isPlayingThisItem ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 56))
                    }
                    Button(action: { switchItem(offset: 1) }) {
                        Image(systemName: "forward.end.fill").font(.system(size: 28))
                    }.disabled(!canSwitchItem(offset: 1))
                    Button(action: { speechManager.seek(to: min(speechManager.duration, speechManager.elapsedTime + 5)) }) {
                        Image(systemName: "goforward.5").font(.system(size: 24))
                    }
                }
                .padding(.vertical, 4)
                
                HStack(spacing: 20) {
                    Button(action: { changeSpeechRate(by: -0.1) }) {
                        Image(systemName: "minus.circle").font(.title2)
                    }
                    Text(String(format: "%.1fx", speechManager.speechRate))
                        .font(.body.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(minWidth: 50)
                    Button(action: { changeSpeechRate(by: 0.1) }) {
                        Image(systemName: "plus.circle").font(.title2)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
        } else {
            Button(action: { withAnimation { isPlayerVisible.toggle() } }) { Image(systemName: "chevron.up").font(.body.weight(.semibold)).padding().frame(maxWidth: .infinity) }.background(.thinMaterial)
        }
    }
    
    private var topControlsRow: some View {
        HStack {
             Button(action: toggleLanguage) { HStack(spacing: 4) { Image(systemName: "globe"); Text(currentLanguageLabel()) } }.buttonStyle(.bordered).tint(.secondary)
             if isWebItem || isYouTubeItem || isFacebookItem || isTwitterItem { Picker("Mode", selection: $webDisplayMode) { ForEach(WebDisplayMode.allCases) { Text($0.rawValue) } }.pickerStyle(.segmented).fixedSize() }
             Spacer()
            HStack(spacing: 16) {
                if isGeneratingAudio {
                    ProgressView().scaleEffect(0.8)
                } else {
                    // **MODIFIED**: Voice Download/Generate Button Restricted
                    Button(action: {
                        if subscriptionManager.isPro {
                            toggleAudioState()
                        } else {
                            showPaywall = true
                        }
                    }) {
                        Image(systemName: (hasLocalAudio && speechManager.preferLocalFile) ? "waveform.circle.fill" : "waveform.circle")
                            .font(.title3)
                            // IAP Logic: Grey out if not Pro, otherwise normal colors
                            .foregroundColor(subscriptionManager.isPro ? ((hasLocalAudio && speechManager.preferLocalFile) ? .green : .secondary) : .gray)
                    }
                    
                    if hasLocalAudio && subscriptionManager.isPro {
                        Button(action: { isShowingDeleteAudioAlert = true }) {
                            Image(systemName: "xmark").font(.body).foregroundColor(.secondary)
                        }
                    }
                }
                
                Button(action: saveAsNewItem) {
                    Image(systemName: "plus")
                        .font(.title3)
                }
                
                Button(action: { fontSize -= 1 }) { Image(systemName: "textformat.size.smaller") }.disabled(fontSize <= 12)
                Button(action: { fontSize += 1 }) { Image(systemName: "textformat.size.larger") }.disabled(fontSize >= 28)
                Button(action: { keepScreenOn.toggle() }) { Image(systemName: keepScreenOn ? "sun.max.fill" : "sun.max") }.tint(keepScreenOn ? .yellow : .secondary)
                Button(action: { withAnimation { isPlayerVisible.toggle() } }) { Image(systemName: "chevron.down") }
            }.tint(.secondary)
         }.font(.callout)
    }
    
    private func switchItem(offset: Int) {
        guard let currentIndex = clipboardManager.items.firstIndex(where: { $0.id == item.id }) else { return }
        let nextIndex = currentIndex + offset
        if nextIndex >= 0 && nextIndex < clipboardManager.items.count {
            withAnimation {
                item = clipboardManager.items[nextIndex]
            }
        }
    }

    private func canSwitchItem(offset: Int) -> Bool {
        guard let currentIndex = clipboardManager.items.firstIndex(where: { $0.id == item.id }) else { return false }
        let nextIndex = currentIndex + offset
        return nextIndex >= 0 && nextIndex < clipboardManager.items.count
    }
    
    private func saveAsNewItem() {
        let contentToSave: String
        
        if isWebItem || isYouTubeItem || isFacebookItem || isTwitterItem {
            if webDisplayMode == .text {
                contentToSave = extractedWebText ?? item.content
            } else {
                contentToSave = currentWebURL?.absoluteString ?? item.content
            }
        } else {
            contentToSave = draftItem?.content ?? item.content
        }
        
        guard !contentToSave.isEmpty else { return }
        
        clipboardManager.addNewItem(content: contentToSave, type: UTType.text.identifier)
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        showSaveAlert = true
    }
    
    private func toggleAudioState() {
        if hasLocalAudio {
            speechManager.preferLocalFile.toggle()
            if speechManager.isSpeaking { speechManager.stop() }
        } else {
            startAudioGeneration()
        }
    }
    
    private func startAudioGeneration() {
        let textToConvert: String
        if isWebItem || isYouTubeItem || isFacebookItem || isTwitterItem {
            if let webText = extractedWebText, !webText.isEmpty { textToConvert = webText }
            else { return }
        } else {
            textToConvert = draftItem?.content ?? item.content
        }
        guard !textToConvert.isEmpty else { return }
        
        isGeneratingAudio = true
        Task {
            do {
                try await speechManager.generateAudioFile(text: textToConvert, itemID: item.id, url: currentWebURL)
                await MainActor.run {
                    isGeneratingAudio = false
                    hasLocalAudio = true
                    speechManager.preferLocalFile = true 
                    playSpeech(fromLocation: 0)
                }
            } catch {
                await MainActor.run {
                    isGeneratingAudio = false
                    print("Audio generation failed: \(error)")
                }
            }
        }
    }
    
    private func deleteAudioFile() {
        speechManager.stop()
        speechManager.deleteAudioFile(for: item.id, url: currentWebURL)
        hasLocalAudio = false
        speechManager.preferLocalFile = false 
    }
    
    private func toggleLanguage() {
        if speechManager.forceLanguage == "en-US" { speechManager.forceLanguage = "zh-TW" }
        else if speechManager.forceLanguage == "zh-TW" { speechManager.forceLanguage = nil }
        else { speechManager.forceLanguage = "en-US" }
        if speechManager.isSpeaking || speechManager.isPaused { speechManager.handleRateChange() }
    }
    private func currentLanguageLabel() -> String { if speechManager.forceLanguage == "en-US" { return "EN" }; if speechManager.forceLanguage == "zh-TW" { return "中文" }; return "Auto" }
    private func changeSpeechRate(by amount: Double) { let newRate = max(Double(AVSpeechUtteranceMinimumSpeechRate), min(Double(AVSpeechUtteranceMaximumSpeechRate), speechManager.speechRate + amount)); speechManager.speechRate = newRate }
    private func formatTime(_ time: TimeInterval) -> String { let minutes = Int(time) / 60; let seconds = Int(time) % 60; return String(format: "%02d:%02d", minutes, seconds) }
    
    private func playSpeech(fromLocation location: Int?) {
        var textToPlay = (isYouTubeItem || isFacebookItem || isTwitterItem || isWebItem) ? (extractedWebText ?? "") : (draftItem?.content ?? item.content)
        if textToPlay.isEmpty && (isYouTubeItem || isFacebookItem || isTwitterItem || isWebItem) { triggerTextExtraction(autoPlay: true); return }
        
        if let startIndex = location, startIndex > 0, startIndex < textToPlay.count {
            let index = textToPlay.index(textToPlay.startIndex, offsetBy: startIndex)
            textToPlay = String(textToPlay[index...])
        }
        
        let titleToDisplay = item.displayName ?? item.content
        speechManager.play(text: textToPlay, title: titleToDisplay, itemID: item.id, url: currentWebURL, fromLocation: location)
    }

    private func triggerTextExtraction(autoPlay: Bool) {
        let webView = WebManager.shared.webView
        shouldAutoPlayAfterExtraction = autoPlay; isExtractingText = true
        let script = "(function(){var t=[];function w(n){if(n.nodeType==3){t.push(n.nodeValue)}else if(n.nodeType==1&&n.nodeName!='SCRIPT'&&n.nodeName!='STYLE'){for(var i=0;i<n.childNodes.length;i++){w(n.childNodes[i])}}}w(document.body);return t.join('\\n');})();"
        webView.evaluateJavaScript(script) { (result, error) in
            if let text = result as? String { handleExtractedText(text) }
            else { isExtractingText = false; shouldAutoPlayAfterExtraction = false }
        }
    }

    private func toggleSpeech() {
        if speechManager.currentItemID == item.id {
             if speechManager.isSpeaking { speechManager.pause(); return }
             if speechManager.isPaused { speechManager.resume(); return }
        }
        if let progress = speechManager.getProgress(for: item.id, url: currentWebURL), progress > 0 {
             isShowingResumeAlert = true
             return
        }
        if isWebItem || isYouTubeItem || isFacebookItem || isTwitterItem {
            if webDisplayMode == .web { webDisplayMode = .text; triggerTextExtraction(autoPlay: true) }
            else { if let text = extractedWebText, !text.isEmpty { playSpeech(fromLocation: nil) } else { triggerTextExtraction(autoPlay: true) } }
        } else { playSpeech(fromLocation: nil) }
    }
    
    private func getWebViewURL(from urlString: String) -> URL? {
        if let videoID = extractYouTubeVideoID(from: urlString) { return URL(string: "https://www.youtube-nocookie.com/embed/\(videoID)?playsinline=1&enablejsapi=1") }
        return URL(string: urlString)
    }

    private func extractYouTubeVideoID(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        if url.host?.contains("youtu.be") == true { return url.lastPathComponent }
        if url.host?.contains("youtube.com") == true || url.host?.contains("youtube-nocookie.com") == true {
            if url.path.contains("/embed/") { return url.lastPathComponent }
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let queryItems = components.queryItems { return queryItems.first(where: { $0.name == "v" })?.value }
        }
        return nil
    }
    
    func shareItem() {
        var itemsToShare: [Any] = []
        var itemToUse = item
        if itemToUse.fileData == nil, let filename = item.filename { itemToUse.fileData = clipboardManager.loadFileData(filename: filename) }
        if let data = itemToUse.fileData {
            let tempFilename = itemToUse.filename ?? itemToUse.content
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(tempFilename)
            do { try data.write(to: tempURL, options: .atomic); itemsToShare.append(tempURL) } catch { itemsToShare.append(data) }
        } else if isWebItem || isYouTubeItem || isFacebookItem || isTwitterItem, let url = URL(string: item.content) { itemsToShare.append(url) } else { itemsToShare.append(item.content) }
        
        guard !itemsToShare.isEmpty else { return }
        #if os(iOS)
        guard let sourceView = UIApplication.shared.windows.first?.rootViewController?.view else { return }
        let activityVC = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = sourceView; popover.sourceRect = CGRect(x: sourceView.bounds.midX, y: sourceView.bounds.midY, width: 0, height: 0); popover.permittedArrowDirections = []
        }
        sourceView.window?.rootViewController?.present(activityVC, animated: true)
        #elseif os(macOS)
        let sharingPicker = NSSharingServicePicker(items: itemsToShare)
        sharingPicker.show(relativeTo: .zero, of: NSView(), preferredEdge: .minY)
        #endif
    }
}