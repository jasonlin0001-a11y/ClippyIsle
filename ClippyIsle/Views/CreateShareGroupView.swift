import SwiftUI

/// View for creating and sharing a group of clipboard items
struct CreateShareGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var shareGroupManager = ShareGroupManager.shared
    
    let selectedItems: [ClipboardItem]
    
    @State private var groupTitle: String = ""
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var createdGroup: ShareGroup?
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Group Name", text: $groupTitle)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Share Group Details")
                } footer: {
                    Text("Give this collection a memorable name")
                }
                
                Section {
                    HStack {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                        Text("\(selectedItems.count) items selected")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Selected Items")
                }
                
                Section {
                    ForEach(selectedItems.prefix(5), id: \.id) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayName ?? item.content)
                                .lineLimit(1)
                                .font(.body)
                            
                            Text(item.type)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if selectedItems.count > 5 {
                        Text("... and \(selectedItems.count - 5) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("Create Share Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await createAndShare()
                        }
                    }) {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Share")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isCreating || groupTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showShareSheet) {
                if let group = createdGroup {
                    ShareControllerView(shareGroup: group) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createAndShare() async {
        isCreating = true
        defer { isCreating = false }
        
        do {
            let trimmedTitle = groupTitle.trimmingCharacters(in: .whitespaces)
            let group = try await MainActor.run {
                try shareGroupManager.createShareGroup(
                    with: selectedItems,
                    title: trimmedTitle.isEmpty ? String(localized: "Shared Items") : trimmedTitle
                )
            }
            
            await MainActor.run {
                createdGroup = group
                showShareSheet = true
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

/// UIViewControllerRepresentable for presenting UICloudSharingController
struct ShareControllerView: UIViewControllerRepresentable {
    let shareGroup: ShareGroup
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        Task {
            do {
                try await ShareGroupManager.shared.shareGroup(shareGroup, from: viewController)
            } catch {
                print("❌ Failed to present share controller: \(error)")
            }
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
    
    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: ()) {
        // Clean up if needed
    }
}

// MARK: - Preview Provider

struct CreateShareGroupView_Previews: PreviewProvider {
    static var previews: some View {
        CreateShareGroupView(selectedItems: [
            ClipboardItem(content: "Sample text 1", type: "public.plain-text"),
            ClipboardItem(content: "Sample text 2", type: "public.plain-text"),
            ClipboardItem(content: "https://example.com", type: "public.url")
        ])
    }
}
