import SwiftUI

/// View for displaying incoming shared groups and importing them
struct IncomingShareView: View {
    @StateObject private var shareGroupManager = ShareGroupManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var sharedGroups: [ShareGroup] = []
    @State private var isLoading = false
    @State private var selectedGroup: ShareGroup?
    @State private var showImportSuccess = false
    @State private var importedCount = 0
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading shared items...")
                } else if sharedGroups.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle("Incoming Shares")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Import Successful", isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Successfully imported \(importedCount) items to your library.")
            }
        }
        .task {
            await loadSharedGroups()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Shared Items")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("When someone shares items with you, they'll appear here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var listView: some View {
        List {
            ForEach(sharedGroups, id: \.objectID) { group in
                ShareGroupCard(
                    group: group,
                    onImport: {
                        await importGroup(group)
                    }
                )
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func loadSharedGroups() async {
        isLoading = true
        defer { isLoading = false }
        
        await MainActor.run {
            sharedGroups = shareGroupManager.fetchIncomingSharedGroups()
        }
    }
    
    private func importGroup(_ group: ShareGroup) async {
        do {
            let count = try await shareGroupManager.importSharedItems(from: group)
            
            await MainActor.run {
                importedCount = count
                showImportSuccess = true
                
                // Remove from list after successful import
                sharedGroups.removeAll { $0.objectID == group.objectID }
                
                // Optionally, leave the share to clean up
                Task {
                    try? await shareGroupManager.leaveShare(group)
                }
            }
        } catch {
            print("❌ Failed to import group: \(error)")
            // TODO: Show error alert
        }
    }
}

/// Card view for displaying a single ShareGroup
struct ShareGroupCard: View {
    let group: ShareGroup
    let onImport: () async -> Void
    
    @State private var isImporting = false
    
    private var itemCount: Int {
        (group.items?.count ?? 0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and date
            VStack(alignment: .leading, spacing: 4) {
                Text(group.title ?? "Untitled")
                    .font(.headline)
                
                if let createdAt = group.createdAt {
                    Text("Shared \(createdAt, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Item count
            HStack {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.blue)
                Text("You received \(itemCount) \(itemCount == 1 ? "item" : "items")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Import button
            Button(action: {
                Task {
                    isImporting = true
                    await onImport()
                    isImporting = false
                }
            }) {
                HStack {
                    if isImporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text(isImporting ? "Importing..." : "Import to Library")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isImporting)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview Provider

struct IncomingShareView_Previews: PreviewProvider {
    static var previews: some View {
        IncomingShareView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
