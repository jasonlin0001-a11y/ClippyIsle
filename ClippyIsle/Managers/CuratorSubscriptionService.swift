//
//  CuratorSubscriptionService.swift
//  ClippyIsle
//
//  Manages Curator subscription status (mock IAP for MVP).
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Subscription Status Enum
enum SubscriptionStatus: String, Codable {
    case free = "free"
    case active = "active"
    case expired = "expired"
}

// MARK: - Curator Subscription Service
@MainActor
class CuratorSubscriptionService: ObservableObject {
    static let shared = CuratorSubscriptionService()
    
    // MARK: - Constants
    static let CURATOR_PLAN_PRICE = "TWD 300"
    static let CURATOR_PLAN_PERIOD = "每月 / Month"
    static let SUBSCRIPTION_DAYS = 30
    
    // MARK: - Published Properties
    @Published var isCurator: Bool = false
    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var subscriptionExpiryDate: Date?
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: String?
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    
    private init() {
        // Load status on init if user is authenticated
        if let uid = Auth.auth().currentUser?.uid {
            Task {
                await loadSubscriptionStatus(for: uid)
            }
        }
    }
    
    // MARK: - Load Subscription Status
    /// Loads the current user's subscription status from Firestore
    func loadSubscriptionStatus(for uid: String) async {
        do {
            let docRef = db.collection(usersCollection).document(uid)
            let snapshot = try await docRef.getDocument()
            
            guard let data = snapshot.data() else { return }
            
            let isCuratorValue = data["isCurator"] as? Bool ?? false
            let statusString = data["subscriptionStatus"] as? String ?? "free"
            let status = SubscriptionStatus(rawValue: statusString) ?? .free
            
            var expiryDate: Date? = nil
            if let expiryTimestamp = data["subscriptionExpiryDate"] as? Timestamp {
                expiryDate = expiryTimestamp.dateValue()
            }
            
            // Check if subscription has expired
            let finalIsCurator: Bool
            let finalStatus: SubscriptionStatus
            
            if let expiry = expiryDate, expiry < Date() {
                // Subscription has expired
                finalIsCurator = false
                finalStatus = .expired
                // Update Firestore with expired status
                try? await docRef.updateData([
                    "isCurator": false,
                    "subscriptionStatus": "expired"
                ])
            } else {
                finalIsCurator = isCuratorValue
                finalStatus = status
            }
            
            self.isCurator = finalIsCurator
            self.subscriptionStatus = finalStatus
            self.subscriptionExpiryDate = expiryDate
            
            print("📦 Loaded subscription status: isCurator=\(finalIsCurator), status=\(finalStatus)")
        } catch {
            print("📦 Failed to load subscription status: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Purchase Curator Plan (Mock IAP)
    /// Simulates purchasing the Curator plan
    /// In production, this would integrate with StoreKit
    func purchaseCuratorPlan() async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "CuratorSubscriptionService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        isPurchasing = true
        purchaseError = nil
        
        do {
            // Simulate network delay (1-2 seconds)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1_000_000_000...2_000_000_000))
            
            // Calculate expiry date (30 days from now)
            let expiryDate = Calendar.current.date(byAdding: .day, value: CuratorSubscriptionService.SUBSCRIPTION_DAYS, to: Date())!
            
            // Update Firestore
            let docRef = db.collection(usersCollection).document(uid)
            try await docRef.updateData([
                "isCurator": true,
                "subscriptionStatus": "active",
                "subscriptionExpiryDate": Timestamp(date: expiryDate)
            ])
            
            // Update local state
            self.isCurator = true
            self.subscriptionStatus = .active
            self.subscriptionExpiryDate = expiryDate
            self.isPurchasing = false
            
            print("📦 Successfully purchased Curator plan! Expires: \(expiryDate)")
        } catch {
            self.isPurchasing = false
            self.purchaseError = error.localizedDescription
            print("📦 Failed to purchase Curator plan: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Cancel Subscription (Mock)
    /// Simulates cancelling the subscription
    func cancelSubscription() async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "CuratorSubscriptionService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Note: In a real app, subscription would remain active until expiry
        // For MVP, we just mark it as expired
        let docRef = db.collection(usersCollection).document(uid)
        try await docRef.updateData([
            "subscriptionStatus": "expired"
        ])
        
        self.subscriptionStatus = .expired
        print("📦 Subscription cancelled")
    }
    
    // MARK: - Refresh Status
    /// Refreshes the subscription status from Firestore
    func refreshStatus() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        await loadSubscriptionStatus(for: uid)
    }
    
    // MARK: - Check if User Can Publish
    /// Returns whether the current user can publish posts
    var canPublish: Bool {
        return isCurator && subscriptionStatus == .active
    }
    
    // MARK: - Days Remaining
    /// Returns the number of days remaining in the subscription
    var daysRemaining: Int? {
        guard let expiryDate = subscriptionExpiryDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day
        return max(0, days ?? 0)
    }
}
