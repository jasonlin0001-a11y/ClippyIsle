//
//  PaywallView.swift
//  ClippyIsle
//
//  Paywall UI
//

import SwiftUI
import StoreKit

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
                
                Text("Unlock ClippyIsle Pro")
                    .font(.largeTitle.bold())
                
                Text("Remove limits, customize themes, and enable sync.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            
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
    
    var isBestValue: Bool {
        product.id == ProductIDs.lifetime || product.id == ProductIDs.yearly
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(product.displayName)
                    .font(.headline)
                Text(product.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(product.displayPrice)
                    .font(.title3.bold())
                
                if isBestValue {
                    Text("BEST VALUE")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}