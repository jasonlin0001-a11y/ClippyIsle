import SwiftUI
import UniformTypeIdentifiers
import LinkPresentation

// MARK: - Helper Components (Missing Shapes & Layouts)

struct TagChipView: View {
    let tag: String
    let tagColor: Color
    let textColor: Color
    let onFilter: () -> Void
    
    var body: some View {
        Text(tag)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tagColor)
            .foregroundColor(textColor)
            .cornerRadius(8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onEnded { value in
                        // Detect horizontal swipe: horizontal movement must be 1.5x greater than vertical
                        // to distinguish intentional horizontal swipes from diagonal gestures
                        if abs(value.translation.width) > abs(value.translation.height) * 1.5 {
                            onFilter()
                        }
                    }
            )
    }
}

struct CornerTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct FlowLayout: Layout {
    var alignment: Alignment = .center
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        return rows.last?.maxY ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        for row in rows {
            for item in row.items {
                item.view.place(at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y), proposal: .unspecified)
            }
        }
    }
    
    struct Row { var items: [Item] = []; var y: CGFloat = 0; var height: CGFloat = 0; var maxY: CGSize = .zero }
    struct Item { var view: LayoutSubview; var x: CGFloat = 0 }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? 0
        
        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)
            if x + viewSize.width > maxWidth && !currentRow.items.isEmpty {
                currentRow.maxY = CGSize(width: maxWidth, height: currentRow.y + currentRow.height)
                rows.append(currentRow)
                currentRow = Row(y: currentRow.y + currentRow.height + spacing)
                x = 0
            }
            currentRow.items.append(Item(view: view, x: x))
            currentRow.height = max(currentRow.height, viewSize.height)
            x += viewSize.width + spacing
        }
        if !currentRow.items.isEmpty {
            currentRow.maxY = CGSize(width: maxWidth, height: currentRow.y + currentRow.height)
            rows.append(currentRow)
        }
        return rows
    }
}

// MARK: - Main Subviews

struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - List Display Style
enum ListDisplayStyle: Int, CaseIterable {
    case compact = 0
    case feed = 1
    
    var name: String {
        switch self {
        case .compact: return String(localized: "Compact")
        case .feed: return String(localized: "Feed")
        }
    }
}

// MARK: - Clipboard Item Row (Supports both compact and feed styles)
struct ClipboardItemRow: View {
    let item: ClipboardItem
    let themeColor: Color
    var isHighlighted: Bool = false
    var clipboardManager: ClipboardManager? = nil
    var displayStyle: ListDisplayStyle = .feed
    var showLinkPreview: Bool = true
    
    var copyAction: () -> Void
    var previewAction: () -> Void
    var createDragItem: () -> NSItemProvider
    var togglePinAction: () -> Void
    var deleteAction: () -> Void
    var renameAction: () -> Void
    var tagAction: () -> Void
    var shareAction: () -> Void
    var linkPreviewAction: (() -> Void)? = nil
    var onTagLongPress: ((String) -> Void)? = nil
    /// Callback when link preview title is fetched - used for auto-rename
    var onLinkTitleFetched: ((String) -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme
    
    // Check if item is a URL type
    private var isLinkType: Bool {
        item.type == UTType.url.identifier
    }
    
    // Get content preview text based on item type
    private var contentPreview: String {
        if isLinkType {
            // For links, show the URL
            return item.content
        } else {
            // For text, show the body content only when displayName differs from content
            guard let displayName = item.displayName, displayName != item.content else { return "" }
            return item.content
        }
    }

    var body: some View {
        Group {
            if displayStyle == .compact {
                compactLayout
            } else {
                feedLayout
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, displayStyle == .compact ? 4 : 8)
        .onDrag(createDragItem)
        // Pin indicator overlay - uses red for semantic visibility (pinned = important)
        .overlay(Group { if item.isPinned { CornerTriangleShape().fill(Color.red).frame(width: 12, height: 12).padding([.top, .trailing], 4) } }, alignment: .topTrailing)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeColor, lineWidth: isHighlighted ? 3 : 0)
                .padding(2)
        )
        .animation(.easeInOut, value: isHighlighted)
        .clipped()
    }
    
    // MARK: - Compact Layout (Original style)
    private var compactLayout: some View {
        HStack(spacing: 15) {
            typeIconButton
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName ?? item.content)
                        .lineLimit(1)
                        .font(.callout)
                        .foregroundColor(colorScheme == .light ? Color(.darkGray) : .primary)
                    HStack(spacing: 8) {
                        if let tags = item.tags, !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) { 
                                HStack { 
                                    ForEach(tags, id: \.self) { tag in 
                                        let customColor = clipboardManager?.getTagColor(tag)
                                        let tagColor = customColor ?? Color.gray.opacity(0.2)
                                        let textColor = customColor != nil ? Color.white : Color.primary
                                        TagChipView(
                                            tag: tag,
                                            tagColor: tagColor,
                                            textColor: textColor,
                                            onFilter: {
                                                if let onTagLongPress = self.onTagLongPress {
                                                    onTagLongPress(tag)
                                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                                    generator.impactOccurred()
                                                }
                                            }
                                        )
                                    } 
                                } 
                            }
                        }
                        Spacer()
                        Text(item.timestamp.timeAgoDisplay())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }.frame(height: 20)
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: previewAction)
        }
        .contentShape(Rectangle())
    }
    
    // MARK: - Feed Layout (Social feed style with content preview)
    private var feedLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 15) {
                // Type Icon - top-aligned to match title position in social feed layout
                typeIconButton

                // Content area - VStack for social feed style
                VStack(alignment: .leading, spacing: 6) {
                    // Top: Title (reduced font size: subheadline instead of headline)
                    Text(item.displayName ?? item.content)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(colorScheme == .light ? Color(.darkGray) : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Middle: Content Preview (reduced font size: caption instead of subheadline)
                    if isLinkType {
                        // Link type: show URL with distinct color, limited to 1 line
                        Text(item.content)
                            .font(.caption)
                            .foregroundColor(Color.blue.opacity(0.8))
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    } else if !contentPreview.isEmpty {
                        // Text type: show body content, 3 lines max
                        Text(contentPreview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Bottom: Tags and Date
                    HStack(spacing: 8) {
                        if let tags = item.tags, !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) { 
                                HStack(spacing: 6) { 
                                    ForEach(tags, id: \.self) { tag in 
                                        let customColor = clipboardManager?.getTagColor(tag)
                                        let tagColor = customColor ?? Color.gray.opacity(0.2)
                                        let textColor = customColor != nil ? Color.white : Color.primary
                                        TagChipView(
                                            tag: tag,
                                            tagColor: tagColor,
                                            textColor: textColor,
                                            onFilter: {
                                                if let onTagLongPress = self.onTagLongPress {
                                                    onTagLongPress(tag)
                                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                                    generator.impactOccurred()
                                                }
                                            }
                                        )
                                    } 
                                } 
                            }
                        }
                        Spacer()
                        Text(item.timestamp.timeAgoDisplay())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: previewAction)
            }
            .contentShape(Rectangle())
            
            // Link Preview - loaded asynchronously, only for URL items in feed mode
            if isLinkType && showLinkPreview, let url = URL(string: item.content) {
                CompactLinkPreviewRow(url: url, onTitleFetched: onLinkTitleFetched)
                    .padding(.top, 8)
                    .padding(.leading, 59) // Align with content (44 icon + 15 spacing)
            }
        }
    }
    
    // MARK: - Type Icon Button (shared between layouts)
    private var typeIconButton: some View {
        Button(action: copyAction) {
            // Corner bracket minimalist icon design
            ZStack {
                // Center text
                Text(itemIcon(for: item.type))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
                
                // Corner brackets using themeColor
                // Top-left corner
                Text("┌")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(themeColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                
                // Top-right corner
                Text("┐")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(themeColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                
                // Bottom-left corner
                Text("└")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(themeColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                
                // Bottom-right corner
                Text("┘")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(themeColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Link Preview Loading Queue
/// Manages concurrent link preview loading to prevent app freeze
@MainActor
class LinkPreviewLoadingQueue {
    static let shared = LinkPreviewLoadingQueue()
    
    private var activeTasks: Int = 0
    private let maxConcurrentTasks = 2 // Only allow 2 concurrent loads
    private var pendingContinuations: [CheckedContinuation<Void, Never>] = []
    
    private init() {}
    
    func enqueue(task: @escaping () async -> Void) async {
        // Wait if too many tasks are active
        if activeTasks >= maxConcurrentTasks {
            await withCheckedContinuation { continuation in
                pendingContinuations.append(continuation)
            }
        }
        
        activeTasks += 1
        await task()
        activeTasks -= 1
        
        // Resume next waiting task if any
        if !pendingContinuations.isEmpty {
            let next = pendingContinuations.removeFirst()
            next.resume()
        }
    }
}

// MARK: - Compact Link Preview Row (for feed style)
/// A smaller inline preview for links that loads metadata asynchronously with lazy loading
/// Enhanced with waterfall description extraction
struct CompactLinkPreviewRow: View {
    let url: URL
    /// Callback when title is fetched - used to auto-update item name
    var onTitleFetched: ((String) -> Void)? = nil
    
    @State private var enhancedMetadata: EnhancedLinkMetadata?
    @State private var isLoading = false
    @State private var hasStartedLoading = false
    @State private var hasError = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if !hasStartedLoading {
                // Placeholder before loading starts
                HStack(spacing: 8) {
                    Image(systemName: "link.circle")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("Tap to load preview")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(8)
                .onTapGesture {
                    startLoading()
                }
            } else if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading preview...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(8)
            } else if let enhanced = enhancedMetadata {
                HStack(alignment: .center, spacing: 10) {
                    // Image (if available)
                    if let imageProvider = enhanced.lpMetadata.imageProvider {
                        CompactPreviewImage(imageProvider: imageProvider)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    // Text content: Title + Description (no URL as per user request)
                    VStack(alignment: .leading, spacing: 2) {
                        if let title = enhanced.lpMetadata.title {
                            Text(title)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(2)
                                .foregroundColor(.primary)
                        }
                        // Show description from waterfall extraction
                        if let description = enhanced.description {
                            Text(description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(8)
            } else if hasError {
                // Show error state with retry option
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Failed to load")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Retry") {
                        hasError = false
                        startLoading()
                    }
                    .font(.caption2)
                }
                .padding(8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6).opacity(colorScheme == .dark ? 1.0 : 0.5))
        )
        .onAppear {
            // Check cache immediately on appear - if cached, show it
            if let cached = LinkMetadataManager.shared.getCachedEnhancedMetadata(for: url) {
                enhancedMetadata = cached
                hasStartedLoading = true
                isLoading = false
            }
            // Don't auto-load - user needs to tap to load preview
        }
    }
    
    private func startLoading() {
        guard !isLoading && !hasStartedLoading else { return }
        hasStartedLoading = true
        isLoading = true
        
        Task {
            await fetchMetadata()
        }
    }
    
    @MainActor
    private func fetchMetadata() async {
        // Use the queue to limit concurrent requests
        await LinkPreviewLoadingQueue.shared.enqueue {
            do {
                // Use task group with timeout - whichever finishes first wins
                let result = try await withThrowingTaskGroup(of: EnhancedLinkMetadata?.self) { group in
                    // Task 1: Fetch enhanced metadata (with description)
                    group.addTask {
                        await LinkMetadataManager.shared.fetchEnhancedMetadata(for: self.url)
                    }
                    
                    // Task 2: Timeout after 10 seconds (increased for enhanced fetch)
                    group.addTask {
                        try await Task.sleep(for: .seconds(10))
                        throw TimeoutError()
                    }
                    
                    // Return first successful result
                    while let taskResult = try await group.next() {
                        // Cancel remaining tasks
                        group.cancelAll()
                        return taskResult
                    }
                    
                    return nil
                }
                
                if let fetchedMetadata = result {
                    self.enhancedMetadata = fetchedMetadata
                    // Notify callback with fetched title for auto-rename
                    if let title = fetchedMetadata.lpMetadata.title {
                        self.onTitleFetched?(title)
                    }
                } else {
                    self.hasError = true
                }
            } catch is TimeoutError {
                // Timeout occurred
                self.hasError = true
            } catch {
                // Other error
                self.hasError = true
            }
            
            self.isLoading = false
        }
    }
}

/// Error type for timeout
private struct TimeoutError: Error {}

/// Helper view to load and display images for compact preview
struct CompactPreviewImage: View {
    let imageProvider: NSItemProvider
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            } else {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .frame(width: 48, height: 48)
        .background(Color.gray.opacity(0.1))
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        imageProvider.loadObject(ofClass: UIImage.self) { (object, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("⚠️ Failed to load compact preview image: \(error.localizedDescription)")
                } else if let image = object as? UIImage {
                    self.image = image
                }
                self.isLoading = false
            }
        }
    }
}

struct TagExportSelectionView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Binding var exportURL: URL?
    @Binding var isShowingImportAlert: Bool
    @Binding var importAlertMessage: String?
    @State private var selectedTags: Set<String> = []
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select tags to export")) {
                    List(clipboardManager.allTags, id: \.self) { tag in
                        Button(action: { if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) } }) {
                            HStack { Text(tag); Spacer(); if selectedTags.contains(tag) { Image(systemName: "checkmark").foregroundColor(.accentColor) } }
                        }.foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Selective Export").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Export") { exportSelectedTags() }.disabled(selectedTags.isEmpty) } }
        }
    }
    private func exportSelectedTags() {
        do {
            if let url = try clipboardManager.exportData(forTags: selectedTags) { exportURL = url }
            else { importAlertMessage = "No items found for the selected tags."; isShowingImportAlert = true }
        } catch { importAlertMessage = "Export failed.\nError: \(error.localizedDescription)"; isShowingImportAlert = true }
        dismiss()
    }
}

struct TagFirebaseShareView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Binding var firebaseShareURL: String?
    @Binding var isShowingFirebaseShareAlert: Bool
    @Binding var isShowingImportAlert: Bool
    @Binding var importAlertMessage: String?
    @State private var selectedTags: Set<String> = []
    @State private var isSharingFirebase = false
    @Environment(\.dismiss) var dismiss
    
    // Firebase password settings
    @AppStorage("firebasePasswordEnabled") private var firebasePasswordEnabled: Bool = false
    @AppStorage("firebasePassword") private var firebasePassword: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select tags to share via Firebase")) {
                    List(clipboardManager.allTags, id: \.self) { tag in
                        Button(action: { if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) } }) {
                            HStack { Text(tag); Spacer(); if selectedTags.contains(tag) { Image(systemName: "checkmark").foregroundColor(.accentColor) } }
                        }.foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Share via Firebase").navigationBarTitleDisplayMode(.inline)
            .toolbar { 
                ToolbarItem(placement: .navigationBarTrailing) { 
                    Button {
                        shareSelectedTags()
                    } label: {
                        if isSharingFirebase {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Share")
                        }
                    }
                    .disabled(selectedTags.isEmpty || isSharingFirebase)
                } 
            }
        }
    }
    
    private func shareSelectedTags() {
        print("🔥🔥🔥 shareSelectedTags() CALLED")
        print("🔥 Selected tags: \(selectedTags)")
        let filteredItems = clipboardManager.items.filter { item in
            guard let itemTags = item.tags, !item.isTrashed else { return false }
            return !selectedTags.isDisjoint(with: itemTags)
        }
        print("🔥 Filtered items count: \(filteredItems.count)")
        
        guard !filteredItems.isEmpty else {
            print("🔥 No items found for selected tags")
            importAlertMessage = "No items found for the selected tags."
            isShowingImportAlert = true
            dismiss()
            return
        }
        
        // Get password if enabled
        let password: String? = firebasePasswordEnabled && !firebasePassword.isEmpty ? firebasePassword : nil
        print("🔐 shareSelectedTags: firebasePasswordEnabled=\(firebasePasswordEnabled), hasPassword=\(password != nil)")
        
        print("🔥 Calling FirebaseManager.shareItems with \(filteredItems.count) items")
        isSharingFirebase = true
        FirebaseManager.shared.shareItems(filteredItems, password: password) { result in
            print("🔥 Firebase callback received")
            DispatchQueue.main.async {
                self.isSharingFirebase = false
                switch result {
                case .success(let shareURL):
                    print("🔥 SUCCESS: \(shareURL)")
                    self.firebaseShareURL = shareURL
                    self.isShowingFirebaseShareAlert = true
                    dismiss()
                case .failure(let error):
                    print("🔥 ERROR: \(error.localizedDescription)")
                    self.importAlertMessage = "Firebase share failed.\nError: \(error.localizedDescription)"
                    self.isShowingImportAlert = true
                    dismiss()
                }
            }
        }
    }
}

struct TagEditView: View {
    @Binding var item: ClipboardItem
    @ObservedObject var clipboardManager: ClipboardManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var newTag = ""
    @State private var newTagColor: Color?
    @State private var showColorPicker = false
    @State private var showPaywall = false
    @Environment(\.dismiss) var dismiss
    
    // Theme Color Support
    @AppStorage("themeColorName") private var themeColorName: String = "green"
    @AppStorage("customColorRed") private var customColorRed: Double = 0.0
    @AppStorage("customColorGreen") private var customColorGreen: Double = 0.478
    @AppStorage("customColorBlue") private var customColorBlue: Double = 1.0
    
    var themeColor: Color {
        if themeColorName == "custom" {
            return Color(red: customColorRed, green: customColorGreen, blue: customColorBlue)
        }
        return ClippyIsleAttributes.ColorUtility.color(forName: themeColorName)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Current Tags") {
                    if item.tags?.isEmpty ?? true { Text("No Tags").foregroundColor(.secondary) }
                    else {
                        // **FIX**: Added FlowLayout definition above
                        FlowLayout(alignment: .leading) {
                            ForEach(item.tags ?? [], id: \.self) { tag in
                                HStack { Text(tag); Button(action: { removeTag(tag) }) { Image(systemName: "xmark") } }
                                .padding(.horizontal, 8).padding(.vertical, 4).background(Color.gray.opacity(0.2)).clipShape(Capsule()).buttonStyle(.plain)
                            }
                        }
                    }
                }
                Section("Add from Existing Tags") {
                    let existingTags = clipboardManager.allTags.filter { !(item.tags?.contains($0) ?? false) }
                    if existingTags.isEmpty { Text("No Other Tags").foregroundColor(.secondary) }
                    else {
                        FlowLayout(alignment: .leading) {
                            ForEach(existingTags, id: \.self) { tag in
                                Button(action: { addTag(tag) }) { Text(tag).padding(.horizontal, 10).padding(.vertical, 5).background(Color.accentColor.opacity(0.2)).foregroundColor(.accentColor).clipShape(Capsule()) }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                Section("Add New Tag") {
                    HStack {
                        TextField("Enter new tag...", text: $newTag).onSubmit(addNewTag)
                        
                        if subscriptionManager.isPro {
                            Button(action: { showColorPicker = true }) {
                                if let color = newTagColor {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 24, height: 24)
                                } else {
                                    Image(systemName: "paintpalette")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button("Add", action: addNewTag).disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    if !subscriptionManager.isPro {
                        Text("Upgrade to Pro to set tag colors").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Tags").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showColorPicker) {
                NavigationView {
                    Form {
                        Section("Preview") {
                            if !newTag.isEmpty {
                                HStack {
                                    Text(newTag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(newTagColor ?? Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        
                        Section("Choose Color") {
                            ColorPicker("Color", selection: Binding(
                                get: { newTagColor ?? Color.blue },
                                set: { newTagColor = $0 }
                            ), supportsOpacity: false)
                        }
                        
                        Section {
                            Button("Clear Color") {
                                newTagColor = nil
                                showColorPicker = false
                            }
                        }
                    }
                    .navigationTitle("Tag Color")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") { showColorPicker = false }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showColorPicker = false }
                        }
                    }
                }
            }
        }
        .tint(themeColor)
    }
    private func addTag(_ tag: String) { var tags = item.tags ?? []; if !tags.contains(tag) { tags.append(tag); clipboardManager.updateTags(for: &item, newTags: tags) } }
    private func removeTag(_ tag: String) { var tags = item.tags ?? []; tags.removeAll { $0 == tag }; clipboardManager.updateTags(for: &item, newTags: tags) }
    private func addNewTag() { 
        let name = newTag.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { 
            addTag(name)
            // Set color if selected
            if let color = newTagColor {
                clipboardManager.setTagColor(name, color: color)
            }
            newTag = ""
            newTagColor = nil
        }
    }
}

// **MODIFIED**: Added tag sharing functionality, replaced Edit button with Share button
struct TagFilterView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var selectedTag: String?
    @State private var tagToRename: String?
    @State private var newTagName = ""
    @State private var isShowingRenameAlert = false
    @State private var tags: [String] = []
    @State private var isSelectMode = false
    @State private var selectedTags: Set<String> = []
    @State private var exportURL: URL?
    @State private var tagToColor: String?
    @State private var showColorPicker = false
    @State private var showPaywall = false
    @State private var refreshTrigger = false
    @State private var isSharingFirebase = false
    @State private var firebaseShareURL: String?
    @State private var showShareSheet = false
    @State private var showSizeError = false
    @Environment(\.dismiss) var dismiss
    
    // Theme Color Support
    @AppStorage("themeColorName") private var themeColorName: String = "green"
    @AppStorage("customColorRed") private var customColorRed: Double = 0.0
    @AppStorage("customColorGreen") private var customColorGreen: Double = 0.478
    @AppStorage("customColorBlue") private var customColorBlue: Double = 1.0
    
    // Firebase password settings
    @AppStorage("firebasePasswordEnabled") private var firebasePasswordEnabled: Bool = false
    @AppStorage("firebasePassword") private var firebasePassword: String = ""
    
    var themeColor: Color {
        if themeColorName == "custom" {
            return Color(red: customColorRed, green: customColorGreen, blue: customColorBlue)
        }
        return ClippyIsleAttributes.ColorUtility.color(forName: themeColorName)
    }

    var body: some View {
        NavigationView {
            List {
                if !isSelectMode {
                    Button { selectedTag = nil; dismiss() } label: { HStack { Image(systemName: selectedTag == nil ? "checkmark.circle.fill" : "circle"); Text("All Items") } }.foregroundColor(.primary)
                }
                Section("Tags") {
                    ForEach(tags, id: \.self) { tag in
                        if isSelectMode {
                            Button {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedTags.contains(tag) ? "checkmark.circle.fill" : "circle")
                                    Text(tag)
                                    Spacer()
                                }
                            }.foregroundColor(.primary)
                        } else {
                            Button { selectedTag = tag; dismiss() } label: { 
                                HStack { 
                                    Image(systemName: selectedTag == tag ? "checkmark.circle.fill" : "circle")
                                    if let customColor = clipboardManager.getTagColor(tag) {
                                        Circle()
                                            .fill(customColor)
                                            .frame(width: 12, height: 12)
                                    }
                                    Text(tag)
                                } 
                            }
                            .foregroundColor(.primary)
                            .id("\(tag)-\(refreshTrigger)")
                            .swipeActions {
                                Button("Delete", role: .destructive) { 
                                    clipboardManager.deleteTagFromAllItems(tag)
                                    tags = clipboardManager.allTags
                                }
                                Button("Color") { 
                                    if subscriptionManager.isPro {
                                        // Set tagToColor before triggering sheet to avoid race condition
                                        // Async ensures tagToColor is set before sheet content evaluates
                                        tagToColor = tag
                                        DispatchQueue.main.async {
                                            showColorPicker = true
                                        }
                                    } else {
                                        showPaywall = true
                                    }
                                }.tint(Color(UIColor.systemBlue).opacity(0.55))
                                Button("Rename") { tagToRename = tag; newTagName = tag; isShowingRenameAlert = true }.tint(Color(UIColor.systemBlue).opacity(0.55))
                            }
                        }
                    }
                    .onMove { from, to in
                        tags.move(fromOffsets: from, toOffset: to)
                        clipboardManager.saveTagOrder(tags)
                    }
                }
            }
            .navigationTitle("Tag Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if isSelectMode {
                            // Cancel selection mode
                            isSelectMode = false
                            selectedTags.removeAll()
                        } else {
                            // Enter selection mode
                            isSelectMode = true
                            selectedTags.removeAll()
                        }
                    } label: {
                        Text(isSelectMode ? "Cancel" : "Share")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelectMode {
                        Button {
                            shareSelectedTagsViaFirebase()
                        } label: {
                            if isSharingFirebase {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Send")
                            }
                        }
                        .disabled(selectedTags.isEmpty || isSharingFirebase)
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .alert("Rename Tag", isPresented: $isShowingRenameAlert) {
                TextField("New tag name", text: $newTagName)
                Button("Save") {
                    if let oldName = tagToRename {
                        clipboardManager.renameTag(from: oldName, to: newTagName)
                        tags = clipboardManager.allTags
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                tags = clipboardManager.allTags
            }
            .sheet(item: $exportURL) { url in
                ActivityView(activityItems: [url])
            }
            .sheet(isPresented: $showColorPicker) {
                if let tag = tagToColor {
                    NavigationView {
                        TagColorPickerView(tag: tag, clipboardManager: clipboardManager, isPresented: $showColorPicker, onSave: {
                            // Force refresh of the view by toggling state
                            refreshTrigger.toggle()
                        })
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showShareSheet) {
                if let urlString = firebaseShareURL {
                    ActivityView(activityItems: [urlString])
                }
            }
            .alert("Size Limit Exceeded", isPresented: $showSizeError) {
                Button("OK") {}
            } message: {
                Text("The selected items exceed the 900KB limit for Firebase sharing. Please use JSON export instead.")
            }
        }
        .tint(themeColor)
    }
    
    private func exportSelectedTags() {
        do {
            if let url = try clipboardManager.exportData(forTags: selectedTags) {
                exportURL = url
            }
        } catch {
            print("Export failed: \(error.localizedDescription)")
        }
    }
    
    private func shareSelectedTagsViaFirebase() {
        let filteredItems = clipboardManager.items.filter { item in
            guard let itemTags = item.tags, !item.isTrashed else { return false }
            return !selectedTags.isDisjoint(with: itemTags)
        }
        
        guard !filteredItems.isEmpty else {
            return
        }
        
        // Check size limit (900KB) - estimate using ClipboardItem encoding
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(filteredItems),
           data.count > 900 * 1024 {
            showSizeError = true
            return
        }
        
        // Get password if enabled
        let password: String? = firebasePasswordEnabled && !firebasePassword.isEmpty ? firebasePassword : nil
        print("🔐 shareSelectedTagsViaFirebase: firebasePasswordEnabled=\(firebasePasswordEnabled), hasPassword=\(password != nil)")
        
        isSharingFirebase = true
        FirebaseManager.shared.shareItems(filteredItems, password: password) { result in
            DispatchQueue.main.async {
                self.isSharingFirebase = false
                switch result {
                case .success(let shareURL):
                    self.firebaseShareURL = shareURL
                    self.showShareSheet = true
                    // Exit select mode after successful share
                    self.isSelectMode = false
                    self.selectedTags.removeAll()
                case .failure(let error):
                    print("Firebase share failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Tag Color Management View (Pro Feature)
struct TagColorManagementView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var tags: [String] = []
    @State private var selectedTag: String?
    @State private var showColorPicker = false
    @State private var showPaywall = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            Section {
                if !subscriptionManager.isPro {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "crown.fill").foregroundColor(.yellow)
                            Text("Pro Feature").fontWeight(.semibold)
                        }
                        Text("Upgrade to Pro to customize tag colors")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Upgrade to Pro") {
                            showPaywall = true
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                }
            }
            
            if subscriptionManager.isPro {
                Section("Tag Colors") {
                    ForEach(tags, id: \.self) { tag in
                        let customColor = clipboardManager.getTagColor(tag)
                        HStack {
                            if let color = customColor {
                                Circle()
                                    .fill(color)
                                    .frame(width: 24, height: 24)
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 24, height: 24)
                            }
                            
                            Text(tag)
                            
                            Spacer()
                            
                            Button(action: { selectedTag = tag; showColorPicker = true }) {
                                Text(customColor == nil ? "Set Color" : "Change")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            if customColor != nil {
                                Button(action: { clipboardManager.setTagColor(tag, color: nil) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Tag Colors")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            tags = clipboardManager.allTags
        }
        .sheet(isPresented: $showColorPicker) {
            if let tag = selectedTag {
                TagColorPickerView(tag: tag, clipboardManager: clipboardManager, isPresented: $showColorPicker)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

// MARK: - Tag Color Picker View
struct TagColorPickerView: View {
    let tag: String
    @ObservedObject var clipboardManager: ClipboardManager
    @Binding var isPresented: Bool
    var onSave: (() -> Void)?
    @State private var selectedColor: Color
    
    init(tag: String, clipboardManager: ClipboardManager, isPresented: Binding<Bool>, onSave: (() -> Void)? = nil) {
        self.tag = tag
        self.clipboardManager = clipboardManager
        self._isPresented = isPresented
        self.onSave = onSave
        self._selectedColor = State(initialValue: clipboardManager.getTagColor(tag) ?? Color.blue)
    }
    
    var body: some View {
        Form {
            Section("Preview") {
                HStack {
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(selectedColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            Section("Choose Color") {
                ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)
            }
        }
        .navigationTitle("Tag Color")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { isPresented = false }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    clipboardManager.setTagColor(tag, color: selectedColor)
                    onSave?()
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - Shared Items Import View
/// View for displaying received shared items and allowing selective import
struct SharedItemsImportView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    let pendingItems: [ClipboardItem]
    @Binding var isPresented: Bool
    @State private var selectedItems: Set<UUID> = []
    @Environment(\.dismiss) var dismiss
    
    // Theme Color Support
    @AppStorage("themeColorName") private var themeColorName: String = "green"
    @AppStorage("customColorRed") private var customColorRed: Double = 0.0
    @AppStorage("customColorGreen") private var customColorGreen: Double = 0.478
    @AppStorage("customColorBlue") private var customColorBlue: Double = 1.0
    
    var themeColor: Color {
        if themeColorName == "custom" {
            return Color(red: customColorRed, green: customColorGreen, blue: customColorBlue)
        }
        return ClippyIsleAttributes.ColorUtility.color(forName: themeColorName)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header info
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(themeColor)
                    Text("Received \(pendingItems.count) item(s)")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Selection controls
                HStack {
                    Button(action: selectAll) {
                        Text("Select All")
                            .font(.subheadline)
                    }
                    .disabled(selectedItems.count == pendingItems.count)
                    
                    Spacer()
                    
                    Text("\(selectedItems.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: deselectAll) {
                        Text("Deselect All")
                            .font(.subheadline)
                    }
                    .disabled(selectedItems.isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Items list
                List {
                    ForEach(pendingItems) { item in
                        Button(action: { toggleSelection(item) }) {
                            HStack(spacing: 12) {
                                // Selection indicator
                                Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedItems.contains(item.id) ? themeColor : .secondary)
                                    .font(.title3)
                                
                                // Item icon
                                Text(itemIcon(for: item.type))
                                    .font(.system(size: 20))
                                
                                // Item content
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.displayName ?? item.content)
                                        .lineLimit(2)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    HStack(spacing: 8) {
                                        // Show tags if any
                                        if let tags = item.tags, !tags.isEmpty {
                                            ForEach(tags.prefix(3), id: \.self) { tag in
                                                Text(tag)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 2)
                                                    .background(Color.gray.opacity(0.2))
                                                    .cornerRadius(4)
                                            }
                                            if tags.count > 3 {
                                                Text("+\(tags.count - 3)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // Item type indicator
                                        Text(itemTypeLabel(for: item.type))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Shared Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        importSelectedItems()
                    }
                    .disabled(selectedItems.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .tint(themeColor)
        .onAppear {
            // Pre-select all items by default
            selectedItems = Set(pendingItems.map { $0.id })
        }
    }
    
    private func toggleSelection(_ item: ClipboardItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
    
    private func selectAll() {
        selectedItems = Set(pendingItems.map { $0.id })
    }
    
    private func deselectAll() {
        selectedItems.removeAll()
    }
    
    private func importSelectedItems() {
        let itemsToImport = pendingItems.filter { selectedItems.contains($0.id) }
        
        for item in itemsToImport {
            // Create new item with fresh timestamp for import
            let importedItem = ClipboardItem(
                content: item.content,
                type: item.type,
                filename: item.filename,
                timestamp: Date(), // Use current time for import
                isPinned: false, // Don't preserve pinned status on import
                displayName: item.displayName,
                isTrashed: false, // Don't import trashed items
                tags: item.tags,
                fileData: item.fileData
            )
            
            // Insert at beginning
            clipboardManager.items.insert(importedItem, at: 0)
        }
        
        // Save all changes at once
        clipboardManager.sortAndSave()
        
        print("✅ Successfully imported \(itemsToImport.count) item(s)")
        
        dismiss()
    }
    
    private func itemTypeLabel(for type: String) -> String {
        switch type {
        case UTType.url.identifier:
            return "URL"
        case UTType.png.identifier, UTType.jpeg.identifier:
            return "Image"
        case UTType.pdf.identifier:
            return "PDF"
        case UTType.rtf.identifier:
            return "RTF"
        default:
            return "Text"
        }
    }
}