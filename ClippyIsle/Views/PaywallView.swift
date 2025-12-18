//
//  PaywallView.swift
//  ClippyIsle
//
//  Paywall UI
//

import SwiftUI
import StoreKit

struct FeatureRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.fill")
                .foregroundStyle(.blue)
                .font(.system(size: 6))
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

struct PaywallView: View {
    // 使用 Singleton 或 EnvironmentObject
    @StateObject var manager = SubscriptionManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)
                    .padding(.top, 40)
                
                Text("解鎖CC Isle Pro")
                    .font(.largeTitle.bold())
                
                Text("解鎖完整功能，享受更強大的體驗")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            
            // PRO Features List
            VStack(alignment: .leading, spacing: 12) {
                Text("PRO 功能包含：")
                    .font(.headline)
                    .padding(.top, 10)
                
                FeatureRow(text: "標籤想加就加（隨心所欲歸類內容）")
                FeatureRow(text: "語音帶著走（沒網路也能暢聽無阻）")
                FeatureRow(text: "介面由你定義（隨心情切換愛用色）")
                FeatureRow(text: "iCloud 雲端備份（換手機也能無痛銜接）")
                FeatureRow(text: "網頁版小幫手（鍵盤打字整理更神速）")
                FeatureRow(text: "未來功能全包辦（一次購買，終身享受）")
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Products List
            if manager.products.isEmpty {
                VStack {
                    ProgressView()
                    Text("Loading prices...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(manager.products) { product in
                        Button {
                            Task {
                                try? await manager.purchase(product)
                                if manager.isPro { dismiss() }
                            }
                        } label: {
                            ProductRow(product: product)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Spacer()
            
            // Footer / Restore
            Button("Restore Purchases") {
                Task { await manager.restorePurchases() }
            }
            .font(.subheadline)
            .foregroundStyle(.blue)
            
            Text("Privacy Policy • Terms of Use")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom)
        }
        .padding()
        .task {
            // 只有打開這個頁面時才去抓取商品資訊
            await manager.loadProducts()
        }
    }
}

struct ProductRow: View {
    let product: Product
    @Environment(\.colorScheme) var colorScheme
    
    var isBestValue: Bool {
        product.id == ProductIDs.lifetime || product.id == ProductIDs.yearly
    }
    
    var subscriptionTypeLabel: String {
        switch product.id {
        case ProductIDs.monthly:
            return "月訂閱"
        case ProductIDs.yearly:
            return "年訂閱"
        case ProductIDs.lifetime:
            return "終身訂閱"
        default:
            return ""
        }
    }
    
    var subscriptionDescription: String {
        switch product.id {
        case ProductIDs.monthly:
            return "每月自動續訂，可隨時取消"
        case ProductIDs.yearly:
            return "每年自動續訂，平均每月更划算"
        case ProductIDs.lifetime:
            return "一次付費，永久使用"
        default:
            return product.description
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(product.displayName)
                        .font(.headline)
                    if !subscriptionTypeLabel.isEmpty {
                        Text("(\(subscriptionTypeLabel))")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
                Text(subscriptionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(product.displayPrice)
                    .font(.title3.bold())
                
                if isBestValue {
                    Text("最超值")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue))
                }
            }
        }
        .padding()
        .adaptiveCardStyle(cornerRadius: 12, includeBorder: true)
    }
}