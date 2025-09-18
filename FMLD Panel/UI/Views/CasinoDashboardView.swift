//
//  CasinoDashboardView.swift
//  FMLD Panel
//
//  Created by AI Assistant on 9/13/25.
//

import SwiftUI

struct CasinoDashboardView: View {
    @StateObject private var casinoAI = CasinoAIService.shared
    @StateObject private var transactionRepository = TransactionRepository.shared
    @State private var insights: [CasinoInsight] = []
    @State private var isLoading = false
    @State private var selectedTransaction: Transaction?
    @State private var showingTransactionDetail = false
    @State private var realTimeUpdates = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            headerSection
            
            // Real-time Status
            realTimeStatusSection
            
            // Key Metrics
            keyMetricsSection
            
            // Real-time Alerts
            realTimeAlertsSection
            
            // AI Insights
            aiInsightsSection
            
            // Recent Transactions
            recentTransactionsSection
            
            Spacer()
        }
        .padding()
        .onAppear {
            loadCasinoData()
        }
        .onReceive(Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()) { _ in
            if realTimeUpdates {
                Task {
                    await refreshCasinoData()
                }
            }
        }
        .sheet(isPresented: $showingTransactionDetail) {
            if let transaction = selectedTransaction {
                CasinoTransactionDetailView(transaction: transaction)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🎰 Casino AI Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(realTimeUpdates ? "Pause Updates" : "Resume Updates") {
                        realTimeUpdates.toggle()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Refresh") {
                        Task {
                            await refreshCasinoData()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Text("Real-time AI-powered fraud detection and compliance monitoring for casino operations")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Real-time Status Section
    private var realTimeStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Real-time Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                StatusCard(
                    title: "AI Service",
                    status: casinoAI.isActive ? "Active" : "Inactive",
                    color: casinoAI.isActive ? .green : .red
                )
                
                StatusCard(
                    title: "Compliance",
                    status: casinoAI.complianceStatus.rawValue.capitalized,
                    color: casinoAI.complianceStatus == .compliant ? .green : .red
                )
                
                StatusCard(
                    title: "Active Players",
                    value: "\(casinoAI.playerProfiles.count)",
                    color: .blue
                )
                
                StatusCard(
                    title: "Active Alerts",
                    value: "\(casinoAI.realTimeAlerts.count)",
                    color: casinoAI.realTimeAlerts.isEmpty ? .green : .red
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Key Metrics Section
    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                MetricCard(
                    title: "Total Transactions",
                    value: "\(transactionRepository.transactions.count)",
                    change: "+12%",
                    color: .blue
                )
                
                MetricCard(
                    title: "High Risk Transactions",
                    value: "\(highRiskTransactionCount)",
                    change: "-5%",
                    color: .orange
                )
                
                MetricCard(
                    title: "Fraud Alerts",
                    value: "\(fraudAlertCount)",
                    change: "+2%",
                    color: .red
                )
                
                MetricCard(
                    title: "Compliance Score",
                    value: "\(complianceScore)%",
                    change: "+3%",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - Real-time Alerts Section
    private var realTimeAlertsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Real-time Alerts")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !casinoAI.realTimeAlerts.isEmpty {
                    Text("\(casinoAI.realTimeAlerts.count) active")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if casinoAI.realTimeAlerts.isEmpty {
                Text("No active alerts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(casinoAI.realTimeAlerts.suffix(5), id: \.id) { alert in
                            AlertCard(alert: alert)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - AI Insights Section
    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Insights")
                .font(.headline)
                .fontWeight(.semibold)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing transactions...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if insights.isEmpty {
                Text("No AI insights available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(insights, id: \.type) { insight in
                        CasinoInsightCard(insight: insight)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Recent Transactions Section
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Transactions")
                .font(.headline)
                .fontWeight(.semibold)
            
            if transactionRepository.transactions.isEmpty {
                Text("No transactions available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(transactionRepository.transactions.suffix(10), id: \.id) { transaction in
                            TransactionRow(transaction: transaction)
                                .onTapGesture {
                                    selectedTransaction = transaction
                                    showingTransactionDetail = true
                                }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    private var highRiskTransactionCount: Int {
        transactionRepository.transactions.filter { transaction in
            transaction.amount > 10000 || transaction.country != "US"
        }.count
    }
    
    private var fraudAlertCount: Int {
        casinoAI.realTimeAlerts.filter { $0.type == .fraud }.count
    }
    
    private var complianceScore: Int {
        let totalTransactions = transactionRepository.transactions.count
        guard totalTransactions > 0 else { return 100 }
        
        let compliantTransactions = transactionRepository.transactions.filter { transaction in
            transaction.amount <= 100000 && 
            transaction.country != "AF" && 
            transaction.country != "IR" && 
            transaction.country != "KP"
        }.count
        
        return Int((Double(compliantTransactions) / Double(totalTransactions)) * 100)
    }
    
    // MARK: - Methods
    private func loadCasinoData() {
        Task {
            await refreshCasinoData()
        }
    }
    
    private func refreshCasinoData() async {
        isLoading = true
        
        let newInsights = await casinoAI.getRealTimeCasinoInsights()
        
        await MainActor.run {
            self.insights = newInsights
            self.isLoading = false
        }
    }
}

// MARK: - Supporting Views

struct StatusCard: View {
    let title: String
    let status: String?
    let value: String?
    let color: Color
    
    init(title: String, status: String, color: Color) {
        self.title = title
        self.status = status
        self.value = nil
        self.color = color
    }
    
    init(title: String, value: String, color: Color) {
        self.title = title
        self.status = nil
        self.value = value
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(status ?? value ?? "")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let change: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Spacer()
                
                Text(change)
                    .font(.caption)
                    .foregroundColor(change.hasPrefix("+") ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct AlertCard: View {
    let alert: CasinoAlert
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                alertIcon
                
                Spacer()
                
                Text(alert.severity.rawValue.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(severityColor.opacity(0.2))
                    .foregroundColor(severityColor)
                    .cornerRadius(4)
            }
            
            Text(alert.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(2)
            
            Text(alert.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            Text(alert.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 200)
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var alertIcon: some View {
        Image(systemName: iconForType(alert.type))
            .font(.title2)
            .foregroundColor(severityColor)
    }
    
    private var severityColor: Color {
        switch alert.severity {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
    
    private func iconForType(_ type: AlertType) -> String {
        switch type {
        case .fraud: return "exclamationmark.triangle.fill"
        case .risk: return "warning.fill"
        case .compliance: return "checkmark.shield.fill"
        case .player: return "person.fill"
        }
    }
}

struct CasinoInsightCard: View {
    let insight: CasinoInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                insightIcon
                
                Spacer()
                
                severityBadge
            }
            
            Text(insight.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(2)
            
            Text(insight.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack {
                Text("Confidence: \(Int(insight.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Tap for details")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var insightIcon: some View {
        Image(systemName: iconForType(insight.type))
            .font(.title2)
            .foregroundColor(colorForSeverity(insight.severity))
    }
    
    private var severityBadge: some View {
        Text(insight.severity.uppercased())
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colorForSeverity(insight.severity).opacity(0.2))
            .foregroundColor(colorForSeverity(insight.severity))
            .cornerRadius(6)
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "high_value": return "dollarsign.circle"
        case "velocity": return "speedometer"
        case "player_behavior": return "person.2"
        case "compliance": return "checkmark.shield"
        default: return "lightbulb"
        }
    }
    
    private func colorForSeverity(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        case "critical": return .purple
        default: return .blue
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("$\(String(format: "%.2f", transaction.amount))")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("\(transaction.city), \(transaction.country)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                riskBadge
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var riskBadge: some View {
        let riskLevel = transaction.amount > 10000 ? "HIGH" : transaction.amount > 1000 ? "MEDIUM" : "LOW"
        let color: Color = riskLevel == "HIGH" ? .red : riskLevel == "MEDIUM" ? .orange : .green
        
        return Text(riskLevel)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Casino Transaction Detail View
struct CasinoTransactionDetailView: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    @State private var aiAnalysis: CasinoAnalysisResult?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Transaction Details
                    transactionDetailsSection
                    
                    // AI Analysis
                    if let analysis = aiAnalysis {
                        aiAnalysisSection(analysis)
                    } else if isLoading {
                        loadingSection
                    }
                }
                .padding()
            }
            .navigationTitle("Transaction Analysis")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            loadAIAnalysis()
        }
    }
    
    private var transactionDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transaction Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(label: "Transaction ID", value: transaction.id.uuidString)
                DetailRow(label: "Amount", value: "$\(String(format: "%.2f", transaction.amount))")
                DetailRow(label: "Currency", value: transaction.currency)
                DetailRow(label: "Location", value: "\(transaction.city), \(transaction.country)")
                DetailRow(label: "BIN", value: transaction.bin)
                DetailRow(label: "Timestamp", value: transaction.timestamp.formatted())
                DetailRow(label: "IP Address", value: transaction.ipAddress)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func aiAnalysisSection(_ analysis: CasinoAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Analysis")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(label: "Risk Score", value: String(format: "%.2f", analysis.riskScore))
                DetailRow(label: "Fraud Probability", value: String(format: "%.2f", analysis.fraudProbability))
                DetailRow(label: "Player Risk Level", value: analysis.playerRiskLevel)
                DetailRow(label: "Compliance Status", value: analysis.complianceStatus.rawValue)
                DetailRow(label: "Recommendation", value: analysis.recommendation)
                DetailRow(label: "Processing Time", value: String(format: "%.3f", analysis.processingTime))
            }
            
            if !analysis.explanation.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Explanation")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(analysis.explanation)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Analyzing transaction with AI...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadAIAnalysis() {
        Task {
            let analysis = await CasinoAIService.shared.analyzeCasinoTransaction(transaction)
            
            await MainActor.run {
                self.aiAnalysis = analysis
                self.isLoading = false
            }
        }
    }
}

#Preview {
    CasinoDashboardView()
}
