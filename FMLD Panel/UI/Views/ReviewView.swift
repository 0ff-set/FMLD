//
//  ReviewView.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var transactionRepository: TransactionRepository
    @EnvironmentObject private var rulesEngine: RulesEngine
    @State private var selectedTransaction: Transaction?
    @State private var showingDetail = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Transaction Review")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(pendingTransactions.count) pending review")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            // Transactions List
            List {
                ForEach(pendingTransactions) { transaction in
                    ReviewTransactionRow(transaction: transaction) {
                        selectedTransaction = transaction
                        showingDetail = true
                    }
                }
            }
            .listStyle(PlainListStyle())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingDetail) {
            if let transaction = selectedTransaction {
                TransactionDetailView(transaction: transaction)
            }
        }
    }
    
    private var pendingTransactions: [Transaction] {
        transactionRepository.transactions
            .filter { $0.status == .review }
            .sorted { $0.timestamp > $1.timestamp }
    }
}

struct ReviewTransactionRow: View {
    let transaction: Transaction
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.maskedCardNumber)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(transaction.city), \(transaction.country)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(transaction.timestamp, formatter: itemFormatter)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f %@", transaction.amount, transaction.currency))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Risk: \(transaction.riskLevel.rawValue)")
                    .font(.caption)
                    .foregroundColor(riskColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(riskColor.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("Approve") {
                    approveTransaction(transaction)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("Block") {
                    blockTransaction(transaction)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private var riskColor: Color {
        switch transaction.riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
    
    private func approveTransaction(_ transaction: Transaction) {
        var updatedTransaction = transaction
        updatedTransaction.status = .approved
        TransactionRepository.shared.updateTransaction(updatedTransaction)
    }
    
    private func blockTransaction(_ transaction: Transaction) {
        var updatedTransaction = transaction
        updatedTransaction.status = .blocked
        TransactionRepository.shared.updateTransaction(updatedTransaction)
    }
    
    private let itemFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}


struct DetailRow: View {
    let label: String
    let value: String
    let formatter: DateFormatter?
    
    init(label: String, value: String) {
        self.label = label
        self.value = value
        self.formatter = nil
    }
    
    init(label: String, value: Date, formatter: DateFormatter) {
        self.label = label
        self.value = formatter.string(from: value)
        self.formatter = formatter
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    ReviewView()
        .environmentObject(TransactionRepository.shared)
        .environmentObject(RulesEngine.shared)
}