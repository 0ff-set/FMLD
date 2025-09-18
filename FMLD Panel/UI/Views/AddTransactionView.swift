//
//  AddTransactionView.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var transactionRepository: TransactionRepository
    @EnvironmentObject private var rulesEngine: RulesEngine
    @EnvironmentObject private var riskScorer: RiskScorer
    @StateObject private var binService = MockBinDatabaseService.shared
    @StateObject private var geocodingService = GeocodingService.shared
    
    @State private var amount = ""
    @State private var currency = "USD"
    @State private var cardNumber = ""
    @State private var bin = ""
    @State private var country = ""
    @State private var city = ""
    @State private var ipAddress = ""
    @State private var userAgent = ""
    @State private var merchantId = ""
    @State private var userId = ""
    @State private var description = ""
    
    @State private var isProcessing = false
    @State private var showingBINInfo = false
    @State private var binInfo: BinInfo?
    @State private var geocodingResult: GeocodingResult?
    
    private let currencies = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Transaction Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Transaction Details")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("Amount")
                                    .font(.headline)
                                TextField("0.00", text: $amount)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Currency")
                                    .font(.headline)
                        Picker("Currency", selection: $currency) {
                            ForEach(currencies, id: \.self) { curr in
                                Text(curr).tag(curr)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                                .frame(width: 100)
                            }
                        }
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("Card Number")
                                    .font(.headline)
                                TextField("1234567890123456", text: $cardNumber)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onChange(of: cardNumber) { _, newValue in
                                        updateBINFromCardNumber(newValue)
                                    }
                            }
                            
                            VStack(alignment: .leading) {
                                Text("BIN (6 digits)")
                                    .font(.headline)
                                TextField("123456", text: $bin)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onChange(of: bin) { _, newValue in
                                        if newValue.count == 6 {
                                            lookupBIN(newValue)
                                        }
                                    }
                            }
                        }
                        
                        if let binInfo = binInfo {
                            BINInfoCard(binInfo: binInfo) {
                                showingBINInfo = true
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Location Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Location Details")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("Country")
                                    .font(.headline)
                                TextField("United States", text: $country)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                            VStack(alignment: .leading) {
                                Text("City")
                                    .font(.headline)
                                TextField("New York", text: $city)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        
                        HStack {
                            Button("Geocode Address") {
                                geocodeAddress()
                            }
                            .buttonStyle(.bordered)
                            .disabled(city.isEmpty || country.isEmpty)
                            
                            if let result = geocodingResult {
                                Text("✓ Geocoded")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Technical Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Technical Details")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading) {
                                Text("IP Address")
                                    .font(.headline)
                                TextField("192.168.1.1", text: $ipAddress)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                            VStack(alignment: .leading) {
                                Text("User Agent")
                                    .font(.headline)
                                TextField("Mozilla/5.0...", text: $userAgent)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            HStack(spacing: 16) {
                                VStack(alignment: .leading) {
                                    Text("Merchant ID")
                                        .font(.headline)
                                    TextField("Optional", text: $merchantId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                                VStack(alignment: .leading) {
                                    Text("User ID")
                                        .font(.headline)
                                    TextField("Optional", text: $userId)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Description")
                                    .font(.headline)
                                TextField("Transaction description", text: $description, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .lineLimit(2...4)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Action Buttons
                    HStack {
                        Spacer()
                        
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Add Transaction") {
                            addTransaction()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(amount.isEmpty || cardNumber.isEmpty || isProcessing)
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Add Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 700)
        .sheet(isPresented: $showingBINInfo) {
            if let binInfo = binInfo {
                BINDetailView(binInfo: binInfo)
            }
        }
    }
    
    private func updateBINFromCardNumber(_ cardNumber: String) {
        let cleaned = cardNumber.replacingOccurrences(of: " ", with: "")
        if cleaned.count >= 6 {
            let newBIN = String(cleaned.prefix(6))
            if newBIN != bin {
                bin = newBIN
                lookupBIN(newBIN)
            }
        }
    }
    
    private func lookupBIN(_ bin: String) {
        if let foundBINInfo = binService.lookupBin(bin) {
            binInfo = foundBINInfo
            country = foundBINInfo.country
        } else {
            binInfo = nil
        }
    }
    
    private func geocodeAddress() {
        let address = "\(city), \(country)"
        
        Task {
            if let result = await geocodingService.geocodeAddress(address) {
                await MainActor.run {
                    geocodingResult = result
                    country = result.country
                    city = result.locality ?? city
                }
            }
        }
    }
    
    private func addTransaction() {
        guard let amountValue = Double(amount), !cardNumber.isEmpty else { return }
        
        isProcessing = true
        
        let newTransaction = Transaction(
            amount: amountValue,
            currency: currency,
            cardNumber: cardNumber,
            bin: bin,
            country: country,
            city: city,
            ipAddress: ipAddress.isEmpty ? "192.168.1.1" : ipAddress,
            userAgent: userAgent.isEmpty ? "Demo User Agent" : userAgent,
            binInfo: binInfo,
            merchantId: merchantId.isEmpty ? nil : merchantId,
            userId: userId.isEmpty ? nil : userId,
            metadata: description.isEmpty ? nil : description
        )
        
        // Calculate risk score
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isProcessing = false
            dismiss()
        }
    }
}

struct BINInfoCard: View {
    let binInfo: BinInfo
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("BIN Information")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(binInfo.bank) - \(binInfo.country)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(binInfo.brand)
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(binInfo.type)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("View Details") {
                onTap()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

struct BINDetailView: View {
    let binInfo: BinInfo
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("BIN Details")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    DetailRow(label: "BIN", value: binInfo.bin)
                    DetailRow(label: "Bank", value: binInfo.bank)
                    DetailRow(label: "Brand", value: binInfo.brand)
                    DetailRow(label: "Scheme", value: binInfo.scheme)
                    DetailRow(label: "Type", value: binInfo.type)
                    DetailRow(label: "Level", value: binInfo.level)
                    DetailRow(label: "Country", value: binInfo.country)
                    DetailRow(label: "Country Code", value: binInfo.countryCode)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .navigationTitle("BIN Information")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    AddTransactionView()
        .environmentObject(TransactionRepository.shared)
        .environmentObject(RulesEngine.shared)
        .environmentObject(RiskScorer.shared)
}