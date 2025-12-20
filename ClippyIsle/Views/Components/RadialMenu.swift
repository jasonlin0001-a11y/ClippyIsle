import SwiftUI

// MARK: - Radial Menu Item
/// Represents a single item in the radial menu
struct RadialMenuItem: Identifiable {
    let id = UUID()
    let letterIcon: String  // Single letter icon (S, N, P)
    let label: String
    let action: () -> Void
    var longPressAction: (() -> Void)? = nil  // Optional long press action
}

// MARK: - Radial Menu Button
/// A single button that appears in the radial menu
struct RadialMenuButton: View {
    let item: RadialMenuItem
    let index: Int
    let isExpanded: Bool
    let themeColor: Color
    let totalItems: Int
    let isOnLeftSide: Bool  // Determines fan direction
    
    // Calculate angle for fan expansion based on position
    private var angle: Double {
        // If on right side: fan from 180° (left) to 270° (up)
        // If on left side: fan from 270° (up) to 360° (right)
        let startAngle: Double = isOnLeftSide ? 270 : 180
        let endAngle: Double = isOnLeftSide ? 360 : 270
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
        let radians = CGFloat(angle) * .pi / 180
        return CGSize(
            width: Darwin.cos(radians) * expandedRadius,
            height: Darwin.sin(radians) * expandedRadius
        )
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(themeColor)
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                // Letter icon instead of SF Symbol
                Text(item.letterIcon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(item.label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .onTapGesture {
            item.action()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            if let longPressAction = item.longPressAction {
                longPressAction()
            }
        }
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
/// A floating action button with radial menu expansion and draggable positioning
struct RadialMenuView: View {
    let themeColor: Color
    let onSearch: () -> Void
    let onVoiceSearch: () -> Void  // New callback for voice search
    let onNewItem: () -> Void
    let onPasteFromClipboard: () -> Void
    
    @State private var isExpanded = false
    @State private var isDragging = false
    @State private var position: CGPoint = .zero
    @State private var dragOffset: CGSize = .zero  // Separate drag offset to prevent ghost images
    @State private var isOnLeftSide = false
    @Environment(\.colorScheme) private var colorScheme
    
    // Animation timing constants
    private let closeAnimationDuration: Double = 0.3
    private let actionExecutionDelay: Double = 0.25
    
    // FAB size and margins
    private let fabSize: CGFloat = 56
    private let edgeMargin: CGFloat = 16
    private let verticalPadding: CGFloat = 100  // Distance from bottom
    
    // Reusable haptic feedback generator
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    private var menuItems: [RadialMenuItem] {
        [
            RadialMenuItem(letterIcon: "S", label: "SEARCH", action: {
                closeMenuAndExecute(onSearch)
            }, longPressAction: {
                closeMenuAndExecute(onVoiceSearch)
            }),
            RadialMenuItem(letterIcon: "N", label: "NEW ITEM", action: {
                closeMenuAndExecute(onNewItem)
            }),
            RadialMenuItem(letterIcon: "P", label: "PASTE", action: {
                closeMenuAndExecute(onPasteFromClipboard)
            })
        ]
    }
    
    private func closeMenuAndExecute(_ action: @escaping () -> Void) {
        withAnimation(.spring(response: closeAnimationDuration, dampingFraction: 0.7)) {
            isExpanded = false
        }
        // Execute action after menu close animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + actionExecutionDelay) {
            action()
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Backdrop for dismissing menu when tapping outside
                if isExpanded {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: closeAnimationDuration, dampingFraction: 0.7)) {
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
                            totalItems: menuItems.count,
                            isOnLeftSide: isOnLeftSide
                        )
                    }
                    
                    // Main FAB button - 30% transparent (70% opacity)
                    ZStack {
                        Circle()
                            .fill(themeColor.opacity(0.7))  // 70% opacity = 30% transparent
                            .frame(width: fabSize, height: fabSize)
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
                            .animation(.spring(response: closeAnimationDuration, dampingFraction: 0.7), value: isExpanded)
                    }
                    .scaleEffect(isDragging ? 1.1 : 1.0)
                    .onTapGesture {
                        // Tap action: Open radial menu
                        if !isExpanded {
                            hapticGenerator.impactOccurred()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isExpanded = true
                            }
                        } else {
                            withAnimation(.spring(response: closeAnimationDuration, dampingFraction: 0.7)) {
                                isExpanded = false
                            }
                        }
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                // Start dragging mode
                                hapticGenerator.impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isDragging = true
                                }
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if isDragging {
                                    // Calculate new position directly from translation
                                    let newX = position.x + value.translation.width - dragOffset.width
                                    let newY = position.y + value.translation.height - dragOffset.height
                                    dragOffset = value.translation
                                    position = CGPoint(x: newX, y: newY)
                                }
                            }
                            .onEnded { value in
                                if isDragging {
                                    dragOffset = .zero
                                    
                                    // Snap to left or right edge
                                    let screenWidth = geometry.size.width
                                    let screenHeight = geometry.size.height
                                    let midX = screenWidth / 2
                                    
                                    // Determine which side to snap to
                                    let newIsOnLeftSide = position.x < midX
                                    
                                    // Clamp Y position within safe bounds (accounting for safe area)
                                    let safeAreaTop = geometry.safeAreaInsets.top
                                    let safeAreaBottom = geometry.safeAreaInsets.bottom
                                    let minY = fabSize / 2 + edgeMargin + safeAreaTop
                                    let maxY = screenHeight - fabSize / 2 - edgeMargin - safeAreaBottom
                                    let clampedY = min(max(position.y, minY), maxY)
                                    
                                    // Calculate final X position (snapped to edge)
                                    let finalX = newIsOnLeftSide ? (fabSize / 2 + edgeMargin) : (screenWidth - fabSize / 2 - edgeMargin)
                                    
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        position = CGPoint(x: finalX, y: clampedY)
                                        isOnLeftSide = newIsOnLeftSide
                                        isDragging = false
                                    }
                                }
                            }
                    )
                }
                .position(position)
                .drawingGroup()  // Fixes ghost image artifacts during drag
            }
            .onAppear {
                // Set initial position
                position = defaultPosition(in: geometry)
                hapticGenerator.prepare()
            }
        }
    }
    
    private func defaultPosition(in geometry: GeometryProxy) -> CGPoint {
        // Default to bottom-right corner
        CGPoint(
            x: geometry.size.width - fabSize / 2 - edgeMargin,
            y: geometry.size.height - fabSize / 2 - verticalPadding
        )
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
            onVoiceSearch: { print("Voice search tapped") },
            onNewItem: { print("New Item tapped") },
            onPasteFromClipboard: { print("Paste tapped") }
        )
    }
}
