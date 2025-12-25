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
struct MainFeedView<DiscoveryContent: View, FollowingContent: View>: View {
    @Binding var selectedTab: FeedTab
    let themeColor: Color
    let discoveryContent: () -> DiscoveryContent
    let followingContent: () -> FollowingContent
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header with title and segmented picker
            customHeader
            
            // Paged TabView content
            TabView(selection: $selectedTab) {
                // Tab 0: Discovery (creator_posts from Firestore)
                discoveryContent()
                    .tag(FeedTab.discovery)
                
                // Tab 1: Following (local clipboard items)
                followingContent()
                    .tag(FeedTab.following)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: selectedTab)
        }
    }
    
    // MARK: - Custom Header
    private var customHeader: some View {
        HStack {
            Text("CC Isle")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            // Segmented Picker for Discovery/Following
            Picker("Feed", selection: $selectedTab) {
                ForEach(FeedTab.allCases, id: \.rawValue) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
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
                .font(.caption)
                .fontWeight(selectedTab == tab ? .semibold : .regular)
                .foregroundColor(selectedTab == tab ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
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
        }
    }
}
#endif
