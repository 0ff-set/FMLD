//
//  RealTimeView.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import SwiftUI

struct RealTimeView: View {
    @EnvironmentObject private var realTimeProcessor: RealTimeProcessor
    @EnvironmentObject private var transactionRepository: TransactionRepository
    @State private var isMonitoring = false
    @State private var selectedTimeRange = 0
    @State private var showingFilters = false
    
    private let timeRanges = ["Last Hour", "Last 6 Hours", "Last 24 Hours", "All Time"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Real-Time Monitoring")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Live transaction processing and monitoring")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Filters") {
                        showingFilters = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button(isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                        toggleMonitoring()
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundColor(isMonitoring ? .red : .green)
                }
            }
            .padding()
            
            // Time Range Picker
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(0..<timeRanges.count, id: \.self) { index in
                    Text(timeRanges[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Stats Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    StatCard(
                        title: "Processed",
                        value: "\(realTimeProcessor.processedCount)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    StatCard(
                        title: "Blocked",
                        value: "\(realTimeProcessor.blockedCount)",
                        icon: "xmark.circle.fill",
                        color: .red
                    )
                    
                    StatCard(
                        title: "Review",
                        value: "\(realTimeProcessor.reviewCount)",
                        icon: "exclamationmark.triangle.fill",
                        color: .orange
                    )
                    
                    StatCard(
                        title: "Processing Rate",
                        value: "\(String(format: "%.1f", realTimeProcessor.processingRate))/min",
                        icon: "speedometer",
                        color: .blue
                    )
                }
                .padding(.horizontal)
            }
            
            // Real-time Transactions
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Live Transactions")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if isMonitoring {
                        HStack {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Live")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.horizontal)
                
                List {
                    ForEach(filteredTransactions) { transaction in
                        RealTimeTransactionRow(transaction: transaction)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startMonitoring()
        }
        .onDisappear {
            stopMonitoring()
        }
        .sheet(isPresented: $showingFilters) {
            FilterView()
        }
    }
    
    private var filteredTransactions: [Transaction] {
        let transactions = transactionRepository.transactions
        let now = Date()
        
        let filtered: [Transaction]
        switch selectedTimeRange {
        case 0: // Last Hour
            filtered = transactions.filter { now.timeIntervalSince($0.timestamp) <= 3600 }
        case 1: // Last 6 Hours
            filtered = transactions.filter { now.timeIntervalSince($0.timestamp) <= 21600 }
        case 2: // Last 24 Hours
            filtered = transactions.filter { now.timeIntervalSince($0.timestamp) <= 86400 }
        default: // All Time
            filtered = transactions
        }
        
        return filtered.sorted { $0.timestamp > $1.timestamp }
    }
    
    private func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }
    
    private func startMonitoring() {
        isMonitoring = true
        realTimeProcessor.startRealTimeIngestion()
    }
    
    private func stopMonitoring() {
        isMonitoring = false
        realTimeProcessor.stopRealTimeIngestion()
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .frame(width: 150, height: 80)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct RealTimeTransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.maskedCardNumber)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(transaction.city), \(transaction.country)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(transaction.timestamp, formatter: timeFormatter)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f %@", transaction.amount, transaction.currency))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(transaction.status.rawValue)
                    .font(.caption)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Risk: \(transaction.riskLevel.rawValue)")
                    .font(.caption)
                    .foregroundColor(riskColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(riskColor.opacity(0.2))
                    .cornerRadius(4)
                
                Text(String(format: "%.2f", transaction.riskScore))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch transaction.status {
        case .approved: return .green
        case .review: return .orange
        case .blocked: return .red
        case .pending: return .blue
        case .cancelled: return .gray
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
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}

struct FilterView: View {
    @Environment(\.dismiss) var dismiss
    @State private var minAmount = ""
    @State private var maxAmount = ""
    @State private var selectedStatus: TransactionStatus?
    @State private var selectedRiskLevel: RiskLevel?
    @State private var selectedCountry = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Amount Range") {
                    TextField("Min Amount", text: $minAmount)
                    TextField("Max Amount", text: $maxAmount)
                }
                
                Section("Status") {
                    Picker("Status", selection: $selectedStatus) {
                        Text("All").tag(nil as TransactionStatus?)
                        ForEach(TransactionStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status as TransactionStatus?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Risk Level") {
                    Picker("Risk Level", selection: $selectedRiskLevel) {
                        Text("All").tag(nil as RiskLevel?)
                        ForEach(RiskLevel.allCases, id: \.self) { risk in
                            Text(risk.rawValue).tag(risk as RiskLevel?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Location") {
                    TextField("Country", text: $selectedCountry)
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyFilters()
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private func applyFilters() {
        // Apply filter logic here
    }
}

#Preview {
    RealTimeView()
        .environmentObject(RealTimeProcessor.shared)
        .environmentObject(TransactionRepository.shared)
}

