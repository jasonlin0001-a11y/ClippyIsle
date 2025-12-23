//
//  MainFeedView.swift
//  ClippyIsle
//
//  Paged TabView container for Discovery and Following feeds.
//

import SwiftUI

// MARK: - Feed Tab
/// Enum representing the two feed tabs
enum FeedTab: Int, CaseIterable {
    case discovery = 0
    case following = 1
    
    var title: String {
        switch self {
        case .discovery:
            return "Discovery"
        case .following:
            return "Following"
        }
    }
}

// MARK: - Main Feed View
/// Container view with paged TabView for Discovery and Following feeds
struct MainFeedView<DiscoveryContent: View>: View {
    @Binding var selectedTab: FeedTab
    let themeColor: Color
    let discoveryContent: () -> DiscoveryContent
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack(alignment: .top) {
            // Paged TabView
            TabView(selection: $selectedTab) {
                // Tab 0: Discovery (existing main list)
                discoveryContent()
                    .tag(FeedTab.discovery)
                
                // Tab 1: Following Feed
                FollowingFeedView(themeColor: themeColor)
                    .tag(FeedTab.following)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: selectedTab)
            
            // Floating Header
            FeedNavigationHeader(
                selectedTab: $selectedTab,
                themeColor: themeColor
            )
        }
    }
}

// MARK: - Feed Navigation Header
/// Custom floating header with Discovery/Following toggle buttons
struct FeedNavigationHeader: View {
    @Binding var selectedTab: FeedTab
    let themeColor: Color
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Animation namespace for indicator
    @Namespace private var animation
    
    var body: some View {
        VStack(spacing: 0) {
            // Header background with safe area
            headerContent
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(headerBackground)
        }
    }
    
    // MARK: - Header Content
    private var headerContent: some View {
        HStack(spacing: 0) {
            ForEach(FeedTab.allCases, id: \.rawValue) { tab in
                tabButton(for: tab)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5).opacity(colorScheme == .dark ? 0.6 : 0.4))
        )
    }
    
    // MARK: - Tab Button
    private func tabButton(for tab: FeedTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            Text(tab.title)
                .font(.subheadline)
                .fontWeight(selectedTab == tab ? .semibold : .regular)
                .foregroundColor(selectedTab == tab ? .white : .primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeColor)
                                .matchedGeometryEffect(id: "tab_indicator", in: animation)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Header Background
    private var headerBackground: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Preview
#if DEBUG
struct MainFeedView_Previews: PreviewProvider {
    static var previews: some View {
        MainFeedView(
            selectedTab: .constant(.discovery),
            themeColor: .green
        ) {
            Text("Discovery Content")
        }
    }
}
#endif
