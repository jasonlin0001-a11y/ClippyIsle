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

// **MODIFIED**: Added tag sharing functionality, replaced Export button with Share button using Firebase
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
    @State private var firebaseShareURL: String?
    @State private var isShowingFirebaseShareAlert = false
    @State private var showShareSheet = false
    @State private var isSharingFirebase = false
    @State private var shareErrorMessage: String?
    @State private var isShowingShareError = false
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
            .alert("Share Link Created", isPresented: $isShowingFirebaseShareAlert, presenting: firebaseShareURL) { url in
                Button("Copy Link") { 
                    UIPasteboard.general.string = url
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
                Button("Share") {
                    showShareSheet = true
                }
                Button("OK") {}
            } message: { url in 
                Text("Share this link with others to let them import your clipboard items:\n\n\(url)")
            }
            .alert("Share Failed", isPresented: $isShowingShareError, presenting: shareErrorMessage) { msg in
                Button("OK") {}
            } message: { msg in 
                Text(msg)
            }
            .onAppear {
                tags = clipboardManager.allTags
            }
            .sheet(item: $exportURL) { url in
                ActivityView(activityItems: [url])
            }
            .sheet(isPresented: $showShareSheet) {
                if let urlString = firebaseShareURL {
                    ActivityView(activityItems: [urlString])
                }
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
    
    private func shareSelectedTags() {
        let filteredItems = clipboardManager.items.filter { item in
            guard let itemTags = item.tags, !item.isTrashed else { return false }
            return !selectedTags.isDisjoint(with: itemTags)
        }
        
        guard !filteredItems.isEmpty else {
            shareErrorMessage = "No items found for the selected tags."
            isShowingShareError = true
            return
        }
        
        isSharingFirebase = true
        
        // Get Firebase password setting if enabled
        let firebasePassword = FirebaseManager.getSharePassword()
        
        FirebaseManager.shared.shareItems(filteredItems, password: firebasePassword) { result in
            // Completion is already called on main thread from FirebaseManager
            self.isSharingFirebase = false
            switch result {
            case .success(let shareURL):
                self.firebaseShareURL = shareURL
                self.isShowingFirebaseShareAlert = true
            case .failure(let error):
                // Check if it's a size limit error
                if let nsError = error as NSError?, nsError.code == 413 {
                    self.shareErrorMessage = nsError.localizedDescription
                } else {
                    self.shareErrorMessage = "Firebase share failed: \(error.localizedDescription)"
                }
                self.isShowingShareError = true
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