import SwiftUI
import Combine

/// View for creating and sharing a group of clipboard items
struct CreateShareGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var shareGroupManager = ShareGroupManager.shared
    @StateObject private var sharePresenter = SharePresenter()
    
    let selectedItems: [ClipboardItem]
    
    @State private var groupTitle: String = ""
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
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
            .onChange(of: sharePresenter.isPresenting) { oldValue, newValue in
                if !newValue {
                    // Dismiss the view after sharing is complete
                    dismiss()
                }
            }
        }
    }
    
    private func createAndShare() async {
        isCreating = true
        defer { isCreating = false }
        
        do {
            let trimmedTitle = groupTitle.trimmingCharacters(in: .whitespaces)
            let finalTitle = trimmedTitle.isEmpty ? String(localized: "Shared Items") : trimmedTitle
            
            let group = try shareGroupManager.createShareGroup(
                with: selectedItems,
                title: finalTitle
            )
            
            // Present the share controller
            await MainActor.run {
                sharePresenter.presentShare(for: group) {
                    // Will be called when sharing completes or fails
                }
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create share group: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

/// Helper class for presenting UICloudSharingController
@MainActor
class SharePresenter: NSObject, UICloudSharingControllerDelegate, ObservableObject {
    @Published var isPresenting = false
    private var onComplete: (() -> Void)?
    
    func presentShare(for shareGroup: ShareGroup, onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        self.isPresenting = true
        
        Task {
            do {
                // Get the key window's root view controller
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                    throw NSError(domain: "SharePresenter", code: -1, 
                                userInfo: [NSLocalizedDescriptionKey: "No window found. Please make sure the app is in foreground."])
                }
                
                // Find the topmost presented view controller
                var topViewController = rootViewController
                while let presented = topViewController.presentedViewController {
                    topViewController = presented
                }
                
                print("📱 Presenting share controller from: \(type(of: topViewController))")
                
                // Present the share controller
                try await ShareGroupManager.shared.shareGroup(shareGroup, from: topViewController, delegate: self)
                
            } catch {
                print("❌ Share presentation failed: \(error.localizedDescription)")
                self.isPresenting = false
                onComplete()
            }
        }
    }
    
    // MARK: - UICloudSharingControllerDelegate
    
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("❌ Failed to save share: \(error.localizedDescription)")
        isPresenting = false
        onComplete?()
    }
    
    func itemTitle(for csc: UICloudSharingController) -> String? {
        return "Shared Clipboard Items"
    }
    
    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        print("✅ Share saved successfully")
        isPresenting = false
        onComplete?()
    }
    
    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        print("ℹ️ Stopped sharing")
        isPresenting = false
        onComplete?()
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
