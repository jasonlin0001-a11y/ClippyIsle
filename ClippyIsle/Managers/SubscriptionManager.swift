//
//  SubscriptionManager.swift
//  ClippyIsle
//
//  Created for high-performance StoreKit 2 implementation.
//

import Foundation
import StoreKit
import SwiftUI
import Combine

enum ProductIDs {
    static let monthly = "com.shihchieh.clippyisle.pro.monthly"
    static let yearly = "com.shihchieh.clippyisle.pro.yearly"
    static let lifetime = "com.shihchieh.clippyisle.pro.lifetime"
    
    static let all = [monthly, yearly, lifetime]
}

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // Published 用於 UI 顯示價格
    @Published var products: [Product] = []
    
    // 使用 UserDefaults + Published 來替代 @AppStorage，避免 Protocol Conformance 錯誤
    // 這樣做既能讓 UI 響應變化，又能與 App 其他部分的 @AppStorage("isProUser") 保持同步
    @Published var isPro: Bool = UserDefaults.standard.bool(forKey: "isProUser") {
        didSet {
            UserDefaults.standard.set(isPro, forKey: "isProUser")
        }
    }
    
    private var updateListenerTask: Task<Void, Error>? = nil

    // MARK: - Performance Rule: Empty Init
    // 這裡絕對不能放任何 fetch 邏輯，確保 App 啟動 0 延遲
    private init() {}
    
    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Lifecycle (Call from App.task)
    func start() {
        // 在背景 Task.detached 啟動監聽，完全不佔用 Main Thread
        updateListenerTask = Task.detached(priority: .background) {
            // 明確指定 StoreKit.Transaction 避免與 SwiftUI.Transaction 衝突
            for await result in StoreKit.Transaction.updates {
                await self.handle(transactionVerification: result)
            }
        }
        
        // 啟動時順便在背景檢查一次最新狀態
        Task.detached(priority: .background) {
            await self.updateSubscriptionStatus()
        }
    }

    // MARK: - Purchase Logic
    
    // 只有當使用者打開 Paywall 時才呼叫此函式，節省資源
    func loadProducts() async {
        do {
            let loadedProducts = try await Product.products(for: ProductIDs.all)
            let sorted = loadedProducts.sorted { $0.price < $1.price }
            await MainActor.run {
                self.products = sorted
            }
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            await handle(transactionVerification: verification)
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }
    
    func restorePurchases() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Internal Handling

    private func handle(transactionVerification result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        
        await updateSubscriptionStatus()
        await transaction.finish()
    }

    private func updateSubscriptionStatus() async {
        var validProFound = false
        
        // 檢查所有權限
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            if ProductIDs.all.contains(transaction.productID) {
                if let expirationDate = transaction.expirationDate {
                    if expirationDate > Date() {
                        validProFound = true
                    }
                } else {
                    // 買斷制 (Lifetime)
                    validProFound = true
                }
            }
            if validProFound { break }
        }
        
        // 只有狀態改變時才更新 UI，減少重繪
        let finalStatus = validProFound
        await MainActor.run {
            if self.isPro != finalStatus {
                self.isPro = finalStatus
            }
        }
    }
}