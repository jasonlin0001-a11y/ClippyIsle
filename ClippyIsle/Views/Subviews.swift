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

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let themeColor: Color
    var isHighlighted: Bool = false
    var clipboardManager: ClipboardManager? = nil
    
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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 15) {
            Button(action: copyAction) {
                Text(itemIcon(for: item.type))
                    .font(.system(size: 24, weight: .bold))
                    .frame(width: 30)
                    .foregroundColor(themeColor)
            }
            .buttonStyle(.plain)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName ?? item.content).lineLimit(1).font(.body).foregroundColor(colorScheme == .light ? Color(.darkGray) : .primary)
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
                                                    // Add haptic feedback
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
                        Text(item.timestamp.timeAgoDisplay()).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }.frame(height: 20)
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: previewAction)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .padding(.horizontal, isHighlighted ? 8 : 0)
        .onDrag(createDragItem)
        .swipeActions(edge: .leading) {
            Button("Share", action: shareAction).tint(.blue)
            Button(item.isPinned ? "Unpin" : "Pin", action: togglePinAction).tint(Color(UIColor.systemGray4))
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", action: deleteAction).tint(Color(UIColor.systemGray3))
            Button("Tag", action: tagAction).tint(Color(UIColor.systemBlue).opacity(0.55))
            Button("Rename", action: renameAction).tint(Color(UIColor.systemBlue).opacity(0.55))
        }
        // **FIX**: Updated padding syntax and added shape
        .overlay(Group { if item.isPinned { CornerTriangleShape().fill(Color.red).frame(width: 12, height: 12).padding([.top, .trailing], 4) } }, alignment: .topTrailing)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeColor, lineWidth: isHighlighted ? 3 : 0)
                .padding(2)
        )
        .animation(.easeInOut, value: isHighlighted)
        .clipped()
    }
}

struct TagExportSelectionView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Binding var exportURL: URL?
    @Binding var isShowingImportAlert: Bool
    @Binding var importAlertMessage: String?
    @State private var selectedTags: Set<String> = []
    @State private var isSharing = false
    @State private var shareURL: String?
    @AppStorage("firebaseSharePassword") private var firebaseSharePassword: String = ""
    @AppStorage("firebaseEncryptionEnabled") private var firebaseEncryptionEnabled: Bool = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select tags to share")) {
                    List(clipboardManager.allTags, id: \.self) { tag in
                        Button(action: { if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) } }) {
                            HStack { Text(tag); Spacer(); if selectedTags.contains(tag) { Image(systemName: "checkmark").foregroundColor(.accentColor) } }
                        }.foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Share by Tags").navigationBarTitleDisplayMode(.inline)
            .toolbar { 
                ToolbarItem(placement: .navigationBarTrailing) { 
                    Button(isSharing ? "Sharing..." : "Share") { 
                        shareSelectedTags() 
                    }
                    .disabled(selectedTags.isEmpty || isSharing) 
                } 
            }
        }
    }
    
    private func shareSelectedTags() {
        // Get items with selected tags
        let itemsToShare = clipboardManager.items.filter { item in
            guard let tags = item.tags else { return false }
            return !Set(tags).isDisjoint(with: selectedTags)
        }
        
        if itemsToShare.isEmpty {
            importAlertMessage = "No items found for the selected tags."
            isShowingImportAlert = true
            dismiss()
            return
        }
        
        // Check total size (900KB limit)
        do {
            let itemDicts = itemsToShare.map { itemToDictionary($0) }
            let data = try JSONSerialization.data(withJSONObject: itemDicts, options: [])
            
            if data.count > 921_600 {
                importAlertMessage = "Selected items exceed 900KB limit.\nPlease select fewer tags or use Export function."
                isShowingImportAlert = true
                dismiss()
                return
            }
        } catch {
            importAlertMessage = "Failed to prepare items.\n\(error.localizedDescription)"
            isShowingImportAlert = true
            dismiss()
            return
        }
        
        isSharing = true
        let password = (firebaseEncryptionEnabled && !firebaseSharePassword.isEmpty) ? firebaseSharePassword : nil
        
        FirebaseManager.shared.shareItems(itemsToShare, password: password) { result in
            DispatchQueue.main.async {
                isSharing = false
                
                switch result {
                case .success(let url):
                    shareURL = url
                    // Show native iOS share sheet
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        guard let sourceView = UIApplication.shared.windows.first?.rootViewController?.view else { return }
                        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        if let popover = activityVC.popoverPresentationController {
                            popover.sourceView = sourceView
                            popover.sourceRect = CGRect(x: sourceView.bounds.midX, y: sourceView.bounds.midY, width: 0, height: 0)
                            popover.permittedArrowDirections = []
                        }
                        sourceView.window?.rootViewController?.present(activityVC, animated: true)
                    }
                    
                case .failure(let error):
                    importAlertMessage = "Failed to create share link.\n\(error.localizedDescription)"
                    isShowingImportAlert = true
                    dismiss()
                }
            }
        }
    }
    
    private func itemToDictionary(_ item: ClipboardItem) -> [String: Any] {
        var dict: [String: Any] = [
            "id": item.id.uuidString,
            "content": item.content,
            "type": item.type,
            "timestamp": item.timestamp.timeIntervalSince1970,
            "isPinned": item.isPinned,
            "isTrashed": item.isTrashed
        ]
        if let displayName = item.displayName {
            dict["displayName"] = displayName
        }
        if let filename = item.filename {
            dict["filename"] = filename
        }
        if let tags = item.tags {
            dict["tags"] = tags
        }
        return dict
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
    @Environment(\.dismiss) var dismiss
    
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
                        Button("Export") {
                            exportSelectedTags()
                        }
                        .disabled(selectedTags.isEmpty)
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