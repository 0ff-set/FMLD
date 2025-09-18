//
//  SubscriptionManager.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation
import StoreKit

// MARK: - Subscription Plans
enum SubscriptionPlan: String, CaseIterable, Codable {
    case basic = "com.fmld.panel.basic"
    case professional = "com.fmld.panel.professional"
    case enterprise = "com.fmld.panel.enterprise"
    
    var displayName: String {
        switch self {
        case .basic:
            return "Basic"
        case .professional:
            return "Professional"
        case .enterprise:
            return "Enterprise"
        }
    }
    
    var price: String {
        switch self {
        case .basic:
            return "$29.99/month"
        case .professional:
            return "$99.99/month"
        case .enterprise:
            return "$299.99/month"
        }
    }
    
    var features: [String] {
        switch self {
        case .basic:
            return [
                "Up to 1,000 transactions/month",
                "Basic fraud detection",
                "Email support",
                "Standard reports"
            ]
        case .professional:
            return [
                "Up to 10,000 transactions/month",
                "Advanced fraud detection",
                "Real-time monitoring",
                "Priority support",
                "Custom rules",
                "API access"
            ]
        case .enterprise:
            return [
                "Unlimited transactions",
                "AI-powered fraud detection",
                "Real-time monitoring",
                "24/7 dedicated support",
                "Custom rules & workflows",
                "Full API access",
                "White-label options",
                "SLA guarantee"
            ]
        }
    }
    
    var transactionLimit: Int {
        switch self {
        case .basic:
            return 1000
        case .professional:
            return 10000
        case .enterprise:
            return Int.max
        }
    }
}

// MARK: - Subscription Status
enum SubscriptionStatus: String, Codable {
    case active = "active"
    case expired = "expired"
    case cancelled = "cancelled"
    case pending = "pending"
    case trial = "trial"
}

struct SubscriptionInfo: Codable {
    let plan: SubscriptionPlan
    let status: SubscriptionStatus
    let startDate: Date
    let endDate: Date?
    let autoRenew: Bool
    let trialEndDate: Date?
    var usage: UsageInfo
    
    struct UsageInfo: Codable {
        var transactionsThisMonth: Int
        var apiCallsThisMonth: Int
        var storageUsed: Int64 // in bytes
    }
}

// MARK: - Subscription Manager
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var currentSubscription: SubscriptionInfo?
    @Published var availablePlans: [SubscriptionPlan] = SubscriptionPlan.allCases
    @Published var isLoading = false
    @Published var error: Error?
    
    private let logger = Logger.shared
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadSubscriptionInfo()
    }
    
    // MARK: - Subscription Management
    func subscribe(to plan: SubscriptionPlan) async {
        isLoading = true
        error = nil
        
        do {
            // In production, this would integrate with StoreKit
            let subscription = try await purchaseSubscription(plan: plan)
            
            DispatchQueue.main.async {
                self.currentSubscription = subscription
                self.isLoading = false
                self.saveSubscriptionInfo(subscription)
                self.logger.info("Subscribed to \(plan.displayName)")
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
                self.logger.error("Subscription failed: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelSubscription() async {
        isLoading = true
        
        do {
            // In production, this would cancel the subscription
            try await cancelCurrentSubscription()
            
            DispatchQueue.main.async {
                self.currentSubscription = nil
                self.isLoading = false
                self.logger.info("Subscription cancelled")
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
                self.logger.error("Cancellation failed: \(error.localizedDescription)")
            }
        }
    }
    
    func restorePurchases() async {
        isLoading = true
        
        do {
            // In production, this would restore from StoreKit
            let subscription = try await restoreSubscription()
            
            DispatchQueue.main.async {
                self.currentSubscription = subscription
                self.isLoading = false
                self.logger.info("Purchases restored")
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
                self.logger.error("Restore failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Usage Tracking
    func trackTransaction() {
        guard var subscription = currentSubscription else { return }
        
        var usage = subscription.usage
        usage.transactionsThisMonth += 1
        
        subscription.usage = usage
        currentSubscription = subscription
        saveSubscriptionInfo(subscription)
    }
    
    func trackAPICall() {
        guard var subscription = currentSubscription else { return }
        
        var usage = subscription.usage
        usage.apiCallsThisMonth += 1
        
        subscription.usage = usage
        currentSubscription = subscription
        saveSubscriptionInfo(subscription)
    }
    
    // MARK: - Validation
    func canProcessTransaction() -> Bool {
        guard let subscription = currentSubscription else { return false }
        
        switch subscription.status {
        case .active, .trial:
            return subscription.usage.transactionsThisMonth < subscription.plan.transactionLimit
        case .expired, .cancelled, .pending:
            return false
        }
    }
    
    func canMakeAPICall() -> Bool {
        guard let subscription = currentSubscription else { return false }
        
        switch subscription.status {
        case .active, .trial:
            return true
        case .expired, .cancelled, .pending:
            return false
        }
    }
    
    // MARK: - Private Methods
    private func purchaseSubscription(plan: SubscriptionPlan) async throws -> SubscriptionInfo {
        // Simulate API call delay
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // In production, this would integrate with StoreKit
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: now)
        let trialEndDate = Calendar.current.date(byAdding: .day, value: 14, to: now)
        
        return SubscriptionInfo(
            plan: plan,
            status: .trial,
            startDate: now,
            endDate: endDate,
            autoRenew: true,
            trialEndDate: trialEndDate,
            usage: SubscriptionInfo.UsageInfo(
                transactionsThisMonth: 0,
                apiCallsThisMonth: 0,
                storageUsed: 0
            )
        )
    }
    
    private func cancelCurrentSubscription() async throws {
        // Simulate API call delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // In production, this would cancel the subscription
    }
    
    private func restoreSubscription() async throws -> SubscriptionInfo? {
        // Simulate API call delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // In production, this would restore from StoreKit
        return nil
    }
    
    private func loadSubscriptionInfo() {
        if let data = userDefaults.data(forKey: "subscription_info"),
           let subscription = try? JSONDecoder().decode(SubscriptionInfo.self, from: data) {
            self.currentSubscription = subscription
        }
    }
    
    private func saveSubscriptionInfo(_ subscription: SubscriptionInfo) {
        if let data = try? JSONEncoder().encode(subscription) {
            userDefaults.set(data, forKey: "subscription_info")
        }
    }
}

// MARK: - Subscription Errors
enum SubscriptionError: Error, LocalizedError {
    case purchaseFailed
    case restoreFailed
    case invalidProduct
    case paymentCancelled
    case networkError
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        case .restoreFailed:
            return "Failed to restore purchases. Please contact support."
        case .invalidProduct:
            return "Invalid product. Please try again."
        case .paymentCancelled:
            return "Payment was cancelled."
        case .networkError:
            return "Network error. Please check your connection."
        case .unknownError:
            return "An unknown error occurred. Please contact support."
        }
    }
}
