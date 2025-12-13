import SwiftUI
import CoreData

/// Main view for managing ShareGroups (both created and received)
struct ShareGroupListView: View {
    @StateObject private var shareGroupManager = ShareGroupManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var allGroups: [ShareGroup] = []
    @State private var incomingGroups: [ShareGroup] = []
    @State private var isLoading = false
    @State private var selectedTab = 0
    
    var ownedGroups: [ShareGroup] {
        allGroups.filter { group in
            // Groups not in incomingGroups are owned by current user
            !incomingGroups.contains(where: { $0.objectID == group.objectID })
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Segmented control for switching between tabs
                Picker("View", selection: $selectedTab) {
                    Text("Received").tag(0)
                    Text("Created").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected tab
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if selectedTab == 0 {
                    incomingGroupsView
                } else {
                    ownedGroupsView
                }
            }
            .navigationTitle("Share Groups")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadGroups()
        }
    }
    
    private var incomingGroupsView: some View {
        Group {
            if incomingGroups.isEmpty {
                emptyStateView(
                    icon: "square.and.arrow.down.on.square",
                    title: "No Received Shares",
                    message: "When someone shares items with you, they'll appear here."
                )
            } else {
                List {
                    ForEach(incomingGroups, id: \.objectID) { group in
                        IncomingGroupRow(group: group) {
                            await loadGroups()
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
    
    private var ownedGroupsView: some View {
        Group {
            if ownedGroups.isEmpty {
                emptyStateView(
                    icon: "square.and.arrow.up.on.square",
                    title: "No Created Shares",
                    message: "Share groups you create will appear here."
                )
            } else {
                List {
                    ForEach(ownedGroups, id: \.objectID) { group in
                        OwnedGroupRow(group: group) {
                            await loadGroups()
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
    
    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadGroups() async {
        isLoading = true
        defer { isLoading = false }
        
        let all = await shareGroupManager.fetchShareGroups()
        let incoming = await shareGroupManager.fetchIncomingSharedGroups()
        
        await MainActor.run {
            allGroups = all
            incomingGroups = incoming
        }
    }
}

/// Row for displaying an incoming (received) share group
struct IncomingGroupRow: View {
    let group: ShareGroup
    let onUpdate: () async -> Void
    
    @State private var isImporting = false
    @State private var showImportSuccess = false
    @State private var importedCount = 0
    
    private var itemCount: Int {
        (group.items?.count ?? 0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.title ?? "Untitled")
                .font(.headline)
            
            HStack {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("\(itemCount) \(itemCount == 1 ? "item" : "items")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let createdAt = group.createdAt {
                    Text("Shared \(createdAt, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: {
                Task {
                    await importGroup()
                }
            }) {
                HStack {
                    if isImporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text(isImporting ? "Importing..." : "Import to Library")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isImporting)
        }
        .padding(.vertical, 4)
        .alert("Import Successful", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Successfully imported \(importedCount) items to your library.")
        }
    }
    
    private func importGroup() async {
        isImporting = true
        defer { isImporting = false }
        
        do {
            let count = try await ShareGroupManager.shared.importSharedItems(from: group)
            
            await MainActor.run {
                importedCount = count
                showImportSuccess = true
            }
            
            // Leave the share after import
            try? await ShareGroupManager.shared.leaveShare(group)
            
            await onUpdate()
        } catch {
            print("❌ Failed to import group: \(error)")
        }
    }
}

/// Row for displaying an owned (created) share group
struct OwnedGroupRow: View {
    let group: ShareGroup
    let onUpdate: () async -> Void
    
    @State private var showDeleteConfirmation = false
    
    private var itemCount: Int {
        (group.items?.count ?? 0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.title ?? "Untitled")
                .font(.headline)
            
            HStack {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("\(itemCount) \(itemCount == 1 ? "item" : "items")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let createdAt = group.createdAt {
                    Text("Created \(createdAt, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(role: .destructive, action: {
                showDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Share Group")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
        .confirmationDialog("Delete Share Group?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await deleteGroup()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will delete the share group and stop sharing with others. This cannot be undone.")
        }
    }
    
    private func deleteGroup() async {
        do {
            try ShareGroupManager.shared.deleteShareGroup(group)
            await onUpdate()
        } catch {
            print("❌ Failed to delete group: \(error)")
        }
    }
}

// MARK: - Preview Provider

struct ShareGroupListView_Previews: PreviewProvider {
    static var previews: some View {
        ShareGroupListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
