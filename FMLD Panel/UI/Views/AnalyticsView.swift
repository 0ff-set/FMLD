//
//  AnalyticsView.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject private var transactionRepository: TransactionRepository
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Analytics Dashboard")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    // Total Transactions
                    AnalyticsCard(
                        title: "Total Transactions",
                        value: "\(transactionRepository.transactions.count)",
                        icon: "list.bullet.rectangle.portrait",
                        color: .blue
                    )
                    
                    // Total Volume
                    AnalyticsCard(
                        title: "Total Volume",
                        value: String(format: "%.2f", totalVolume),
                        icon: "dollarsign.circle.fill",
                        color: .green
                    )
                    
                    // High Risk Count
                    AnalyticsCard(
                        title: "High Risk",
                        value: "\(highRiskCount)",
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                    
                    // Approval Rate
                    AnalyticsCard(
                        title: "Approval Rate",
                        value: String(format: "%.1f%%", approvalRate),
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                }
                .padding()
                
                // Charts Section
                VStack(alignment: .leading, spacing: 20) {
                    Text("Transaction Analysis")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    // Status Distribution
                    VStack(alignment: .leading) {
                        Text("Status Distribution")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack(spacing: 20) {
                            ForEach(statusDistribution, id: \.status) { item in
                                VStack {
                                    Text(item.status)
                                        .font(.caption)
                                    Text("\(item.count)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(colorForStatus(item.status))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Risk Level Distribution
                    VStack(alignment: .leading) {
                        Text("Risk Level Distribution")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack(spacing: 20) {
                            ForEach(riskDistribution, id: \.riskLevel) { item in
                                VStack {
                                    Text(item.riskLevel)
                                        .font(.caption)
                                    Text("\(item.count)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(colorForRiskLevel(item.riskLevel))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var totalVolume: Double {
        statistics.totalAmount
    }
    
    private var statistics: TransactionStatistics {
        transactionRepository.getStatistics()
    }
    
    private var highRiskCount: Int {
        statistics.highRisk
    }
    
    private var approvalRate: Double {
        statistics.approvalRate
    }
    
    private var statusDistribution: [(status: String, count: Int)] {
        statistics.statusDistribution.map { (status, count) in (status.rawValue, count) }
    }
    
    private var riskDistribution: [(riskLevel: String, count: Int)] {
        statistics.riskDistribution.map { (riskLevel, count) in (riskLevel.rawValue, count) }
    }
    
    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "Approved": return .green
        case "Review": return .orange
        case "Blocked": return .red
        default: return .gray
        }
    }
    
    private func colorForRiskLevel(_ riskLevel: String) -> Color {
        switch riskLevel {
        case "Low": return .green
        case "Medium": return .orange
        case "High": return .red
        default: return .gray
        }
    }
}

// MARK: - Analytics Card
struct AnalyticsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}