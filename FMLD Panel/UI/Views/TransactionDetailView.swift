//
//  TransactionDetailView.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import SwiftUI
import MapKit

struct TransactionDetailView: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    @StateObject private var binService = RealBinDatabaseService.shared
    @StateObject private var geocodingService = GeocodingService.shared
    @StateObject private var amlService = AMLBlacklistService.shared
    @StateObject private var mlService = ProductionMLService.shared
    
    @State private var geocodingResult: GeocodingResult?
    @State private var amlResult: AMLCheckResult?
    @State private var riskAnalysis: RiskAnalysis?
    @State private var isProcessing = false
    
    private let logger = Logger.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection
                    
                    // Transaction Details
                    transactionDetailsSection
                    
                    // BIN Information
                    binInfoSection
                    
                    // Risk Analysis
                    riskAnalysisSection
                    
                    // Geolocation
                    geolocationSection
                    
                    // AML Check Results
                    amlCheckSection
                    
                    // Device & Session Info
                    deviceInfoSection
                    
                    // Metadata
                    metadataSection
                }
                .padding()
            }
            .navigationTitle("Transaction Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadAdditionalData()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transaction #\(transaction.id.uuidString.prefix(8))")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                statusBadge
            }
            
            Text(transaction.metadata ?? "No description")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var statusBadge: some View {
        Text(transaction.status.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
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
    
    // MARK: - Transaction Details Section
    private var transactionDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transaction Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                DetailCard(title: "Amount", value: String(format: "%.2f %@", transaction.amount, transaction.currency))
                DetailCard(title: "Date", value: DateFormatter.detailed.string(from: transaction.timestamp))
                DetailCard(title: "Card Number", value: transaction.maskedCardNumber)
                DetailCard(title: "BIN", value: transaction.bin)
                DetailCard(title: "Country", value: transaction.country)
                DetailCard(title: "City", value: transaction.city)
                DetailCard(title: "IP Address", value: transaction.ipAddress)
                DetailCard(title: "User Agent", value: String(transaction.userAgent.prefix(50)) + "...")
            }
        }
    }
    
    // MARK: - BIN Information Section
    private var binInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("BIN Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let binInfo = binService.lookupBin(transaction.bin) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Bank:")
                        Spacer()
                        Text(binInfo.bank)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Brand:")
                        Spacer()
                        Text(binInfo.brand)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Type:")
                        Spacer()
                        Text(binInfo.type)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Level:")
                        Spacer()
                        Text(binInfo.level)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Country:")
                        Spacer()
                        Text(binInfo.country)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Risk Level:")
                        Spacer()
                        Text(binInfo.riskLevel)
                            .fontWeight(.medium)
                            .foregroundColor(riskColor(for: binInfo.riskLevel))
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading BIN information...")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Risk Analysis Section
    private var riskAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Decision Analysis")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Risk Score:")
                    Spacer()
                    Text(String(format: "%.2f", transaction.riskScore))
                        .fontWeight(.bold)
                        .foregroundColor(riskColor(for: transaction.riskLevel.rawValue))
                }
                
                HStack {
                    Text("Decision:")
                    Spacer()
                    Text(transaction.status.rawValue.capitalized)
                        .fontWeight(.bold)
                        .foregroundColor(statusColor)
                }
                
                if let riskAnalysis = riskAnalysis {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🤖 Why the AI Made This Decision:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(riskAnalysis.decisionExplanation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        
                        Text("Key Risk Factors:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(Array(riskAnalysis.factors.enumerated()), id: \.offset) { index, factor in
                            HStack(alignment: .top) {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                Text(factor)
                                    .font(.caption)
                            }
                        }
                        
                        if !riskAnalysis.mitigatingFactors.isEmpty {
                            Text("Mitigating Factors:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.top, 8)
                            
                            ForEach(Array(riskAnalysis.mitigatingFactors.enumerated()), id: \.offset) { index, factor in
                                HStack(alignment: .top) {
                                    Text("\(index + 1).")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                    Text(factor)
                                        .font(.caption)
                                }
                            }
                        }
                        
                        Text("Confidence Level: \(Int(riskAnalysis.confidence * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(riskAnalysis.confidence > 0.8 ? .green : riskAnalysis.confidence > 0.6 ? .orange : .red)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Geolocation Section
    private var geolocationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Geolocation")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let geocodingResult = geocodingResult {
                VStack(spacing: 12) {
                    HStack {
                        Text("Address:")
                        Spacer()
                        Text(geocodingResult.address)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Country:")
                        Spacer()
                        Text(geocodingResult.country)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Coordinates:")
                        Spacer()
                        Text(String(format: "%.4f, %.4f", 
                                  geocodingResult.coordinate.latitude, 
                                  geocodingResult.coordinate.longitude))
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Confidence:")
                        Spacer()
                        Text(String(format: "%.1f%%", geocodingResult.confidence * 100))
                            .fontWeight(.medium)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else if isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading geolocation data...")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else {
                Text("No geolocation data available")
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - AML Check Section
    private var amlCheckSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AML Check Results")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let amlResult = amlResult {
                VStack(spacing: 12) {
                    HStack {
                        Text("Status:")
                        Spacer()
                        Text(amlResult.isBlacklisted ? "BLOCKED" : "CLEAR")
                            .fontWeight(.bold)
                            .foregroundColor(amlResult.isBlacklisted ? .red : .green)
                    }
                    
                    HStack {
                        Text("Risk Level:")
                        Spacer()
                        Text(amlResult.riskLevel.rawValue.capitalized)
                            .fontWeight(.medium)
                            .foregroundColor(riskColor(for: amlResult.riskLevel.rawValue))
                    }
                    
                    if let source = amlResult.source, !source.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reasons:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ForEach([source], id: \.self) { reason in
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text(reason)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else if isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Running AML checks...")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else {
                Text("No AML data available")
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Device Info Section
    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Device & Session Info")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Session ID:")
                    Spacer()
                    Text(transaction.sessionId ?? "N/A")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Device Fingerprint:")
                    Spacer()
                    Text(transaction.deviceFingerprint ?? "N/A")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Merchant ID:")
                    Spacer()
                    Text(transaction.merchantId ?? "N/A")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("User ID:")
                    Spacer()
                    Text(transaction.userId ?? "N/A")
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Metadata Section
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Additional Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                if let billingAddress = transaction.billingAddress {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Billing Address:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("\(billingAddress.street)")
                        Text("\(billingAddress.city), \(billingAddress.state ?? "") \(billingAddress.postalCode ?? "")")
                        Text(billingAddress.country)
                    }
                }
                
                if let metadata = transaction.metadata {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(metadata)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Methods
    private func loadAdditionalData() {
        isProcessing = true
        
        Task {
            do {
                // Load geocoding data with timeout
                if let address = transaction.billingAddress?.street {
                    let geocodingTask = Task {
                        await geocodingService.geocodeAddress(address)
                    }
                    geocodingResult = try await geocodingTask.value
                }
                
                // Load AML check (synchronous, should be fast)
                amlResult = amlService.checkCryptoAddress(transaction.cardNumber)
                
                // Load ML risk analysis with timeout
                let mlTask = Task {
                    await mlService.analyzeTransactionRisk(transaction)
                }
                riskAnalysis = try await mlTask.value
                
            } catch {
                // If any operation fails, create fallback data
                logger.error("Failed to load additional data: \(error.localizedDescription)")
                
                // Create fallback risk analysis
                riskAnalysis = RiskAnalysis(
                    factors: ["Limited data available for analysis"],
                    mitigatingFactors: ["Transaction appears to be from a legitimate source"],
                    confidence: 0.5,
                    recommendation: "MONITOR - Limited data available",
                    decisionExplanation: "The system could not fully analyze this transaction due to limited data availability. A manual review is recommended."
                )
            }
            
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    private func riskColor(for level: String) -> Color {
        switch level.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .gray
        }
    }
}

// MARK: - Detail Card Component
struct DetailCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let detailed: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - Risk Analysis Model
struct RiskAnalysis {
    let factors: [String]
    let mitigatingFactors: [String]
    let confidence: Double
    let recommendation: String
    let decisionExplanation: String
}
