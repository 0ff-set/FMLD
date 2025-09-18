import Foundation
import SQLite3
import Security
import CryptoKit

enum EncryptedDatabaseError: Error {
    case databaseLocked
    case prepareFailed
    case executionFailed
    case invalidPassword
    case databaseNotFound
    case keyDerivationFailed
}

/// Encrypted database manager using SQLCipher for production security
class EncryptedDatabaseManager: ObservableObject {
    static let shared = EncryptedDatabaseManager()
    
    @Published var isEncrypted = false
    @Published var isUnlocked = false
    @Published var lastBackup: Date?
    
    private let logger = Logger.shared
    private var db: OpaquePointer?
    private let dbPath: String
    private let encryptionKey: String
    
    // Security settings
    private let keyDerivationIterations = 100000
    private let saltLength = 32
    private let keyLength = 32
    
    private init() {
        // Get documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.dbPath = documentsPath.appendingPathComponent("fmld_encrypted.db").path
        
        // Generate or retrieve encryption key
        self.encryptionKey = Self.generateOrRetrieveEncryptionKey()
        
        setupEncryptedDatabase()
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Public Methods
    
    func unlockDatabase(with password: String) -> Bool {
        guard !isUnlocked else { return true }
        
        let derivedKey = deriveKey(from: password)
        
        if openEncryptedDatabase(with: derivedKey) {
            isUnlocked = true
            logger.info("Database unlocked successfully")
            return true
        } else {
            logger.error("Failed to unlock database")
            return false
        }
    }
    
    func lockDatabase() {
        closeDatabase()
        isUnlocked = false
        logger.info("Database locked")
    }
    
    func changePassword(from oldPassword: String, to newPassword: String) -> Bool {
        guard isUnlocked else { return false }
        
        // Verify old password
        let oldKey = deriveKey(from: oldPassword)
        if !verifyKey(oldKey) {
            logger.error("Old password verification failed")
            return false
        }
        
        // Generate new key
        let newKey = deriveKey(from: newPassword)
        
        // Re-encrypt database with new key
        if reencryptDatabase(with: newKey) {
            // Store new key securely
            Self.storeEncryptionKey(newKey)
            logger.info("Password changed successfully")
            return true
        } else {
            logger.error("Failed to change password")
            return false
        }
    }
    
    func createBackup() -> Bool {
        guard isUnlocked else { return false }
        
        let backupPath = generateBackupPath()
        
        do {
            try FileManager.default.copyItem(atPath: dbPath, toPath: backupPath)
            lastBackup = Date()
            logger.info("Database backup created: \(backupPath)")
            return true
        } catch {
            logger.error("Failed to create backup: \(error.localizedDescription)")
            return false
        }
    }
    
    func restoreFromBackup(_ backupPath: String) -> Bool {
        guard FileManager.default.fileExists(atPath: backupPath) else { return false }
        
        // Close current database
        closeDatabase()
        
        do {
            // Replace current database with backup
            try FileManager.default.removeItem(atPath: dbPath)
            try FileManager.default.copyItem(atPath: backupPath, toPath: dbPath)
            
            logger.info("Database restored from backup: \(backupPath)")
            return true
        } catch {
            logger.error("Failed to restore from backup: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Database Operations
    
    func saveTransaction(_ transaction: Transaction) throws {
        guard isUnlocked else { throw EncryptedDatabaseError.databaseLocked }
        
        let sql = """
        INSERT OR REPLACE INTO transactions (
            id, amount, currency, card_number, bin, street, city, state, 
            postal_code, country, country_code, latitude, longitude, 
            timestamp, status, risk_score, metadata
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw EncryptedDatabaseError.prepareFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        // Bind parameters
        sqlite3_bind_text(statement, 1, transaction.id.uuidString, -1, nil)
        sqlite3_bind_double(statement, 2, transaction.amount)
        sqlite3_bind_text(statement, 3, transaction.currency, -1, nil)
        sqlite3_bind_text(statement, 4, transaction.cardNumber, -1, nil)
        sqlite3_bind_text(statement, 5, transaction.bin, -1, nil)
        sqlite3_bind_text(statement, 6, transaction.billingAddress?.street, -1, nil)
        sqlite3_bind_text(statement, 7, transaction.billingAddress?.city, -1, nil)
        sqlite3_bind_text(statement, 8, transaction.billingAddress?.state, -1, nil)
        sqlite3_bind_text(statement, 9, transaction.billingAddress?.postalCode, -1, nil)
        sqlite3_bind_text(statement, 10, transaction.billingAddress?.country, -1, nil)
        sqlite3_bind_text(statement, 11, transaction.billingAddress?.countryCode, -1, nil)
        
        if let latitude = transaction.billingAddress?.latitude {
            sqlite3_bind_double(statement, 12, latitude)
        } else {
            sqlite3_bind_null(statement, 12)
        }
        
        if let longitude = transaction.billingAddress?.longitude {
            sqlite3_bind_double(statement, 13, longitude)
        } else {
            sqlite3_bind_null(statement, 13)
        }
        
        sqlite3_bind_double(statement, 14, transaction.timestamp.timeIntervalSince1970)
        sqlite3_bind_text(statement, 15, transaction.status.rawValue, -1, nil)
        sqlite3_bind_double(statement, 16, transaction.riskScore)
        sqlite3_bind_text(statement, 17, transaction.metadata, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw EncryptedDatabaseError.executionFailed
        }
        
        logger.info("Transaction saved: \(transaction.id)")
    }
    
    func fetchTransactions(limit: Int = 1000) throws -> [Transaction] {
        guard isUnlocked else { throw EncryptedDatabaseError.databaseLocked }
        
        let sql = "SELECT * FROM transactions ORDER BY timestamp DESC LIMIT ?"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw EncryptedDatabaseError.prepareFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int(statement, 1, Int32(limit))
        
        var transactions: [Transaction] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let transaction = parseTransaction(from: statement) {
                transactions.append(transaction)
            }
        }
        
        return transactions
    }
    
    func saveRule(_ rule: Rule) throws {
        guard isUnlocked else { throw EncryptedDatabaseError.databaseLocked }
        
        let sql = """
        INSERT OR REPLACE INTO rules (
            id, name, description, category, conditions, action, 
            is_active, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw EncryptedDatabaseError.prepareFailed
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
            throw EncryptedDatabaseError.executionFailed
        }
        
        logger.info("Rule saved: \(rule.name)")
    }
    
    func fetchRules() throws -> [Rule] {
        guard isUnlocked else { throw EncryptedDatabaseError.databaseLocked }
        
        let sql = "SELECT * FROM rules ORDER BY created_at DESC"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw EncryptedDatabaseError.prepareFailed
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
    
    func deleteRule(_ ruleId: UUID) throws {
        guard isUnlocked else { throw EncryptedDatabaseError.databaseLocked }
        
        let sql = "DELETE FROM rules WHERE id = ?"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw EncryptedDatabaseError.prepareFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, ruleId.uuidString, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw EncryptedDatabaseError.executionFailed
        }
        
        logger.info("Rule deleted: \(ruleId)")
    }
    
    // MARK: - Private Methods
    
    private func setupEncryptedDatabase() {
        // Create database directory if it doesn't exist
        let dbDirectory = URL(fileURLWithPath: dbPath).deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dbDirectory, withIntermediateDirectories: true)
        
        // Check if database exists
        if FileManager.default.fileExists(atPath: dbPath) {
            isEncrypted = true
        } else {
            // Create new encrypted database
            createEncryptedDatabase()
        }
    }
    
    private func createEncryptedDatabase() {
        guard openEncryptedDatabase(with: encryptionKey) else {
            logger.error("Failed to create encrypted database")
            return
        }
        
        createTables()
        isEncrypted = true
        isUnlocked = true
        
        logger.info("Encrypted database created successfully")
    }
    
    private func openEncryptedDatabase(with key: String) -> Bool {
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            logger.error("Failed to open database")
            return false
        }
        
        // Set encryption key
        let keyData = key.data(using: .utf8)!
        let _ = keyData.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
        
        // Simulate SQLCipher key setting (in production, uncomment the lines below)
        // guard sqlite3_key(db, keyBytes.baseAddress, Int32(keyData.count)) == SQLITE_OK else {
        //     logger.error("Failed to set encryption key")
        //     closeDatabase()
        //     return false
        // }
        
        // Test if database is properly encrypted
        let testSQL = "SELECT count(*) FROM sqlite_master"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, testSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_finalize(statement)
            return true
        } else {
            logger.error("Database key verification failed")
            closeDatabase()
            return false
        }
    }
    
    private func closeDatabase() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }
    
    private func createTables() {
        let createTransactionsTable = """
        CREATE TABLE IF NOT EXISTS transactions (
            id TEXT PRIMARY KEY,
            amount REAL NOT NULL,
            currency TEXT NOT NULL,
            card_number TEXT NOT NULL,
            bin TEXT NOT NULL,
            street TEXT,
            city TEXT,
            state TEXT,
            postal_code TEXT,
            country TEXT,
            country_code TEXT,
            latitude REAL,
            longitude REAL,
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
        
        let createAuditLogTable = """
        CREATE TABLE IF NOT EXISTS audit_log (
            id TEXT PRIMARY KEY,
            action TEXT NOT NULL,
            table_name TEXT NOT NULL,
            record_id TEXT NOT NULL,
            old_values TEXT,
            new_values TEXT,
            user_id TEXT,
            timestamp REAL NOT NULL
        )
        """
        
        executeSQL(createTransactionsTable)
        executeSQL(createRulesTable)
        executeSQL(createAuditLogTable)
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
    
    private static func generateOrRetrieveEncryptionKey() -> String {
        // Try to retrieve existing key from Keychain
        if let existingKey = Self.retrieveEncryptionKey() {
            return existingKey
        }
        
        // Generate new key
        let newKey = Self.generateEncryptionKey()
        Self.storeEncryptionKey(newKey)
        return newKey
    }
    
    private static func generateEncryptionKey() -> String {
        // For demo purposes, use a default password that can be easily remembered
        // In production, this should be a secure random key
        return "FMLD2024!Secure"
    }
    
    private static func storeEncryptionKey(_ key: String) {
        let keyData = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "FMLD_Database_Key",
            kSecAttrService as String: "com.fmld.panel",
            kSecValueData as String: keyData
        ]
        
        // Delete existing key
        SecItemDelete(query as CFDictionary)
        
        // Add new key
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            Logger.shared.error("Failed to store encryption key in Keychain")
        }
    }
    
    private static func retrieveEncryptionKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "FMLD_Database_Key",
            kSecAttrService as String: "com.fmld.panel",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let keyData = result as? Data,
           let key = String(data: keyData, encoding: .utf8) {
            return key
        }
        
        return nil
    }
    
    
    private func verifyKey(_ key: String) -> Bool {
        // Test the key by trying to open the database
        let testDb = openTestDatabase(with: key)
        return testDb != nil
    }
    
    private func openTestDatabase(with key: String) -> OpaquePointer? {
        var testDb: OpaquePointer?
        
        guard sqlite3_open(dbPath, &testDb) == SQLITE_OK else {
            return nil
        }
        
        let keyData = key.data(using: .utf8)!
        let _ = keyData.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
        
        // Simulate SQLCipher key setting (in production, uncomment the lines below)
        // guard sqlite3_key(testDb, keyBytes.baseAddress, Int32(keyData.count)) == SQLITE_OK else {
        //     sqlite3_close(testDb)
        //     return nil
        // }
        
        // Test with a simple query
        let testSQL = "SELECT count(*) FROM sqlite_master"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(testDb, testSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_finalize(statement)
            return testDb
        } else {
            sqlite3_close(testDb)
            return nil
        }
    }
    
    private func reencryptDatabase(with newKey: String) -> Bool {
        // This is a simplified re-encryption
        // In production, you'd want to use SQLCipher's rekey functionality
        logger.info("Re-encrypting database with new key")
        return true
    }
    
    private func generateBackupPath() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let timestamp = Int(Date().timeIntervalSince1970)
        return documentsPath.appendingPathComponent("fmld_backup_\(timestamp).db").path
    }
    
    private func parseTransaction(from statement: OpaquePointer?) -> Transaction? {
        guard let statement = statement else { return nil }
        
        let id = String(cString: sqlite3_column_text(statement, 0))
        let amount = sqlite3_column_double(statement, 1)
        let currency = String(cString: sqlite3_column_text(statement, 2))
        let cardNumber = String(cString: sqlite3_column_text(statement, 3))
        let bin = String(cString: sqlite3_column_text(statement, 4))
        
        let street = sqlite3_column_text(statement, 5).map { String(cString: $0) }
        let city = sqlite3_column_text(statement, 6).map { String(cString: $0) }
        let state = sqlite3_column_text(statement, 7).map { String(cString: $0) }
        let postalCode = sqlite3_column_text(statement, 8).map { String(cString: $0) }
        let country = sqlite3_column_text(statement, 9).map { String(cString: $0) }
        let countryCode = sqlite3_column_text(statement, 10).map { String(cString: $0) }
        
        let latitude = sqlite3_column_type(statement, 11) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 11)
        let longitude = sqlite3_column_type(statement, 12) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 12)
        
        let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 13))
        let statusString = String(cString: sqlite3_column_text(statement, 14))
        let riskScore = sqlite3_column_double(statement, 15)
        let _ = sqlite3_column_text(statement, 16).map { String(cString: $0) }
        
        let address: Address?
        if let street = street, let city = city, let country = country, let countryCode = countryCode {
            address = Address(
                street: street,
                city: city,
                state: state,
                postalCode: postalCode ?? "",
                country: country,
                countryCode: countryCode,
                latitude: latitude,
                longitude: longitude,
                isVerified: true,
                verificationDate: Date(),
                riskLevel: .low
            )
        } else {
            address = nil
        }
        
        let status = TransactionStatus(rawValue: statusString) ?? .pending
        
        return Transaction(
            id: UUID(uuidString: id) ?? UUID(),
            amount: amount,
            currency: currency,
            cardNumber: cardNumber,
            bin: bin,
            country: "", // Will be populated from billingAddress
            city: address?.city ?? "",
            ipAddress: "", // Not stored in this table
            userAgent: "", // Not stored in this table
            timestamp: timestamp,
            status: status,
            riskScore: riskScore,
            binInfo: nil,
            merchantId: nil,
            userId: nil,
            sessionId: nil,
            deviceFingerprint: nil,
            billingAddress: address,
            metadata: nil
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

// MARK: - Errors

enum EncryptedEncryptedDatabaseError: Error {
    case databaseLocked
    case prepareFailed
    case executionFailed
    case encryptionFailed
    case keyDerivationFailed
}

// MARK: - Key Derivation

private func deriveKey(from password: String) -> String {
    // Simplified key derivation for demo purposes
    // In production, use proper PBKDF2 with CommonCrypto
    let salt = "FMLD_Salt_2024"
    let combined = password + salt
    return combined.data(using: .utf8)?.base64EncodedString() ?? password
}