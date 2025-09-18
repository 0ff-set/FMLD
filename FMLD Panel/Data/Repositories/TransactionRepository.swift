//
//  TransactionRepository.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation

// MARK: - Transaction Repository
class TransactionRepository: ObservableObject {
    static let shared = TransactionRepository()
    
    private let databaseManager = DatabaseManager.shared
    private let logger = Logger.shared
    
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {
        loadTransactions()
        // Add sample transactions if database is empty
        if transactions.isEmpty {
            addSampleTransactions()
        }
    }
    
    // MARK: - Load Transactions
    func loadTransactions() {
        isLoading = true
        error = nil
        
        do {
            transactions = try databaseManager.fetchTransactions()
            logger.info("Loaded \(transactions.count) transactions")
        } catch {
            self.error = error
            logger.error("Failed to load transactions: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Add Transaction
    func addTransaction(_ transaction: Transaction) {
        do {
            try databaseManager.saveTransaction(transaction)
            transactions.insert(transaction, at: 0)
            logger.transaction(transaction, action: "added")
        } catch {
            self.error = error
            logger.error("Failed to add transaction: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update Transaction
    func updateTransaction(_ transaction: Transaction) {
        do {
            try databaseManager.saveTransaction(transaction)
            if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
                transactions[index] = transaction
            }
            logger.transaction(transaction, action: "updated")
        } catch {
            self.error = error
            logger.error("Failed to update transaction: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sample Data
    private func addSampleTransactions() {
        let sampleTransactions = [
            // High-value luxury purchase - Approved
            Transaction(
                id: UUID(),
                amount: 12500.00,
                currency: "USD",
                cardNumber: "4111111111111111",
                bin: "411111",
                country: "United States",
                city: "New York",
                ipAddress: "192.168.1.100",
                userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
                timestamp: Date().addingTimeInterval(-3600),
                status: .approved,
                riskScore: 0.2,
                binInfo: BinInfo(
                    bin: "411111",
                    brand: "Visa",
                    scheme: "Visa",
                    type: "Debit",
                    country: "United States",
                    countryCode: "US",
                    bank: "Chase Bank",
                    level: "Classic"
                ),
                merchantId: "AMAZON_001",
                userId: "USER_001",
                sessionId: UUID().uuidString,
                deviceFingerprint: "DEVICE_001",
                billingAddress: Address(
                    street: "123 Main St",
                    city: "New York",
                    state: "NY",
                    postalCode: "10001",
                    country: "United States",
                    countryCode: "US"
                ),
                metadata: "High-end electronics purchase"
            ),
            
            // Suspicious high-value transaction - Under Review
            Transaction(
                id: UUID(),
                amount: 25000.00,
                currency: "USD",
                cardNumber: "5555555555554444",
                bin: "555555",
                country: "United States",
                city: "New York",
                ipAddress: "203.0.113.1",
                userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
                timestamp: Date().addingTimeInterval(-7200),
                status: .review,
                riskScore: 0.8,
                binInfo: BinInfo(
                    bin: "555555",
                    brand: "Mastercard",
                    scheme: "Mastercard",
                    type: "Credit",
                    country: "United States",
                    countryCode: "US",
                    bank: "Bank of America",
                    level: "Gold"
                ),
                merchantId: "LUXURY_001",
                userId: "USER_002",
                sessionId: UUID().uuidString,
                deviceFingerprint: "DEVICE_002",
                billingAddress: Address(
                    street: "456 Park Ave",
                    city: "New York",
                    state: "NY",
                    postalCode: "10022",
                    country: "United States",
                    countryCode: "US"
                ),
                metadata: "Luxury watch purchase - Unusual pattern"
            ),
            
            // Low-risk coffee purchase - Approved
            Transaction(
                id: UUID(),
                amount: 25.50,
                currency: "USD",
                cardNumber: "378282246310005",
                bin: "378282",
                country: "United States",
                city: "New York",
                ipAddress: "198.51.100.1",
                userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X)",
                timestamp: Date().addingTimeInterval(-10800),
                status: .approved,
                riskScore: 0.1,
                binInfo: BinInfo(
                    bin: "378282",
                    brand: "American Express",
                    scheme: "American Express",
                    type: "Credit",
                    country: "United States",
                    countryCode: "US",
                    bank: "American Express",
                    level: "Platinum"
                ),
                merchantId: "STARBUCKS_001",
                userId: "USER_003",
                sessionId: UUID().uuidString,
                deviceFingerprint: "DEVICE_003",
                billingAddress: Address(
                    street: "789 Broadway",
                    city: "New York",
                    state: "NY",
                    postalCode: "10003",
                    country: "United States",
                    countryCode: "US"
                ),
                metadata: "Coffee purchase"
            ),
            
            // Cryptocurrency purchase - Blocked
            Transaction(
                id: UUID(),
                amount: 15000.00,
                currency: "USD",
                cardNumber: "6011111111111117",
                bin: "601111",
                country: "United States",
                city: "New York",
                ipAddress: "198.18.0.1",
                userAgent: "Mozilla/5.0 (X11; Linux x86_64)",
                timestamp: Date().addingTimeInterval(-14400),
                status: .blocked,
                riskScore: 0.9,
                binInfo: BinInfo(
                    bin: "601111",
                    brand: "Discover",
                    scheme: "Discover",
                    type: "Credit",
                    country: "United States",
                    countryCode: "US",
                    bank: "Discover Bank",
                    level: "Classic"
                ),
                merchantId: "CRYPTO_001",
                userId: "USER_004",
                sessionId: UUID().uuidString,
                deviceFingerprint: "DEVICE_004",
                billingAddress: Address(
                    street: "321 Wall St",
                    city: "New York",
                    state: "NY",
                    postalCode: "10005",
                    country: "United States",
                    countryCode: "US"
                ),
                metadata: "Cryptocurrency purchase - BLOCKED"
            ),
            
            // International transaction - Approved
            Transaction(
                id: UUID(),
                amount: 89.99,
                currency: "USD",
                cardNumber: "4000000000000002",
                bin: "400000",
                country: "Canada",
                city: "Toronto",
                ipAddress: "203.0.113.2",
                userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
                timestamp: Date().addingTimeInterval(-18000),
                status: .approved,
                riskScore: 0.4,
                binInfo: BinInfo(
                    bin: "400000",
                    brand: "Visa",
                    scheme: "Visa",
                    type: "Debit",
                    country: "Canada",
                    countryCode: "CA",
                    bank: "Royal Bank of Canada",
                    level: "Classic"
                ),
                merchantId: "APPLE_001",
                userId: "USER_005",
                sessionId: UUID().uuidString,
                deviceFingerprint: "DEVICE_005",
                billingAddress: Address(
                    street: "987 Fifth Ave",
                    city: "New York",
                    state: "NY",
                    postalCode: "10028",
                    country: "United States",
                    countryCode: "US"
                ),
                metadata: "Apple accessory purchase"
            ),
            
            // High-risk transaction from suspicious location - Blocked
            Transaction(
                id: UUID(),
                amount: 5000.00,
                currency: "USD",
                cardNumber: "4111111111111111",
                bin: "411111",
                country: "Russia",
                city: "Moscow",
                ipAddress: "192.0.2.1",
                userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
                timestamp: Date().addingTimeInterval(-21600),
                status: .blocked,
                riskScore: 0.95,
                binInfo: BinInfo(
                    bin: "411111",
                    brand: "Visa",
                    scheme: "Visa",
                    type: "Debit",
                    country: "United States",
                    countryCode: "US",
                    bank: "Chase Bank",
                    level: "Classic"
                ),
                merchantId: "SUSPICIOUS_001",
                userId: "USER_006",
                sessionId: UUID().uuidString,
                deviceFingerprint: "DEVICE_006",
                billingAddress: Address(
                    street: "123 Main St",
                    city: "New York",
                    state: "NY",
                    postalCode: "10001",
                    country: "United States",
                    countryCode: "US"
                ),
                metadata: "Suspicious international transaction - BLOCKED"
            ),
            
            // Medium-risk transaction - Under Review
            Transaction(
                id: UUID(),
                amount: 2500.00,
                currency: "USD",
                cardNumber: "5555555555554444",
                bin: "555555",
                country: "United States",
                city: "Los Angeles",
                ipAddress: "203.0.113.3",
                userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
                timestamp: Date().addingTimeInterval(-25200),
                status: .review,
                riskScore: 0.6,
                binInfo: BinInfo(
                    bin: "555555",
                    brand: "Mastercard",
                    scheme: "Mastercard",
                    type: "Credit",
                    country: "United States",
                    countryCode: "US",
                    bank: "Bank of America",
                    level: "Gold"
                ),
                merchantId: "TRAVEL_001",
                userId: "USER_007",
                sessionId: UUID().uuidString,
                deviceFingerprint: "DEVICE_007",
                billingAddress: Address(
                    street: "456 Park Ave",
                    city: "New York",
                    state: "NY",
                    postalCode: "10022",
                    country: "United States",
                    countryCode: "US"
                ),
                metadata: "Travel booking - Unusual location"
            ),
            
            // Low-value transaction - Approved
            Transaction(
                id: UUID(),
                amount: 15.99,
                currency: "USD",
                cardNumber: "378282246310005",
                bin: "378282",
                country: "United States",
                city: "New York",
                ipAddress: "198.51.100.2",
                userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X)",
                timestamp: Date().addingTimeInterval(-28800),
                status: .approved,
                riskScore: 0.05,
                binInfo: BinInfo(
                    bin: "378282",
                    brand: "American Express",
                    scheme: "American Express",
                    type: "Credit",
                    country: "United States",
                    countryCode: "US",
                    bank: "American Express",
                    level: "Platinum"
                ),
                merchantId: "NETFLIX_001",
                userId: "USER_008",
                sessionId: UUID().uuidString,
                deviceFingerprint: "DEVICE_008",
                billingAddress: Address(
                    street: "789 Broadway",
                    city: "New York",
                    state: "NY",
                    postalCode: "10003",
                    country: "United States",
                    countryCode: "US"
                ),
                metadata: "Netflix subscription"
            ),
            
            // High-value international transaction - Under Review
            Transaction(
                id: UUID(),
                amount: 10000.00,
                currency: "EUR",
                cardNumber: "4000000000000002",
                bin: "400000",
                country: "Germany",
                city: "Berlin",
                ipAddress: "203.0.113.4",
                userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
                timestamp: Date().addingTimeInterval(-32400),
                status: .review,
                riskScore: 0.7,
                binInfo: BinInfo(
                    bin: "400000",
                    brand: "Visa",
                    scheme: "Visa",
                    type: "Debit",
                    country: "Canada",
                    countryCode: "CA",
                    bank: "Royal Bank of Canada",
                    level: "Classic"
                ),
                merchantId: "EUROPE_001",
                userId: "USER_009",
                sessionId: UUID().uuidString,
                deviceFingerprint: "DEVICE_009",
                billingAddress: Address(
                    street: "987 Fifth Ave",
                    city: "New York",
                    state: "NY",
                    postalCode: "10028",
                    country: "United States",
                    countryCode: "US"
                ),
                metadata: "High-value international purchase"
            ),
            
            // Suspicious pattern - Blocked
            Transaction(
                id: UUID(),
                amount: 7500.00,
                currency: "USD",
                cardNumber: "6011111111111117",
                bin: "601111",
                country: "United States",
                city: "New York",
                ipAddress: "198.18.0.2",
                userAgent: "Mozilla/5.0 (X11; Linux x86_64)",
                timestamp: Date().addingTimeInterval(-36000),
                status: .blocked,
                riskScore: 0.85,
                binInfo: BinInfo(
                    bin: "601111",
                    brand: "Discover",
                    scheme: "Discover",
                    type: "Credit",
                    country: "United States",
                    countryCode: "US",
                    bank: "Discover Bank",
                    level: "Classic"
                ),
                merchantId: "SUSPICIOUS_002",
                userId: "USER_010",
                sessionId: UUID().uuidString,
                deviceFingerprint: "DEVICE_010",
                billingAddress: Address(
                    street: "321 Wall St",
                    city: "New York",
                    state: "NY",
                    postalCode: "10005",
                    country: "United States",
                    countryCode: "US"
                ),
                metadata: "Suspicious transaction pattern - BLOCKED"
            )
        ]
        
        for transaction in sampleTransactions {
            addTransaction(transaction)
        }
        
        logger.info("Added \(sampleTransactions.count) sample transactions")
    }
    
    // MARK: - Get Statistics
    func getStatistics() -> TransactionStatistics {
        let total = transactions.count
        let approved = transactions.filter { $0.status == .approved }.count
        let review = transactions.filter { $0.status == .review }.count
        let blocked = transactions.filter { $0.status == .blocked }.count
        
        let lowRisk = transactions.filter { $0.riskLevel == .low }.count
        let mediumRisk = transactions.filter { $0.riskLevel == .medium }.count
        let highRisk = transactions.filter { $0.riskLevel == .high }.count
        
        let totalAmount = transactions.reduce(0) { $0 + $1.amount }
        let averageAmount = total > 0 ? totalAmount / Double(total) : 0
        
        return TransactionStatistics(
            total: total,
            approved: approved,
            review: review,
            blocked: blocked,
            lowRisk: lowRisk,
            mediumRisk: mediumRisk,
            highRisk: highRisk,
            totalAmount: totalAmount,
            averageAmount: averageAmount
        )
    }
}

// MARK: - Transaction Statistics
struct TransactionStatistics {
    let total: Int
    let approved: Int
    let review: Int
    let blocked: Int
    let lowRisk: Int
    let mediumRisk: Int
    let highRisk: Int
    let totalAmount: Double
    let averageAmount: Double
    
    var approvalRate: Double {
        return total > 0 ? (Double(approved) / Double(total)) * 100 : 0
    }
    
    var statusDistribution: [(status: TransactionStatus, count: Int)] {
        return [
            (.approved, approved),
            (.review, review),
            (.blocked, blocked)
        ]
    }
    
    var riskDistribution: [(riskLevel: RiskLevel, count: Int)] {
        return [
            (.low, lowRisk),
            (.medium, mediumRisk),
            (.high, highRisk)
        ]
    }
}