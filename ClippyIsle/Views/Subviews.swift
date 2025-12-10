import SwiftUI
import UniformTypeIdentifiers
import LinkPresentation

// MARK: - Helper Components (Missing Shapes & Layouts)

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
    
    var copyAction: () -> Void
    var previewAction: () -> Void
    var createDragItem: () -> NSItemProvider
    var togglePinAction: () -> Void
    var deleteAction: () -> Void
    var renameAction: () -> Void
    var tagAction: () -> Void
    var shareAction: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 15) {
            Button(action: copyAction) {
                Image(systemName: itemIcon(for: item.type))
                    .font(.title3)
                    .frame(width: 30)
                    .foregroundColor(themeColor)
            }
            .buttonStyle(.plain)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName ?? item.content).lineLimit(1).font(.body).foregroundColor(colorScheme == .light ? Color(.darkGray) : .primary)
                    HStack(spacing: 8) {
                        if let tags = item.tags, !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(tags, id: \.self) { tag in Text(tag).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.2)).cornerRadius(8) } } }
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
    @State private var newTag = ""
    @Environment(\.dismiss) var dismiss

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
                    TextField("Enter new tag...", text: $newTag).onSubmit(addNewTag)
                    Button("Add", action: addNewTag).disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Edit Tags").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
    private func addTag(_ tag: String) { var tags = item.tags ?? []; if !tags.contains(tag) { tags.append(tag); clipboardManager.updateTags(for: &item, newTags: tags) } }
    private func removeTag(_ tag: String) { var tags = item.tags ?? []; tags.removeAll { $0 == tag }; clipboardManager.updateTags(for: &item, newTags: tags) }
    private func addNewTag() { let name = newTag.trimmingCharacters(in: .whitespaces); if !name.isEmpty { addTag(name); newTag = "" } }
}

// **MODIFIED**: Added tag sharing functionality, replaced Edit button with Share button
struct TagFilterView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Binding var selectedTag: String?
    @State private var tagToRename: String?
    @State private var newTagName = ""
    @State private var isShowingRenameAlert = false
    @State private var tags: [String] = []
    @State private var isSelectMode = false
    @State private var selectedTags: Set<String> = []
    @State private var exportURL: URL?
    @Environment(\.dismiss) var dismiss

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
                            Button { selectedTag = tag; dismiss() } label: { HStack { Image(systemName: selectedTag == tag ? "checkmark.circle.fill" : "circle"); Text(tag) } }.foregroundColor(.primary)
                            .swipeActions {
                                Button("Delete", role: .destructive) { 
                                    clipboardManager.deleteTagFromAllItems(tag)
                                    tags = clipboardManager.allTags
                                }
                                Button("Rename") { tagToRename = tag; newTagName = tag; isShowingRenameAlert = true }.tint(.blue)
                            }
                        }
                    }
                    .onMove { from, to in
                        tags.move(fromOffsets: from, toOffset: to)
                        clipboardManager.saveTagOrder(tags)
                    }
                }
            }
            .navigationTitle("Filter by Tag")
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
        }
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