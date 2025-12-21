import SwiftUI

// MARK: - Radial Menu Item
/// Represents a single item in the radial menu
struct RadialMenuItem: Identifiable {
    let id = UUID()
    let localizedKey: LocalizedStringKey  // Localized name key
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
    let isOnLeftSide: Bool  // Determines fan direction
    
    // Distance from center for expanded state
    private let expandedRadius: CGFloat = 100
    
    // Angle offsets for each item position (from horizontal toward vertical)
    // Index 0: Horizontal (0°), Index 1: Diagonal (45°), Index 2: Vertical (90°)
    private let angleOffsets: [Double] = [0, 45, 90]
    
    // Safe index within bounds of angleOffsets array
    private var safeIndex: Int {
        max(0, min(index, angleOffsets.count - 1))
    }
    
    // Calculate angle for fan expansion - explicit mirroring
    private var angle: Double {
        // Right side: Base 180° (pointing left), offset goes counterclockwise toward up
        // Left side: Base 0° (pointing right), offset goes clockwise toward up (negative)
        let offset = angleOffsets[safeIndex]
        
        if isOnLeftSide {
            // Left side: start at 0° (right), fan upward with negative angles
            return 0 - offset  // 0°, -45°, -90°
        } else {
            // Right side: start at 180° (left), fan upward with positive offset
            return 180 + offset  // 180°, 225°, 270°
        }
    }
    
    // Calculate text rotation to align capsule with radial spoke
    private var textRotation: Double {
        // Right side: positive rotations (counterclockwise visual)
        // Left side: negative rotations (clockwise visual) for perfect mirror
        let rotation = angleOffsets[safeIndex]
        return isOnLeftSide ? -rotation : rotation
    }
    
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
        // Show only the localized name text (no letter icon, no circle background)
        Text(item.localizedKey)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(themeColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
            .rotationEffect(.degrees(isExpanded ? textRotation : 0))
            .onTapGesture {
                item.action()
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
    let onVoiceMemo: () -> Void  // Voice memo - opens microphone for voice-to-text memo
    let onNewItem: () -> Void
    let onPasteFromClipboard: () -> Void
    
    @State private var isExpanded = false
    @State private var isDragging = false
    @State private var position: CGPoint = .zero
    @State private var startDragPosition: CGPoint = .zero  // Track starting position for smooth drag
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
            RadialMenuItem(localizedKey: "Voice Memo", action: {
                closeMenuAndExecute(onVoiceMemo)
            }),
            RadialMenuItem(localizedKey: "New Item", action: {
                closeMenuAndExecute(onNewItem)
            }),
            RadialMenuItem(localizedKey: "Paste", action: {
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
                    .animation(.easeOut(duration: 0.15), value: isDragging)
                    .onTapGesture {
                        // Tap action: Open radial menu
                        if !isDragging {
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
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                // Start dragging mode
                                hapticGenerator.impactOccurred()
                                isDragging = true
                                startDragPosition = position
                            }
                    )
                    .highPriorityGesture(
                        isDragging ?
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Direct position update without animation for smooth dragging
                                let newX = startDragPosition.x + value.translation.width
                                let newY = startDragPosition.y + value.translation.height
                                position = CGPoint(x: newX, y: newY)
                            }
                            .onEnded { _ in
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
                        : nil
                    )
                }
                .position(position)
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
            onVoiceMemo: { print("Voice Memo tapped") },
            onNewItem: { print("New Item tapped") },
            onPasteFromClipboard: { print("Paste tapped") }
        )
    }
}
