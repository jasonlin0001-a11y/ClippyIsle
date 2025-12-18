import SwiftUI
import AVFoundation
import UIKit

struct AudioFileManagerView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var speechManager: SpeechManager
    var onOpenItem: ((ClipboardItem) -> Void)?
    
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
    @Environment(\.colorScheme) var colorScheme
    
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
    
    private var cardBackground: Color {
        colorScheme == .dark ? ClippyIsleAttributes.ColorUtility.darkCard : Color(.systemBackground)
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? ClippyIsleAttributes.ColorUtility.darkBorder : Color(.separator).opacity(0.3)
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
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    if !audioFiles.isEmpty {
                        Button("Delete All Audio Files", role: .destructive) {
                            deleteConfirmationText = ""
                            isShowingDeleteAllAlert = true
                        }
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                }
                
                Section(header: Text("Files")) {
                    if audioFiles.isEmpty {
                        Text("No audio files found.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(audioFiles) { file in
                            HStack(spacing: 14) {
                                // Modern play button with card styling
                                Button(action: {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    togglePlayback(for: file)
                                }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(themeColor.opacity(colorScheme == .dark ? 0.2 : 0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: isPlaying(file) ? "stop.fill" : "play.fill")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(themeColor)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())

                                VStack(alignment: .leading, spacing: 5) {
                                    ClickableMarqueeText(
                                        text: file.displayTitle,
                                        isPlaying: isPlaying(file),
                                        highlightColor: themeColor
                                    )
                                    
                                    HStack(spacing: 6) {
                                        Text(file.creationDate.formatted(date: .abbreviated, time: .shortened))
                                        Text("•")
                                        Text(file.sizeString)
                                    }
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(.secondary)
                                }
                                .onTapGesture {
                                    togglePlayback(for: file)
                                }
                                .onLongPressGesture {
                                    if let itemID = file.originalItemID,
                                       let item = clipboardManager.items.first(where: { $0.id == itemID }) {
                                        onOpenItem?(item)
                                        dismiss()
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(cardBackground)
                                    .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(cardBorder, lineWidth: 0.5)
                            )
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .contentShape(Rectangle())
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { shareFile(file.url) } label: { Text("Share") }.tint(themeColor)
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
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(colorScheme == .dark ? ClippyIsleAttributes.ColorUtility.darkBackground : Color(.systemGroupedBackground))
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
                Text(text)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(isPlaying ? highlightColor : .primary)
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