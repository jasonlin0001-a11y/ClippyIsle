import SwiftUI
import UniformTypeIdentifiers

struct TrashView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
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
    
    private var cardBackground: Color {
        colorScheme == .dark ? ClippyIsleAttributes.ColorUtility.darkCard : Color(.systemBackground)
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? ClippyIsleAttributes.ColorUtility.darkBorder : Color(.separator).opacity(0.3)
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(clipboardManager.items.filter { $0.isTrashed }) { item in
                    HStack(spacing: 14) {
                        // Modern icon styling
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(colorScheme == .dark ? 0.2 : 0.1))
                                .frame(width: 38, height: 38)
                            Text(itemIcon(for: item.type))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayName ?? item.content)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .lineLimit(1)
                                .foregroundColor(colorScheme == .dark ? .white : Color(.darkGray))
                            Text(item.timestamp.timeAgoDisplay())
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(cardBackground)
                            .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(cardBorder, lineWidth: 0.5)
                    )
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .leading) {
                        Button("Recover") {
                            clipboardManager.recoverItemFromTrash(item: item)
                        }
                        .tint(themeColor)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            clipboardManager.permanentlyDeleteItem(item: item)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(colorScheme == .dark ? ClippyIsleAttributes.ColorUtility.darkBackground : Color(.systemGroupedBackground))
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
        .tint(themeColor)
    }
}
