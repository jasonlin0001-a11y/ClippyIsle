import SwiftUI
import AVFoundation
import UIKit

struct AudioFileManagerView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var speechManager: SpeechManager
    var onOpenItem: ((ClipboardItem) -> Void)? = nil
    
    @State private var audioFiles: [AudioFileItem] = []
    @State private var totalSize: Int64 = 0
    
    // Playback state
    @State private var shareItems: [Any]?
    @State private var isSharing = false
    
    // Alert states for delete confirmation
    @State private var isShowingDeleteAllAlert = false
    @State private var deleteConfirmationText = ""
    
    @State private var isShowingSingleDeleteAlert = false
    @State private var itemToDelete: AudioFileItem?
    
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("previewFontSize") private var previewFontSize: Double = 17.0

    // Theme Color Support
    @AppStorage("themeColorName") private var themeColorName: String = "blue"
    @AppStorage("customColorRed") private var customColorRed: Double = 0.0
    @AppStorage("customColorGreen") private var customColorGreen: Double = 0.478
    @AppStorage("customColorBlue") private var customColorBlue: Double = 1.0
    
    var themeColor: Color {
        if themeColorName == "custom" {
            return Color(red: customColorRed, green: customColorGreen, blue: customColorBlue)
        }
        return ClippyIsleAttributes.ColorUtility.color(forName: themeColorName)
    }
    
    struct AudioFileItem: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let filename: String
        let displayTitle: String
        let size: Int64
        let creationDate: Date
        let originalItemID: UUID? 
        
        var sizeString: String {
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }
    
    var body: some View {
        ZStack {
            List {
                Section(header: Text("Summary")) {
                    HStack {
                        Text("Total Space Used")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                            .foregroundColor(.secondary)
                    }
                    if !audioFiles.isEmpty {
                        Button("Delete All Audio Files", role: .destructive) {
                            deleteConfirmationText = ""
                            isShowingDeleteAllAlert = true
                        }
                    }
                }
                
                Section(header: Text("Files")) {
                    if audioFiles.isEmpty {
                        Text("No audio files found.").foregroundColor(.secondary)
                    } else {
                        ForEach(audioFiles) { file in
                            HStack(spacing: 12) {
                                // **修正 1**: 使用 Button 取代單純的 Image，增加點擊靈敏度
                                Button(action: {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    togglePlayback(for: file)
                                }) {
                                    Image(systemName: isPlaying(file) ? "stop.circle.fill" : "play.circle")
                                        .font(.title2)
                                        .foregroundColor(themeColor)
                                        .frame(width: 44, height: 44) // 增加觸控範圍
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle()) // 避免點擊時整行閃爍

                                VStack(alignment: .leading, spacing: 4) {
                                    // 文字區域點擊也可以播放，或保留跑馬燈
                                    ClickableMarqueeText(
                                        text: file.displayTitle,
                                        isPlaying: isPlaying(file),
                                        highlightColor: themeColor
                                    )
                                    
                                    HStack {
                                        Text(file.creationDate.formatted(date: .abbreviated, time: .shortened))
                                        Text("•")
                                        Text(file.sizeString)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                // **修正 2**: 讓文字區域也能觸發播放，提升體驗
                                .onTapGesture {
                                    togglePlayback(for: file)
                                }
                                .onLongPressGesture {
                                    // Open the corresponding clipboard item
                                    if let itemID = file.originalItemID,
                                       let item = clipboardManager.items.first(where: { $0.id == itemID }) {
                                        onOpenItem?(item)
                                        dismiss()
                                    }
                                }
                                
                                Spacer()
                            }
                            // **修正 3**: 移除整行的 onTapGesture，避免與 List 手勢衝突
                            .contentShape(Rectangle())
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { shareFile(file.url) } label: { Text("Share") }.tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    itemToDelete = file
                                    isShowingSingleDeleteAlert = true
                                } label: { Text("Delete") }.tint(.gray)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("音訊管理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadFiles)
        
        .sheet(isPresented: $isSharing, onDismiss: { shareItems = nil }) {
            if let items = shareItems { ActivityView(activityItems: items) }
        }
        
        .alert("Permanently Delete All Files?", isPresented: $isShowingDeleteAllAlert) {
            TextField("Type DELETE to confirm", text: $deleteConfirmationText)
                .autocorrectionDisabled(true)
                .autocapitalization(.allCharacters)
            Button("Delete All", role: .destructive) {
                speechManager.stop()
                deleteAllFiles()
            }.disabled(deleteConfirmationText != "DELETE")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. Please type 'DELETE' in all capital letters to confirm.")
        }
        
        .alert("Delete Audio File?", isPresented: $isShowingSingleDeleteAlert, presenting: itemToDelete) { item in
            Button("Delete", role: .destructive) { deleteSingleFile(item) }
            Button("Cancel", role: .cancel) { itemToDelete = nil }
        } message: { _ in
            Text("Are you sure you want to delete this audio file?")
        }
        
        .tint(themeColor)
    }
    
    private func isPlaying(_ file: AudioFileItem) -> Bool {
        return speechManager.isSpeaking && speechManager.currentTitle == file.displayTitle
    }
    
    private func togglePlayback(for file: AudioFileItem) {
        if isPlaying(file) { speechManager.stop() } else { speechManager.playExistingFile(url: file.url, title: file.displayTitle) }
    }
    
    private func shareFile(_ url: URL) {
        self.shareItems = [url]
        self.isSharing = true
    }

    private func loadFiles() {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let folder = cacheDir.appendingPathComponent("LocalAudio")
        do {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            var items: [AudioFileItem] = []
            var total: Int64 = 0
            for url in fileURLs {
                if url.pathExtension == "caf" {
                    let resources = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                    let size = Int64(resources.fileSize ?? 0)
                    let date = resources.creationDate ?? Date()
                    let filename = url.lastPathComponent
                    let uuidString = filename.components(separatedBy: "_").first?.components(separatedBy: ".").first ?? ""
                    var title = "Unknown Item"
                    var originalID: UUID? = nil
                    if let uuid = UUID(uuidString: uuidString),
                       let item = clipboardManager.items.first(where: { $0.id == uuid }) {
                        title = item.displayName ?? item.content
                        if filename.contains("_") { title += " (Page Audio)" }
                        originalID = uuid
                    } else if let uuid = UUID(uuidString: uuidString) {
                        originalID = uuid
                        title = "Deleted Item (\(uuidString.prefix(6))...)"
                    } else { title = "Unknown Item" }
                    items.append(AudioFileItem(url: url, filename: filename, displayTitle: title, size: size, creationDate: date, originalItemID: originalID))
                    total += size
                }
            }
            audioFiles = items.sorted(by: { $0.creationDate > $1.creationDate })
            totalSize = total
        } catch { print("Error loading audio files: \(error)") }
    }
    
    private func deleteSingleFile(_ file: AudioFileItem) {
        if isPlaying(file) { speechManager.stop() }
        try? FileManager.default.removeItem(at: file.url)
        if let index = audioFiles.firstIndex(of: file) { audioFiles.remove(at: index) }
        recalculateTotal()
        itemToDelete = nil
    }
    
    private func deleteAllFiles() {
        speechManager.stop()
        for file in audioFiles { try? FileManager.default.removeItem(at: file.url) }
        audioFiles.removeAll()
        recalculateTotal()
    }
    
    private func recalculateTotal() { totalSize = audioFiles.reduce(0) { $0 + $1.size } }
}

struct ClickableMarqueeText: View {
    let text: String
    let isPlaying: Bool
    let highlightColor: Color
    @State private var isAnimating = false
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Text(text).font(.body).foregroundColor(isPlaying ? highlightColor : .primary)
                    .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    .background(GeometryReader { textGeo in Color.clear.onAppear { textWidth = textGeo.size.width }.onChange(of: text) { _, newText in textWidth = textGeo.size.width; isAnimating = false } })
                    .offset(x: isAnimating ? -(textWidth - containerWidth + 20) : 0)
                    .animation(isAnimating ? Animation.linear(duration: Double(textWidth) / 50).delay(0.5).repeatForever(autoreverses: true) : .default, value: isAnimating)
            }
            .onAppear { containerWidth = geo.size.width }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
            .clipped().contentShape(Rectangle())
            .onTapGesture { if textWidth > containerWidth { isAnimating.toggle() } }
        }
        .frame(height: 24)
    }
}