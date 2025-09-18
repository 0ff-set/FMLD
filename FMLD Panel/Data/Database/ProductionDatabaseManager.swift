//
//  ProductionDatabaseManager.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation
import SQLite3

// MARK: - Production Database Manager
class ProductionDatabaseManager: ObservableObject {
    static let shared = ProductionDatabaseManager()
    
    private let logger = Logger.shared
    private var db: OpaquePointer?
    private let dbPath: String
    
    private init() {
        // Get documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.dbPath = documentsPath.appendingPathComponent("fmld_production.db").path
        
        setupDatabase()
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Setup
    
    private func setupDatabase() {
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            logger.error("Failed to open database")
            return
        }
        
        createTables()
        logger.info("Production database initialized")
    }
    
    private func createTables() {
        let createTransactionsTable = """
        CREATE TABLE IF NOT EXISTS transactions (
            id TEXT PRIMARY KEY,
            amount REAL NOT NULL,
            currency TEXT NOT NULL,
            card_number TEXT NOT NULL,
            bin TEXT NOT NULL,
            country TEXT,
            city TEXT,
            ip_address TEXT,
            user_agent TEXT,
            timestamp REAL NOT NULL,
            status TEXT NOT NULL,
            risk_score REAL NOT NULL,
            metadata TEXT
        )
        """
        
        let createRulesTable = """
        CREATE TABLE IF NOT EXISTS rules (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            category TEXT NOT NULL,
            conditions TEXT NOT NULL,
            action TEXT NOT NULL,
            is_active INTEGER NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        )
        """
        
        executeSQL(createTransactionsTable)
        executeSQL(createRulesTable)
    }
    
    private func executeSQL(_ sql: String) {
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                logger.error("SQL execution failed: \(sql)")
            }
        } else {
            logger.error("SQL preparation failed: \(sql)")
        }
        
        sqlite3_finalize(statement)
    }
    
    private func closeDatabase() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }
    
    // MARK: - Transaction Operations
    
    func saveTransaction(_ transaction: Transaction) throws {
        let sql = """
        INSERT OR REPLACE INTO transactions (
            id, amount, currency, card_number, bin, country, city,
            ip_address, user_agent, timestamp, status, risk_score, metadata
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        // Bind parameters
        sqlite3_bind_text(statement, 1, transaction.id.uuidString, -1, nil)
        sqlite3_bind_double(statement, 2, transaction.amount)
        sqlite3_bind_text(statement, 3, transaction.currency, -1, nil)
        sqlite3_bind_text(statement, 4, transaction.cardNumber, -1, nil)
        sqlite3_bind_text(statement, 5, transaction.bin, -1, nil)
        sqlite3_bind_text(statement, 6, transaction.country, -1, nil)
        sqlite3_bind_text(statement, 7, transaction.city, -1, nil)
        sqlite3_bind_text(statement, 8, transaction.ipAddress, -1, nil)
        sqlite3_bind_text(statement, 9, transaction.userAgent, -1, nil)
        sqlite3_bind_double(statement, 10, transaction.timestamp.timeIntervalSince1970)
        sqlite3_bind_text(statement, 11, transaction.status.rawValue, -1, nil)
        sqlite3_bind_double(statement, 12, transaction.riskScore)
        sqlite3_bind_text(statement, 13, transaction.metadata, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executionFailed
        }
        
        logger.info("Transaction saved: \(transaction.id)")
    }
    
    func fetchTransactions(limit: Int = 100, offset: Int = 0) throws -> [Transaction] {
        let sql = "SELECT * FROM transactions ORDER BY timestamp DESC LIMIT ? OFFSET ?"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int(statement, 1, Int32(limit))
        sqlite3_bind_int(statement, 2, Int32(offset))
        
        var transactions: [Transaction] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let transaction = parseTransaction(from: statement) {
                transactions.append(transaction)
            }
        }
        
        return transactions
    }
    
    // MARK: - Rule Operations
    
    func saveRule(_ rule: Rule) throws {
        let sql = """
        INSERT OR REPLACE INTO rules (
            id, name, description, category, conditions, action, 
            is_active, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        // Convert conditions to JSON
        let conditionsData = try JSONEncoder().encode(rule.conditions)
        let conditionsJSON = String(data: conditionsData, encoding: .utf8) ?? "[]"
        
        sqlite3_bind_text(statement, 1, rule.id.uuidString, -1, nil)
        sqlite3_bind_text(statement, 2, rule.name, -1, nil)
        sqlite3_bind_text(statement, 3, rule.description, -1, nil)
        sqlite3_bind_text(statement, 4, rule.category.rawValue, -1, nil)
        sqlite3_bind_text(statement, 5, conditionsJSON, -1, nil)
        sqlite3_bind_text(statement, 6, rule.action.rawValue, -1, nil)
        sqlite3_bind_int(statement, 7, rule.isActive ? 1 : 0)
        sqlite3_bind_double(statement, 8, rule.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 9, rule.updatedAt.timeIntervalSince1970)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executionFailed
        }
        
        logger.info("Rule saved: \(rule.name)")
    }
    
    func fetchRules() throws -> [Rule] {
        let sql = "SELECT * FROM rules ORDER BY created_at DESC"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        var rules: [Rule] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let rule = parseRule(from: statement) {
                rules.append(rule)
            }
        }
        
        return rules
    }
    
    func deleteRule(_ rule: Rule) {
        let sql = "DELETE FROM rules WHERE id = ?"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            logger.error("Failed to prepare delete statement")
            return
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, rule.id.uuidString, -1, nil)
        
        if sqlite3_step(statement) == SQLITE_DONE {
            logger.info("Rule deleted: \(rule.name)")
        } else {
            logger.error("Failed to delete rule: \(rule.name)")
        }
    }
    
    // MARK: - Database Statistics
    
    func getDatabaseStats() -> DatabaseStats {
        let transactionCount = getTableCount("transactions")
        let ruleCount = getTableCount("rules")
        
        return DatabaseStats(
            transactionCount: transactionCount,
            ruleCount: ruleCount,
            auditLogCount: 0,
            databaseSize: getDatabaseSize(),
            lastUpdated: Date()
        )
    }
    
    private func getTableCount(_ tableName: String) -> Int {
        let sql = "SELECT COUNT(*) FROM \(tableName)"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return 0
        }
        
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }
        
        return 0
    }
    
    private func getDatabaseSize() -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: dbPath)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    // MARK: - Parsing Methods
    
    private func parseTransaction(from statement: OpaquePointer?) -> Transaction? {
        guard let statement = statement else { return nil }
        
        let id = String(cString: sqlite3_column_text(statement, 0))
        let amount = sqlite3_column_double(statement, 1)
        let currency = String(cString: sqlite3_column_text(statement, 2))
        let cardNumber = String(cString: sqlite3_column_text(statement, 3))
        let bin = String(cString: sqlite3_column_text(statement, 4))
        let country = String(cString: sqlite3_column_text(statement, 5))
        let city = String(cString: sqlite3_column_text(statement, 6))
        let ipAddress = String(cString: sqlite3_column_text(statement, 7))
        let userAgent = String(cString: sqlite3_column_text(statement, 8))
        let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 9))
        let statusString = String(cString: sqlite3_column_text(statement, 10))
        let riskScore = sqlite3_column_double(statement, 11)
        let metadata = sqlite3_column_text(statement, 12).map { String(cString: $0) }
        
        let status = TransactionStatus(rawValue: statusString) ?? .pending
        
        return Transaction(
            id: UUID(uuidString: id) ?? UUID(),
            amount: amount,
            currency: currency,
            cardNumber: cardNumber,
            bin: bin,
            country: country,
            city: city,
            ipAddress: ipAddress,
            userAgent: userAgent,
            timestamp: timestamp,
            status: status,
            riskScore: riskScore,
            binInfo: nil,
            merchantId: nil,
            userId: nil,
            sessionId: nil,
            deviceFingerprint: nil,
            billingAddress: nil,
            metadata: metadata
        )
    }
    
    private func parseRule(from statement: OpaquePointer?) -> Rule? {
        guard let statement = statement else { return nil }
        
        let id = String(cString: sqlite3_column_text(statement, 0))
        let name = String(cString: sqlite3_column_text(statement, 1))
        let description = sqlite3_column_text(statement, 2).map { String(cString: $0) }
        let categoryString = String(cString: sqlite3_column_text(statement, 3))
        let conditionsJSON = String(cString: sqlite3_column_text(statement, 4))
        let actionString = String(cString: sqlite3_column_text(statement, 5))
        let isActive = sqlite3_column_int(statement, 6) != 0
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 7))
        let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 8))
        
        // Parse conditions from JSON
        let conditionsData = conditionsJSON.data(using: .utf8) ?? Data()
        let conditions = (try? JSONDecoder().decode([RuleCondition].self, from: conditionsData)) ?? []
        
        let category = RuleCategory(rawValue: categoryString) ?? .custom
        let action = RuleAction(rawValue: actionString) ?? .review
        
        return Rule(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            description: description ?? "",
            category: category,
            priority: 100, // Default priority
            isActive: isActive,
            conditions: conditions,
            action: action,
            createdAt: createdAt,
            updatedAt: updatedAt,
            createdBy: "System" // Default creator
        )
    }
}

// MARK: - Database Stats
struct DatabaseStats {
    let transactionCount: Int
    let ruleCount: Int
    let auditLogCount: Int
    let databaseSize: Int64
    let lastUpdated: Date
}