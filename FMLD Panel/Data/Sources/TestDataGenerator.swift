//
//  TestDataGenerator.swift
//  FMLD Panel
//
//  Created by AI Assistant on 9/13/25.
//

import Foundation

/// Generates realistic test data for development and testing purposes
class TestDataGenerator: ObservableObject {
    static let shared = TestDataGenerator()
    
    private let logger = Logger.shared
    private let binDatabase = FreeBinDatabase.shared
    
    private init() {}
    
    // MARK: - Transaction Generation
    
    func generateTestTransactions(count: Int = 50) -> [Transaction] {
        var transactions: [Transaction] = []
        
        for _ in 0..<count {
            let transaction = generateRandomTransaction()
            transactions.append(transaction)
        }
        
        logger.info("Generated \(count) test transactions")
        return transactions
    }
    
    private func generateRandomTransaction() -> Transaction {
        let amount = generateRealisticAmount()
        let bin = generateRandomBIN()
        let binInfo = binDatabase.lookupBin(bin) ?? createFallbackBinInfo(bin: bin)
        let location = generateLocation()
        let timestamp = generateRealisticTimestamp()
        
        return Transaction(
            id: UUID(),
            amount: amount,
            currency: "USD",
            cardNumber: "\(bin)****",
            bin: bin,
            country: location.country,
            city: location.city,
            ipAddress: generateRandomIP(),
            userAgent: generateRandomUserAgent(),
            timestamp: timestamp,
            status: generateTransactionStatus(),
            riskScore: generateRiskScore(for: amount, location: location, binInfo: binInfo),
            binInfo: binInfo,
            merchantId: generateMerchantId(),
            userId: generateUserId(),
            sessionId: UUID().uuidString,
            deviceFingerprint: generateDeviceFingerprint(),
            billingAddress: generateBillingAddress(country: location.country, city: location.city)
        )
    }
    
    // MARK: - Amount Generation
    
    private func generateRealisticAmount() -> Double {
        // Weighted distribution for realistic amounts
        let rand = Double.random(in: 0...1)
        
        switch rand {
        case 0...0.4:    // 40% small transactions
            return Double.random(in: 1...100)
        case 0.4...0.7:  // 30% medium transactions
            return Double.random(in: 100...1000)
        case 0.7...0.9:  // 20% large transactions
            return Double.random(in: 1000...5000)
        default:         // 10% very large transactions
            return Double.random(in: 5000...50000)
        }
    }
    
    // MARK: - BIN Generation
    
    private func generateRandomBIN() -> String {
        let commonBins = [
            "411111", "424242", "400000", "400001", "400002", "400003",
            "555555", "510510", "520000", "530000", "540000",
            "378282", "371449", "601111", "601100"
        ]
        
        // 80% chance to use known BIN, 20% chance for random
        if Double.random(in: 0...1) < 0.8 {
            return commonBins.randomElement() ?? "411111"
        } else {
            // Generate random 6-digit BIN
            return String(format: "%06d", Int.random(in: 100000...999999))
        }
    }
    
    private func createFallbackBinInfo(bin: String) -> BinInfo {
        let brands = ["Visa", "Mastercard", "American Express", "Discover"]
        let countries = ["United States", "United Kingdom", "Germany", "France", "Canada"]
        let banks = ["Test Bank", "Demo Bank", "Sample Bank", "Mock Bank"]
        
        return BinInfo(
            bin: bin,
            brand: brands.randomElement() ?? "Visa",
            scheme: brands.randomElement() ?? "Visa",
            type: ["Debit", "Credit"].randomElement() ?? "Debit",
            country: countries.randomElement() ?? "United States",
            countryCode: ["US", "GB", "DE", "FR", "CA"].randomElement() ?? "US",
            bank: banks.randomElement() ?? "Test Bank",
            level: ["Classic", "Gold", "Platinum", "Premium"].randomElement() ?? "Classic"
        )
    }
    
    // MARK: - Location Generation
    
    private func generateLocation() -> (country: String, city: String) {
        let locations: [(country: String, city: String)] = [
            ("United States", "New York"),
            ("United States", "Los Angeles"),
            ("United States", "Chicago"),
            ("United States", "Houston"),
            ("United Kingdom", "London"),
            ("United Kingdom", "Manchester"),
            ("Germany", "Berlin"),
            ("Germany", "Munich"),
            ("France", "Paris"),
            ("France", "Lyon"),
            ("Canada", "Toronto"),
            ("Canada", "Vancouver"),
            ("Australia", "Sydney"),
            ("Australia", "Melbourne"),
            ("Japan", "Tokyo"),
            ("Japan", "Osaka"),
            ("Brazil", "São Paulo"),
            ("Brazil", "Rio de Janeiro"),
            ("India", "Mumbai"),
            ("India", "Delhi")
        ]
        
        return locations.randomElement() ?? ("United States", "New York")
    }
    
    // MARK: - Timestamp Generation
    
    private func generateRealisticTimestamp() -> Date {
        // Generate timestamps within last 30 days
        let now = Date()
        let thirtyDaysAgo = now.addingTimeInterval(-30 * 24 * 60 * 60)
        
        // Weighted towards recent times
        let randomTime = Double.random(in: 0...1)
        let timeInterval: TimeInterval
        
        if randomTime < 0.5 {
            // 50% within last 24 hours
            timeInterval = Double.random(in: 0...24 * 60 * 60)
        } else if randomTime < 0.8 {
            // 30% within last week
            timeInterval = Double.random(in: 24 * 60 * 60...7 * 24 * 60 * 60)
        } else {
            // 20% within last 30 days
            timeInterval = Double.random(in: 7 * 24 * 60 * 60...30 * 24 * 60 * 60)
        }
        
        return now.addingTimeInterval(-timeInterval)
    }
    
    // MARK: - Risk Score Generation
    
    private func generateRiskScore(for amount: Double, location: (country: String, city: String), binInfo: BinInfo) -> Double {
        var riskScore = 0.1 // Base risk
        
        // Amount-based risk
        if amount > 10000 {
            riskScore += 0.4
        } else if amount > 5000 {
            riskScore += 0.2
        } else if amount > 1000 {
            riskScore += 0.1
        }
        
        // Country-based risk
        if binDatabase.isHighRiskCountry(binInfo.countryCode) {
            riskScore += 0.3
        }
        
        // Bank-based risk
        if binDatabase.isHighRiskBank(binInfo.bank) {
            riskScore += 0.2
        }
        
        // Random variation
        riskScore += Double.random(in: -0.1...0.1)
        
        return min(max(riskScore, 0.0), 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func generateTransactionStatus() -> TransactionStatus {
        let rand = Double.random(in: 0...1)
        switch rand {
        case 0...0.7: return .approved
        case 0.7...0.9: return .pending
        default: return .blocked
        }
    }
    
    private func generateRandomIP() -> String {
        let octets = (0..<4).map { _ in Int.random(in: 1...254) }
        return octets.map(String.init).joined(separator: ".")
    }
    
    private func generateRandomUserAgent() -> String {
        let userAgents = [
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
            "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1",
            "Mozilla/5.0 (iPad; CPU OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1"
        ]
        return userAgents.randomElement() ?? userAgents[0]
    }
    
    private func generateMerchantId() -> String {
        let merchants = ["AMAZON", "GOOGLE", "APPLE", "NETFLIX", "SPOTIFY", "UBER", "AIRBNB", "STRIPE", "SHOPIFY", "EBAY"]
        let merchant = merchants.randomElement() ?? "MERCHANT"
        let id = Int.random(in: 1000...9999)
        return "\(merchant)_\(id)"
    }
    
    private func generateUserId() -> String {
        return "USER_\(Int.random(in: 10000...99999))"
    }
    
    private func generateDeviceFingerprint() -> String {
        return UUID().uuidString.prefix(16).uppercased()
    }
    
    private func generateBillingAddress(country: String, city: String) -> Address {
        let streets = ["Main St", "Oak Ave", "First St", "Park Rd", "Elm St", "Second Ave", "Third St"]
        let street = streets.randomElement() ?? "Main St"
        let number = Int.random(in: 100...9999)
        
        return Address(
            street: "\(number) \(street)",
            city: city,
            state: generateState(for: country),
            postalCode: generatePostalCode(for: country),
            country: country,
            countryCode: getCountryCode(for: country)
        )
    }
    
    private func generateState(for country: String) -> String {
        let states: [String: [String]] = [
            "United States": ["NY", "CA", "TX", "FL", "IL", "PA", "OH", "GA", "NC", "MI"],
            "Canada": ["ON", "BC", "AB", "QC", "MB", "SK", "NS", "NB", "NL", "PE"],
            "Australia": ["NSW", "VIC", "QLD", "WA", "SA", "TAS", "ACT", "NT"]
        ]
        return states[country]?.randomElement() ?? "Unknown"
    }
    
    private func generatePostalCode(for country: String) -> String {
        switch country {
        case "United States":
            return "\(Int.random(in: 10000...99999))"
        case "Canada":
            let letter1 = Character(UnicodeScalar(65 + Int.random(in: 0...25))!)
            let digit1 = Int.random(in: 0...9)
            let letter2 = Character(UnicodeScalar(65 + Int.random(in: 0...25))!)
            let digit2 = Int.random(in: 0...9)
            let letter3 = Character(UnicodeScalar(65 + Int.random(in: 0...25))!)
            let digit3 = Int.random(in: 0...9)
            return "\(letter1)\(digit1)\(letter2) \(digit2)\(letter3)\(digit3))"
        case "United Kingdom":
            let letters = (0..<2).map { _ in Character(UnicodeScalar(65 + Int.random(in: 0...25))!) }
            let digits = (0..<2).map { _ in Int.random(in: 0...9) }
            let letter = Character(UnicodeScalar(65 + Int.random(in: 0...25))!)
            return "\(letters[0])\(letters[1])\(digits[0])\(digits[1]) \(letter)\(Int.random(in: 0...9))"
        default:
            return "\(Int.random(in: 1000...99999))"
        }
    }
    
    private func getCountryCode(for country: String) -> String {
        let countryCodes: [String: String] = [
            "United States": "US",
            "United Kingdom": "GB",
            "Germany": "DE",
            "France": "FR",
            "Canada": "CA",
            "Australia": "AU",
            "Japan": "JP",
            "China": "CN",
            "India": "IN",
            "Brazil": "BR"
        ]
        return countryCodes[country] ?? "XX"
    }
    
    // MARK: - Specialized Test Data
    
    func generateHighRiskTransactions(count: Int = 10) -> [Transaction] {
        var transactions: [Transaction] = []
        
        for _ in 0..<count {
            let transaction = generateHighRiskTransaction()
            transactions.append(transaction)
        }
        
        logger.info("Generated \(count) high-risk test transactions")
        return transactions
    }
    
    private func generateHighRiskTransaction() -> Transaction {
        let baseTransaction = generateRandomTransaction()
        
        // Create new high-risk transaction
        let highRiskAmount = Double.random(in: 10000...100000)
        let highRiskScore = Double.random(in: 0.7...1.0)
        
        // Use high-risk country
        let highRiskBinInfo = BinInfo(
            bin: baseTransaction.bin,
            brand: baseTransaction.binInfo?.brand ?? "Visa",
            scheme: baseTransaction.binInfo?.scheme ?? "Visa",
            type: baseTransaction.binInfo?.type ?? "Debit",
            country: "Russia",
            countryCode: "RU",
            bank: baseTransaction.binInfo?.bank ?? "Test Bank",
            level: baseTransaction.binInfo?.level ?? "Classic"
        )
        
        return Transaction(
            id: baseTransaction.id,
            amount: highRiskAmount,
            currency: baseTransaction.currency,
            cardNumber: baseTransaction.cardNumber,
            bin: baseTransaction.bin,
            country: "Russia",
            city: "Moscow",
            ipAddress: baseTransaction.ipAddress,
            userAgent: baseTransaction.userAgent,
            timestamp: baseTransaction.timestamp,
            status: baseTransaction.status,
            riskScore: highRiskScore,
            binInfo: highRiskBinInfo,
            merchantId: baseTransaction.merchantId,
            userId: baseTransaction.userId,
            sessionId: baseTransaction.sessionId,
            deviceFingerprint: baseTransaction.deviceFingerprint,
            billingAddress: baseTransaction.billingAddress
        )
    }
    
    func generateFraudulentTransactions(count: Int = 5) -> [Transaction] {
        var transactions: [Transaction] = []
        
        for _ in 0..<count {
            let transaction = generateFraudulentTransaction()
            transactions.append(transaction)
        }
        
        logger.info("Generated \(count) fraudulent test transactions")
        return transactions
    }
    
    private func generateFraudulentTransaction() -> Transaction {
        let baseTransaction = generateRandomTransaction()
        
        // Create new fraudulent transaction
        return Transaction(
            id: baseTransaction.id,
            amount: Double.random(in: 50000...500000),
            currency: baseTransaction.currency,
            cardNumber: baseTransaction.cardNumber,
            bin: baseTransaction.bin,
            country: baseTransaction.country,
            city: baseTransaction.city,
            ipAddress: "192.168.10.1", // Suspicious internal IP
            userAgent: "SuspiciousBot/1.0", // Suspicious user agent
            timestamp: baseTransaction.timestamp,
            status: .blocked,
            riskScore: 0.95,
            binInfo: baseTransaction.binInfo,
            merchantId: baseTransaction.merchantId,
            userId: baseTransaction.userId,
            sessionId: baseTransaction.sessionId,
            deviceFingerprint: baseTransaction.deviceFingerprint,
            billingAddress: baseTransaction.billingAddress
        )
    }
}

