import SwiftUI
import CloudKit
import UIKit
import UniformTypeIdentifiers

/// SwiftUI wrapper for UICloudSharingController
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let item: ClipboardItemEntity
    
    @Environment(\.dismiss) private var dismiss
    
    init(item: ClipboardItemEntity, share: CKShare, container: CKContainer) {
        self.item = item
        self.share = share
        self.container = container
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(item: item, dismiss: dismiss)
    }
    
    func makeUIViewController(context: Context) -> UICloudSharingController {
        // Configure the share
        share[CKShare.SystemFieldKey.title] = item.displayName ?? "Clipboard Item"
        
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
        controller.modalPresentationStyle = .formSheet
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {
        // No updates needed
    }
    
    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let item: ClipboardItemEntity
        let dismiss: DismissAction
        
        init(item: ClipboardItemEntity, dismiss: DismissAction) {
            self.item = item
            self.dismiss = dismiss
        }
        
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("Failed to save share: \(error.localizedDescription)")
            dismiss()
        }
        
        func itemTitle(for csc: UICloudSharingController) -> String? {
            return item.displayName ?? "Clipboard Item"
        }
        
        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            // Create a simple thumbnail image with the item type icon
            let size = CGSize(width: 200, height: 200)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            let image = renderer.image { context in
                // Background
                UIColor.systemBackground.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                
                // Icon based on content type using UTType conformance
                let iconName: String
                if let utType = UTType(item.type) {
                    if utType.conforms(to: .image) {
                        iconName = "photo"
                    } else if utType.conforms(to: .url) {
                        iconName = "link"
                    } else {
                        iconName = "doc.text"
                    }
                } else {
                    iconName = "doc.text"
                }
                
                let icon = UIImage(systemName: iconName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 80))
                UIColor.systemBlue.setFill()
                icon?.withTintColor(.systemBlue).draw(in: CGRect(x: 60, y: 60, width: 80, height: 80))
            }
            
            return image.pngData()
        }
        
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            print("Share saved successfully")
            dismiss()
        }
        
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            print("Sharing stopped")
            dismiss()
        }
    }
}

/// View modifier to present CloudSharingView
struct CloudSharingModifier: ViewModifier {
    @Binding var isPresented: Bool
    let item: ClipboardItemEntity
    let container: CKContainer
    
    @State private var share: CKShare?
    @State private var isLoading = false
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                if let share = share {
                    CloudSharingView(item: item, share: share, container: container)
                } else if isLoading {
                    ProgressView("Preparing to share...")
                        .padding()
                } else {
                    Text("Unable to share this item")
                        .padding()
                }
            }
            .onChange(of: isPresented) { _, newValue in
                if newValue && share == nil {
                    prepareShare()
                }
            }
    }
    
    private func prepareShare() {
        isLoading = true
        
        // Check if already shared
        if let existingShare = PersistenceController.shared.existingShare(for: item) {
            share = existingShare
            isLoading = false
            return
        }
        
        // Create new share
        PersistenceController.shared.createShare(for: item) { newShare, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    print("Error creating share: \(error.localizedDescription)")
                    isPresented = false
                } else {
                    share = newShare
                }
            }
        }
    }
}

extension View {
    func cloudSharing(isPresented: Binding<Bool>, item: ClipboardItemEntity, container: CKContainer) -> some View {
        modifier(CloudSharingModifier(isPresented: isPresented, item: item, container: container))
    }
}
