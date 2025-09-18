//
//  SubscriptionView.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import SwiftUI

struct SubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedPlan: SubscriptionPlan = .professional
    @State private var showingPurchaseAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let subscription = subscriptionManager.currentSubscription {
                    currentSubscriptionView(subscription)
                } else {
                    subscriptionPlansView()
                }
            }
            .navigationTitle("Subscription")
            .padding()
        }
    }
    
    @ViewBuilder
    private func currentSubscriptionView(_ subscription: SubscriptionInfo) -> some View {
        VStack(spacing: 20) {
            // Current Plan Card
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(subscription.plan.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(subscription.plan.price)
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    StatusBadge(status: subscription.status)
                }
                
                // Usage Information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Usage This Month")
                        .font(.headline)
                    
                    UsageBar(
                        current: subscription.usage.transactionsThisMonth,
                        limit: subscription.plan.transactionLimit,
                        label: "Transactions"
                    )
                    
                    HStack {
                        Text("API Calls: \(subscription.usage.apiCallsThisMonth)")
                        Spacer()
                        Text("Storage: \(formatBytes(subscription.usage.storageUsed))")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                // Subscription Details
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Status:")
                        Spacer()
                        Text(subscription.status.rawValue.capitalized)
                            .foregroundColor(statusColor(subscription.status))
                    }
                    
                    HStack {
                        Text("Auto-renew:")
                        Spacer()
                        Text(subscription.autoRenew ? "Yes" : "No")
                    }
                    
                    if let endDate = subscription.endDate {
                        HStack {
                            Text("Next billing:")
                            Spacer()
                            Text(endDate, style: .date)
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Action Buttons
            HStack(spacing: 16) {
                Button("Manage Subscription") {
                    // Open subscription management
                }
                .buttonStyle(.bordered)
                
                Button("Cancel Subscription") {
                    Task {
                        await subscriptionManager.cancelSubscription()
                    }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
    }
    
    @ViewBuilder
    private func subscriptionPlansView() -> some View {
        VStack(spacing: 20) {
            Text("Choose Your Plan")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Select the plan that best fits your needs")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Plan Cards
            VStack(spacing: 16) {
                ForEach(SubscriptionPlan.allCases, id: \.self) { plan in
                    PlanCard(
                        plan: plan,
                        isSelected: selectedPlan == plan,
                        onSelect: { selectedPlan = plan }
                    )
                }
            }
            
            // Purchase Button
            Button(action: {
                showingPurchaseAlert = true
            }) {
                HStack {
                    if subscriptionManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "creditcard.fill")
                    }
                    
                    Text("Subscribe to \(selectedPlan.displayName)")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(subscriptionManager.isLoading)
            
            // Restore Purchases
            Button("Restore Purchases") {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            }
            .foregroundColor(.blue)
        }
        .alert("Confirm Purchase", isPresented: $showingPurchaseAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Purchase") {
                Task {
                    await subscriptionManager.subscribe(to: selectedPlan)
                }
            }
        } message: {
            Text("Are you sure you want to subscribe to \(selectedPlan.displayName) for \(selectedPlan.price)?")
        }
    }
    
    private func statusColor(_ status: SubscriptionStatus) -> Color {
        switch status {
        case .active, .trial:
            return .green
        case .expired, .cancelled:
            return .red
        case .pending:
            return .orange
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text(plan.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(plan.price)
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.features, id: \.self) { feature in
                    HStack {
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text(feature)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onSelect()
        }
    }
}

struct StatusBadge: View {
    let status: SubscriptionStatus
    
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .active, .trial:
            return .green
        case .expired, .cancelled:
            return .red
        case .pending:
            return .orange
        }
    }
}

struct UsageBar: View {
    let current: Int
    let limit: Int
    let label: String
    
    private var percentage: Double {
        guard limit > 0 else { return 0 }
        return min(Double(current) / Double(limit), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(current) / \(limit == Int.max ? "∞" : "\(limit)")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(barColor)
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
    
    private var barColor: Color {
        if percentage > 0.9 {
            return .red
        } else if percentage > 0.7 {
            return .orange
        } else {
            return .green
        }
    }
}

#Preview {
    SubscriptionView()
}

