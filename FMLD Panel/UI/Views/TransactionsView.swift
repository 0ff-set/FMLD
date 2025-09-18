//
//  TransactionsView.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject private var transactionRepository: TransactionRepository
    @EnvironmentObject private var rulesEngine: RulesEngine
    @EnvironmentObject private var riskScorer: RiskScorer
    @StateObject private var binService = RealBinDatabaseService.shared
    @State private var isProcessing: Bool = false
    @State private var newTransactionAmount: String = ""
    @State private var newTransactionCurrency: String = "USD"
    @State private var newTransactionDescription: String = ""
    @State private var newTransactionBin: String = ""
    @State private var selectedTransaction: Transaction?
    @State private var showingTransactionDetail = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Transactions")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Refresh BIN Data") {
                    binService.refreshData()
                }
                .buttonStyle(.bordered)
                .disabled(binService.isLoading)
                
                Button("Add Transaction") {
                    addTransaction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }
            .padding()
            
            // BIN Data Status
            if binService.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading BIN data from APIs...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            } else if !binService.binData.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("BIN data loaded: \(binService.binData.count) records")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            
            // Add Transaction Form
            VStack(alignment: .leading, spacing: 12) {
                Text("Add New Transaction")
                    .font(.headline)
                
                HStack {
                    TextField("Amount", text: $newTransactionAmount)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 120)
                    
                    Picker("Currency", selection: $newTransactionCurrency) {
                        Text("USD").tag("USD")
                        Text("EUR").tag("EUR")
                        Text("GBP").tag("GBP")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 80)
                    
                    TextField("BIN (6 digits)", text: $newTransactionBin)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 120)
                        .onChange(of: newTransactionBin) { _, newValue in
                            if newValue.count == 6 {
                                if let binInfo = binService.lookupBin(newValue) {
                                    print("BIN Found: \(binInfo.bank) - \(binInfo.country)")
                                }
                            }
                        }
                    
                    TextField("Description", text: $newTransactionDescription)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            
            if isProcessing {
                ProgressView("Processing transaction...")
                    .padding()
            }
            
            // Transactions List
            List {
                ForEach(transactionRepository.transactions.sorted(by: { $0.timestamp > $1.timestamp })) { transaction in
                    TransactionRowView(transaction: transaction, binService: binService)
                        .onTapGesture {
                            selectedTransaction = transaction
                            showingTransactionDetail = true
                        }
                        .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(PlainListStyle())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingTransactionDetail) {
            if let transaction = selectedTransaction {
                TransactionDetailView(transaction: transaction)
            }
        }
    }
    
    private func addTransaction() {
        guard let amount = Double(newTransactionAmount), !newTransactionBin.isEmpty else { return }
        
        isProcessing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let binInfo = binService.lookupBin(newTransactionBin)
            
            let newTransaction = Transaction(
                amount: amount,
                currency: newTransactionCurrency,
                cardNumber: "\(newTransactionBin)******\(String(Int.random(in: 1000...9999)))",
                bin: newTransactionBin,
                country: binInfo?.countryCode ?? "Unknown",
                city: "Unknown",
                ipAddress: "192.168.1.1",
                userAgent: "Demo User Agent",
                binInfo: binInfo
            )
            
            // Calculate risk score using ML
            let riskScore = riskScorer.calculateRiskScore(for: newTransaction)
            var updatedTransaction = newTransaction
            updatedTransaction.riskScore = riskScore
            
            // Execute rules
            let ruleResults = rulesEngine.executeRules(for: updatedTransaction)
            let triggeredRules = ruleResults.filter { $0.triggered }
            
            // Determine status based on rules
            if triggeredRules.contains(where: { $0.ruleId == rulesEngine.rules.first(where: { $0.action == .block })?.id }) {
                updatedTransaction.status = .blocked
            } else if triggeredRules.contains(where: { $0.ruleId == rulesEngine.rules.first(where: { $0.action == .review })?.id }) {
                updatedTransaction.status = .review
            } else {
                updatedTransaction.status = .approved
            }
            
            transactionRepository.addTransaction(updatedTransaction)
            newTransactionAmount = ""
            newTransactionDescription = ""
            newTransactionBin = ""
            isProcessing = false
        }
    }
    
}

// MARK: - Transaction Row View
struct TransactionRowView: View {
    let transaction: Transaction
    let binService: RealBinDatabaseService
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.maskedCardNumber)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let binInfo = binService.lookupBin(transaction.bin) {
                    Text("\(binInfo.brand) • \(binInfo.bank)")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text(transaction.city)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(transaction.city)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f %@", transaction.amount, transaction.currency))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(transaction.timestamp, formatter: itemFormatter)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.status.rawValue)
                    .font(.headline)
                    .foregroundColor(statusColor)
                
                Text("Risk: \(transaction.riskLevel.rawValue)")
                    .font(.caption)
                    .foregroundColor(riskColor)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let binInfo = transaction.binInfo {
                    Text(binInfo.bank)
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Text(binInfo.country)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Unknown BIN")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var riskColor: Color {
        switch transaction.riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
    
    private var statusColor: Color {
        switch transaction.status {
        case .pending: return .blue
        case .approved: return .green
        case .review: return .orange
        case .blocked: return .red
        case .cancelled: return .gray
        }
    }
    
    private let itemFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}
