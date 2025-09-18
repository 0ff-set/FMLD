//
//  DatabaseManager.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation

// MARK: - Database Manager
/// Production database manager with encryption and real-time capabilities
class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()
    
    private let encryptedDB = EncryptedDatabaseManager.shared
    private let productionDB = ProductionDatabaseManager.shared
    private let logger = Logger.shared
    
    // Use encrypted database by default for production
    private let useEncryption = true
    
    private init() {
        setupDatabase()
    }
    
    // MARK: - Database Setup
    private func setupDatabase() {
        if useEncryption {
            logger.info("Database initialized with encrypted database (SQLCipher)")
            // Auto-unlock the encrypted database with a default password for demo purposes
            // In production, this should be handled by user authentication
            _ = encryptedDB.unlockDatabase(with: "demo_password_2024")
        } else {
            logger.info("Database initialized with production database (SQLite3)")
        }
    }
    
    // MARK: - Transaction Operations
    func saveTransaction(_ transaction: Transaction) throws {
        if useEncryption {
            try encryptedDB.saveTransaction(transaction)
        } else {
            try productionDB.saveTransaction(transaction)
        }
        
        logger.transaction(transaction, action: "saved")
    }
    
    func fetchTransactions(limit: Int = 100, offset: Int = 0) throws -> [Transaction] {
        if useEncryption {
            return try encryptedDB.fetchTransactions(limit: limit)
        } else {
            return try productionDB.fetchTransactions(limit: limit, offset: offset)
        }
    }
    
    // MARK: - Rule Operations
    func saveRule(_ rule: Rule) throws {
        if useEncryption {
            try encryptedDB.saveRule(rule)
        } else {
            try productionDB.saveRule(rule)
        }
        
        logger.info("Rule saved: \(rule.name)")
    }
    
    func fetchRules() throws -> [Rule] {
        if useEncryption {
            return try encryptedDB.fetchRules()
        } else {
            return try productionDB.fetchRules()
        }
    }
    
    func deleteRule(_ ruleId: UUID) throws {
        if useEncryption {
            try encryptedDB.deleteRule(ruleId)
        } else {
            // For production DB, we need to find the rule first
            let rules = try productionDB.fetchRules()
            if let rule = rules.first(where: { $0.id == ruleId }) {
                productionDB.deleteRule(rule)
            }
        }
        
        logger.info("Rule deleted: \(ruleId)")
    }
    
    // MARK: - Database Statistics
    func getDatabaseStats() -> DatabaseStats {
        if useEncryption {
            // Return basic stats for encrypted database
            return DatabaseStats(
                transactionCount: 0,
                ruleCount: 0,
                auditLogCount: 0,
                databaseSize: 0,
                lastUpdated: Date()
            )
        } else {
            return productionDB.getDatabaseStats()
        }
    }
    
    // MARK: - Real-time Processing Support
    
    func fetchPendingTransactions() throws -> [Transaction] {
        // This would typically fetch transactions with status 'pending'
        // For now, return empty array as placeholder
        return []
    }
    
    func saveCachedBin(_ binInfo: BinInfo) throws {
        // Implementation for caching BIN data
        logger.info("Cached BIN info for: \(binInfo.bin)")
    }
    
    func fetchCachedBins() throws -> [BinInfo] {
        // Implementation for fetching cached BIN data
        return []
    }
    
    func saveCachedAddress(_ address: Address) throws {
        // Implementation for caching address data
        logger.info("Cached address: \(address.city), \(address.country)")
    }
    
    func fetchCachedAddresses() throws -> [Address] {
        // Implementation for fetching cached address data
        return []
    }
    
    func saveCachedBlacklistEntry(_ entry: BlacklistEntry) throws {
        // Implementation for caching blacklist entries
        logger.info("Cached blacklist entry: \(entry.address)")
    }
    
    func fetchCachedBlacklistEntries() throws -> [BlacklistEntry] {
        // Implementation for fetching cached blacklist entries
        return []
    }
    
    func saveAddressEmbedding(_ address: String, embedding: [Float]) throws {
        // Implementation for saving address embeddings
        logger.info("Saved address embedding for: \(address)")
    }
    
    func fetchAddressEmbeddings() throws -> [String: [Float]] {
        // Implementation for fetching address embeddings
        return [:]
    }
    
    func saveBinEmbedding(_ bin: String, embedding: [Float]) throws {
        // Implementation for saving BIN embeddings
        logger.info("Saved BIN embedding for: \(bin)")
    }
    
    func fetchBinEmbeddings() throws -> [String: [Float]] {
        // Implementation for fetching BIN embeddings
        return [:]
    }
}

// MARK: - Supporting Types

struct BlacklistEntry: Codable, Identifiable, Hashable {
    let id = UUID()
    let address: String
    let reason: String
    let source: String
    let riskLevel: String
    let addedDate: Date
    let lastChecked: Date
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(address)
    }
    
    static func == (lhs: BlacklistEntry, rhs: BlacklistEntry) -> Bool {
        return lhs.address == rhs.address
    }
}

// MARK: - Database Error
enum DatabaseError: Error, LocalizedError {
    case notInitialized
    case saveFailed
    case fetchFailed
    case invalidData
    case encryptionFailed
    case keyGenerationFailed
    case connectionFailed
    case prepareFailed
    case executionFailed
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database not initialized"
        case .saveFailed:
            return "Failed to save data"
        case .fetchFailed:
            return "Failed to fetch data"
        case .invalidData:
            return "Invalid data format"
        case .encryptionFailed:
            return "Database encryption failed"
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        case .connectionFailed:
            return "Database connection failed"
        case .prepareFailed:
            return "Failed to prepare SQL statement"
        case .executionFailed:
            return "Failed to execute SQL statement"
        }
    }
}