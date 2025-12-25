//
//  MainFeedView.swift
//  ClippyIsle
//
//  Paged TabView container for Discovery, Following, and CC Feed tabs.
//

import SwiftUI

// MARK: - Feed Tab
/// Enum representing the three feed tabs
enum FeedTab: Int, CaseIterable {
    case discovery = 0
    case following = 1
    case myIsle = 2
    
    var title: String {
        switch self {
        case .discovery:
            return "Discovery"
        case .following:
            return "Following"
        case .myIsle:
            return "My Isle"
        }
    }
}

// MARK: - Scroll Offset Preference Key
/// Tracks scroll offset for collapsing header animation
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Main Feed View
/// Container view with paged TabView for Discovery, Following, and CC Feed tabs
struct MainFeedView<DiscoveryContent: View, FollowingContent: View, MyIsleContent: View>: View {
    @Binding var selectedTab: FeedTab
    let themeColor: Color
    let discoveryContent: () -> DiscoveryContent
    let followingContent: () -> FollowingContent
    let myIsleContent: () -> MyIsleContent
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Track scroll offset for collapsing header
    @State private var scrollOffset: CGFloat = 0
    
    // Threshold for collapsing header (how far to scroll before title hides)
    private let collapseThreshold: CGFloat = 60
    
    // Calculate header opacity based on scroll offset
    private var headerOpacity: Double {
        let progress = min(max(-scrollOffset / collapseThreshold, 0), 1)
        return 1 - progress
    }
    
    // Calculate small title opacity (inverse of header)
    var smallTitleOpacity: Double {
        let progress = min(max(-scrollOffset / collapseThreshold, 0), 1)
        return progress
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header with title and segmented picker (collapsible)
            if headerOpacity > 0 {
                customHeader
                    .opacity(headerOpacity)
                    .frame(height: headerOpacity > 0.1 ? nil : 0, alignment: .top)
                    .clipped()
            }
            
            // Paged TabView content
            TabView(selection: $selectedTab) {
                // Tab 0: Discovery (creator_posts from Firestore)
                discoveryContent()
                    .tag(FeedTab.discovery)
                
                // Tab 1: Following (social subscription feed)
                followingContent()
                    .tag(FeedTab.following)
                
                // Tab 2: My Isle (personal scrapbook - local items + saved posts)
                myIsleContent()
                    .tag(FeedTab.myIsle)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: selectedTab)
        }
    }
    
    // MARK: - Custom Header
    private var customHeader: some View {
        HStack {
            Text("CC 島")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            // Segmented Picker for Discovery/Following/My Isle - aligned to far right
            Picker("Feed", selection: $selectedTab) {
                ForEach(FeedTab.allCases, id: \.rawValue) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    // MARK: - Update Scroll Offset
    func updateScrollOffset(_ offset: CGFloat) {
        scrollOffset = offset
    }
}

// MARK: - Compact Tab Picker for Navigation Bar
/// Compact segmented control to be placed in the navigation bar header
struct CompactTabPicker: View {
    @Binding var selectedTab: FeedTab
    let themeColor: Color
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Animation namespace for indicator
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(FeedTab.allCases, id: \.rawValue) { tab in
                tabButton(for: tab)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
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
                .font(.caption2)
                .fontWeight(selectedTab == tab ? .semibold : .regular)
                .foregroundColor(selectedTab == tab ? .white : .primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    Group {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(themeColor)
                                .matchedGeometryEffect(id: "compact_tab_indicator", in: animation)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
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
        } followingContent: {
            Text("Following Content")
        } myIsleContent: {
            Text("My Isle Content")
        }
    }
}
#endif
