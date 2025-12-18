//
//  AdaptiveStyles.swift
//  ClippyIsle
//
//  Design System for Dark Mode and Light Mode adaptive styling
//  Based on modern iOS app UI design guidelines
//

import SwiftUI

// MARK: - Adaptive Design System

/// A centralized design system for adaptive dark/light mode styling
/// 
/// Design Guidelines:
/// - **Dark Mode**: Use deep grey backgrounds, no shadows, accent colors with slight glow/opacity
/// - **Light Mode**: Off-white background (#F2F2F7), pure white cards with soft drop shadows
struct AdaptiveStyles {
    
    // MARK: - Background Colors
    
    /// The main screen background color
    /// - Dark Mode: Neutral black (system background)
    /// - Light Mode: Soft off-white (#F2F2F7)
    static func screenBackground(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color(UIColor.systemBackground)
        case .light:
            return Color(red: 242/255, green: 242/255, blue: 247/255) // #F2F2F7
        @unknown default:
            return Color(UIColor.systemBackground)
        }
    }
    
    /// Card background color for floating card elements
    /// - Dark Mode: Deep grey panel (systemGray6)
    /// - Light Mode: Pure white
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color(UIColor.systemGray6)
        case .light:
            return Color.white
        @unknown default:
            return Color(UIColor.systemBackground)
        }
    }
    
    /// Secondary card background (for nested elements)
    /// - Dark Mode: Slightly lighter grey (systemGray5)
    /// - Light Mode: Very light grey
    static func secondaryCardBackground(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color(UIColor.systemGray5)
        case .light:
            return Color(red: 250/255, green: 250/255, blue: 252/255)
        @unknown default:
            return Color(UIColor.secondarySystemBackground)
        }
    }
    
    // MARK: - Shadow Configuration
    
    /// Card shadow configuration
    /// - Dark Mode: No shadow (shadows look dirty on dark backgrounds)
    /// - Light Mode: Soft drop shadow
    static func cardShadow(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        switch colorScheme {
        case .dark:
            return (Color.clear, 0, 0, 0)
        case .light:
            return (Color.black.opacity(0.1), 4, 0, 2)
        @unknown default:
            return (Color.black.opacity(0.05), 2, 0, 1)
        }
    }
    
    /// Elevated card shadow (for prominent elements)
    /// - Dark Mode: Subtle inner glow effect using border
    /// - Light Mode: More pronounced drop shadow
    static func elevatedCardShadow(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        switch colorScheme {
        case .dark:
            return (Color.clear, 0, 0, 0)
        case .light:
            return (Color.black.opacity(0.12), 8, 0, 4)
        @unknown default:
            return (Color.black.opacity(0.08), 4, 0, 2)
        }
    }
    
    // MARK: - Adaptive Tint Color Utilities
    
    /// Tag/Label background color based on user's accent color
    /// - Dark Mode: Lower opacity (0.2) for subtle appearance
    /// - Light Mode: Very low opacity (0.1) for subtle tint
    static func tagBackground(userColor: Color, for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return userColor.opacity(0.2)
        case .light:
            return userColor.opacity(0.1)
        @unknown default:
            return userColor.opacity(0.15)
        }
    }
    
    /// Tag/Label text color
    /// - Both modes: Use the user's accent color directly
    /// Note: In light mode, ensure the color is dark enough for contrast
    static func tagTextColor(userColor: Color, for colorScheme: ColorScheme) -> Color {
        return userColor
    }
    
    /// Icon tint configuration
    /// - Dark Mode: Original color, optionally with slight glow
    /// - Light Mode: Original color, no glow
    static func iconColor(userColor: Color, for colorScheme: ColorScheme) -> Color {
        return userColor
    }
    
    /// Default tag background when no custom color is set
    /// - Dark Mode: Subtle grey
    /// - Light Mode: Light grey
    static func defaultTagBackground(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color.gray.opacity(0.3)
        case .light:
            return Color.gray.opacity(0.15)
        @unknown default:
            return Color.gray.opacity(0.2)
        }
    }
    
    // MARK: - Text Colors
    
    /// Primary text color
    /// - Dark Mode: High contrast white
    /// - Light Mode: Clean dark typography
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color.white
        case .light:
            return Color(UIColor.darkGray)
        @unknown default:
            return Color.primary
        }
    }
    
    /// Secondary text color
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        return Color.secondary
    }
    
    // MARK: - Border/Stroke Colors
    
    /// Card border color (for subtle definition)
    /// - Dark Mode: Subtle light border for depth
    /// - Light Mode: Usually not needed due to shadows
    static func cardBorder(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color.white.opacity(0.08)
        case .light:
            return Color.clear
        @unknown default:
            return Color.gray.opacity(0.1)
        }
    }
    
    /// Separator/Divider color
    static func separator(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color.gray.opacity(0.3)
        case .light:
            return Color.gray.opacity(0.2)
        @unknown default:
            return Color.gray.opacity(0.25)
        }
    }
}

// MARK: - View Modifiers

/// A view modifier that applies adaptive card styling
struct AdaptiveCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat = 12
    var includeBorder: Bool = true
    
    func body(content: Content) -> some View {
        let shadow = AdaptiveStyles.cardShadow(for: colorScheme)
        
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AdaptiveStyles.cardBackground(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        includeBorder ? AdaptiveStyles.cardBorder(for: colorScheme) : Color.clear,
                        lineWidth: 1
                    )
            )
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

/// A view modifier that applies elevated card styling
struct AdaptiveElevatedCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat = 16
    
    func body(content: Content) -> some View {
        let shadow = AdaptiveStyles.elevatedCardShadow(for: colorScheme)
        
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AdaptiveStyles.cardBackground(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AdaptiveStyles.cardBorder(for: colorScheme), lineWidth: 1)
            )
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

/// A view modifier for adaptive tag chip styling
struct AdaptiveTagStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var customColor: Color?
    
    func body(content: Content) -> some View {
        let backgroundColor: Color
        let textColor: Color
        
        if let custom = customColor {
            backgroundColor = AdaptiveStyles.tagBackground(userColor: custom, for: colorScheme)
            textColor = colorScheme == .dark ? Color.white : custom
        } else {
            backgroundColor = AdaptiveStyles.defaultTagBackground(for: colorScheme)
            textColor = Color.primary
        }
        
        content
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(8)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies adaptive card styling based on color scheme
    func adaptiveCardStyle(cornerRadius: CGFloat = 12, includeBorder: Bool = true) -> some View {
        modifier(AdaptiveCardStyle(cornerRadius: cornerRadius, includeBorder: includeBorder))
    }
    
    /// Applies elevated adaptive card styling based on color scheme
    func adaptiveElevatedCardStyle(cornerRadius: CGFloat = 16) -> some View {
        modifier(AdaptiveElevatedCardStyle(cornerRadius: cornerRadius))
    }
    
    /// Applies adaptive tag chip styling
    func adaptiveTagStyle(customColor: Color? = nil) -> some View {
        modifier(AdaptiveTagStyle(customColor: customColor))
    }
    
    /// Applies adaptive shadow based on color scheme
    func adaptiveShadow(colorScheme: ColorScheme, elevated: Bool = false) -> some View {
        let shadow = elevated 
            ? AdaptiveStyles.elevatedCardShadow(for: colorScheme)
            : AdaptiveStyles.cardShadow(for: colorScheme)
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
