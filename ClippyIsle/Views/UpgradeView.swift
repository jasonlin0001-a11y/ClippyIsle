//
//  UpgradeView.swift
//  ClippyIsle
//
//  Paywall UI for upgrading to Curator status.
//

import SwiftUI

// MARK: - Upgrade View (Paywall)
struct UpgradeView: View {
    @StateObject private var curatorService = CuratorSubscriptionService.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    let themeColor: Color
    
    @State private var showSuccessAnimation = false
    @State private var showSuccessAlert = false
    @State private var purchaseError: String?
    @State private var showErrorAlert = false
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Image/Icon
                    headerSection
                    
                    // Benefits Section
                    benefitsSection
                    
                    // Pricing Card
                    pricingCard
                    
                    // Subscribe Button
                    subscribeButton
                    
                    // Terms & Conditions
                    termsSection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
            .background(colorScheme == .dark ? Color.black : Color(.systemGroupedBackground))
            
            // Success animation overlay
            if showSuccessAnimation {
                successOverlay
            }
        }
        .navigationTitle("成為策展人")
        .navigationBarTitleDisplayMode(.inline)
        .alert("🎉 恭喜！", isPresented: $showSuccessAlert) {
            Button("太棒了！") {
                dismiss()
            }
        } message: {
            Text("您已成功升級為 CC Isle 策展人！現在可以開始發佈精選內容了。")
        }
        .alert("購買失敗", isPresented: $showErrorAlert) {
            Button("確定") {}
        } message: {
            Text(purchaseError ?? "發生未知錯誤，請稍後再試。")
        }
    }
    
    // MARK: - Success Overlay
    private var successOverlay: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .scaleEffect(showSuccessAnimation ? 1.0 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showSuccessAnimation)
            
            Text("🎉")
                .font(.system(size: 60))
                .scaleEffect(showSuccessAnimation ? 1.0 : 0.3)
                .animation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.2), value: showSuccessAnimation)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Curator Badge Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [themeColor, themeColor.opacity(0.6)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }
            .shadow(color: themeColor.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Title
            VStack(spacing: 8) {
                Text("成為 CC Isle 策展人")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Become a CC Isle Curator")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Benefits Section
    private var benefitsSection: some View {
        VStack(spacing: 16) {
            benefitRow(
                icon: "checkmark.seal.fill",
                title: "策展人徽章",
                subtitle: "Verified Curator Badge",
                color: .green
            )
            
            benefitRow(
                icon: "square.and.pencil",
                title: "解鎖發佈工具",
                subtitle: "Unlock Publishing Tools",
                color: .blue
            )
            
            benefitRow(
                icon: "heart.fill",
                title: "支持社群發展",
                subtitle: "Support the Community",
                color: .red
            )
            
            benefitRow(
                icon: "star.fill",
                title: "優先客服支援",
                subtitle: "Priority Support",
                color: .orange
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
        )
    }
    
    private func benefitRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Pricing Card
    private var pricingCard: some View {
        VStack(spacing: 8) {
            // Price
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("TWD")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(themeColor)
                
                Text("300")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(themeColor)
            }
            
            // Period
            Text("每月 / Per Month")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Note
            Text("隨時可取消")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            themeColor.opacity(0.1),
                            themeColor.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(themeColor.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    // MARK: - Subscribe Button
    private var subscribeButton: some View {
        Button(action: {
            Task {
                await purchaseCurator()
            }
        }) {
            HStack(spacing: 12) {
                if curatorService.isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "crown.fill")
                        .font(.headline)
                }
                
                Text(curatorService.isPurchasing ? "處理中..." : "立即訂閱")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [themeColor, themeColor.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: themeColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(curatorService.isPurchasing)
    }
    
    // MARK: - Terms Section
    private var termsSection: some View {
        VStack(spacing: 8) {
            Text("訂閱後將自動每月續訂，可隨時在設定中取消。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Auto-renews monthly. Cancel anytime in Settings.")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Purchase Action
    private func purchaseCurator() async {
        do {
            try await curatorService.purchaseCuratorPlan()
            // Success!
            showSuccessAnimation = true
            
            // Show alert after brief animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showSuccessAnimation = false
                showSuccessAlert = true
            }
        } catch {
            purchaseError = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// MARK: - Curator Badge View
struct CuratorBadge: View {
    let size: CGFloat
    
    init(size: CGFloat = 20) {
        self.size = size
    }
    
    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: size))
            .foregroundColor(.orange)
    }
}

// MARK: - Upgrade Banner View (for Profile)
struct UpgradeBanner: View {
    let themeColor: Color
    @State private var showUpgradeView = false
    
    var body: some View {
        Button(action: {
            showUpgradeView = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("升級為策展人")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Upgrade to Curator")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [themeColor, themeColor.opacity(0.7)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showUpgradeView) {
            NavigationStack {
                UpgradeView(themeColor: themeColor)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                showUpgradeView = false
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct UpgradeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            UpgradeView(themeColor: .blue)
        }
    }
}
#endif
