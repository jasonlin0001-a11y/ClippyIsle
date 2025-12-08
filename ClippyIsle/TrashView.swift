import SwiftUI
import UniformTypeIdentifiers

struct TrashView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(clipboardManager.items.filter { $0.isTrashed }) { item in
                    HStack {
                        Image(systemName: itemIcon(for: item.type))
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading) {
                            Text(item.displayName ?? item.content)
                                .lineLimit(1)
                            Text(item.timestamp.timeAgoDisplay())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .swipeActions(edge: .leading) {
                        Button("Recover") {
                            clipboardManager.recoverItemFromTrash(item: item)
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            clipboardManager.permanentlyDeleteItem(item: item)
                        }
                    }
                }
            }
            .navigationTitle("Trash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Empty Trash", role: .destructive) {
                        clipboardManager.emptyTrash()
                    }
                    .disabled(clipboardManager.items.filter({ $0.isTrashed }).isEmpty)
                }
            }
        }
    }
}
