import SwiftUI

// MARK: - Radial Menu Item
/// Represents a single item in the radial menu
struct RadialMenuItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let action: () -> Void
}

// MARK: - Radial Menu Button
/// A single button that appears in the radial menu
struct RadialMenuButton: View {
    let item: RadialMenuItem
    let index: Int
    let isExpanded: Bool
    let themeColor: Color
    let totalItems: Int
    
    // Calculate angle for fan expansion from bottom-right (upward arc)
    private var angle: Double {
        // Fan from roughly 180° (left) to 270° (up), centered around 225°
        // Spread items evenly within this arc
        let startAngle: Double = 180
        let endAngle: Double = 270
        let angleSpread = endAngle - startAngle
        let angleStep = angleSpread / Double(max(totalItems - 1, 1))
        return startAngle + (angleStep * Double(index))
    }
    
    // Distance from center for expanded state
    private let expandedRadius: CGFloat = 90
    
    private var offset: CGSize {
        guard isExpanded else {
            return .zero
        }
        let radians = angle * .pi / 180
        return CGSize(
            width: cos(radians) * expandedRadius,
            height: sin(radians) * expandedRadius
        )
    }
    
    var body: some View {
        Button(action: item.action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(themeColor)
                        .frame(width: 50, height: 50)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(item.label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .offset(offset)
        .opacity(isExpanded ? 1 : 0)
        .scaleEffect(isExpanded ? 1 : 0.3)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)
                .delay(isExpanded ? Double(index) * 0.05 : Double(totalItems - index - 1) * 0.03),
            value: isExpanded
        )
    }
}

// MARK: - Radial Menu View
/// A floating action button with radial menu expansion
struct RadialMenuView: View {
    let themeColor: Color
    let onSearch: () -> Void
    let onNewItem: () -> Void
    let onPasteFromClipboard: () -> Void
    
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var menuItems: [RadialMenuItem] {
        [
            RadialMenuItem(icon: "magnifyingglass", label: "Search", action: {
                closeMenuAndExecute(onSearch)
            }),
            RadialMenuItem(icon: "square.and.pencil", label: "New Item", action: {
                closeMenuAndExecute(onNewItem)
            }),
            RadialMenuItem(icon: "doc.on.clipboard", label: "Paste", action: {
                closeMenuAndExecute(onPasteFromClipboard)
            })
        ]
    }
    
    private func closeMenuAndExecute(_ action: @escaping () -> Void) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isExpanded = false
        }
        // Execute action after menu closes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            action()
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Backdrop for dismissing menu when tapping outside
            if isExpanded {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded = false
                        }
                    }
            }
            
            // Radial menu container
            ZStack {
                // Menu items
                ForEach(Array(menuItems.enumerated()), id: \.element.id) { index, item in
                    RadialMenuButton(
                        item: item,
                        index: index,
                        isExpanded: isExpanded,
                        themeColor: themeColor,
                        totalItems: menuItems.count
                    )
                }
                
                // Main FAB button
                Button(action: {
                    // Tap action: Add new item (default action)
                    if !isExpanded {
                        onNewItem()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded = false
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(themeColor)
                            .frame(width: 56, height: 56)
                            .shadow(
                                color: colorScheme == .dark ? .black.opacity(0.4) : .black.opacity(0.2),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                        
                        Image(systemName: isExpanded ? "xmark" : "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
                    }
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isExpanded = true
                            }
                        }
                )
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        RadialMenuView(
            themeColor: .blue,
            onSearch: { print("Search tapped") },
            onNewItem: { print("New Item tapped") },
            onPasteFromClipboard: { print("Paste tapped") }
        )
    }
}
