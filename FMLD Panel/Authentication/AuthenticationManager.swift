//
//  AuthenticationManager.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation
import Security
import LocalAuthentication

// MARK: - User Roles
enum UserRole: String, CaseIterable, Codable {
    case admin = "admin"
    case analyst = "analyst"
    case viewer = "viewer"
    case support = "support"
    
    var displayName: String {
        switch self {
        case .admin:
            return "Administrator"
        case .analyst:
            return "Fraud Analyst"
        case .viewer:
            return "Viewer"
        case .support:
            return "Support"
        }
    }
    
    var permissions: [Permission] {
        switch self {
        case .admin:
            return Permission.allCases
        case .analyst:
            return [.viewTransactions, .analyzeTransactions, .updateTransactions, .viewReports, .exportData]
        case .viewer:
            return [.viewTransactions, .viewReports]
        case .support:
            return [.viewTransactions, .viewReports, .manageUsers]
        }
    }
}

enum Permission: String, CaseIterable {
    case viewTransactions = "view_transactions"
    case analyzeTransactions = "analyze_transactions"
    case updateTransactions = "update_transactions"
    case deleteTransactions = "delete_transactions"
    case viewReports = "view_reports"
    case exportData = "export_data"
    case manageUsers = "manage_users"
    case manageSettings = "manage_settings"
    case viewAuditLogs = "view_audit_logs"
    case manageRules = "manage_rules"
}

// MARK: - User Model
struct User: Codable {
    let id: UUID
    let email: String
    let name: String
    let role: UserRole
    let isActive: Bool
    let createdAt: Date
    let lastLoginAt: Date?
    var preferences: UserPreferences
    
    struct UserPreferences: Codable {
        var theme: String = "system"
        var notifications: Bool = true
        var autoRefresh: Bool = true
        var refreshInterval: Int = 30
        var defaultView: String = "transactions"
    }
}

// MARK: - Authentication Manager
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let keychain = KeychainManager()
    private let logger = Logger.shared
    
    private init() {
        checkAuthenticationStatus()
    }
    
    // MARK: - Authentication Status
    func checkAuthenticationStatus() {
        if let userData = keychain.get(key: "current_user"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    // MARK: - Login
    func login(email: String, password: String, rememberMe: Bool = false) async {
        isLoading = true
        error = nil
        
        do {
            // In production, this would make a real API call
            let user = try await authenticateUser(email: email, password: password)
            
            DispatchQueue.main.async {
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
                
                if rememberMe {
                    self.saveUserToKeychain(user)
                }
                
                self.logger.info("User \(email) logged in successfully")
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
                self.logger.error("Login failed for \(email): \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Biometric Authentication
    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to access FMLD Panel"
            )
            return result
        } catch {
            logger.error("Biometric authentication failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Logout
    func logout() {
        currentUser = nil
        isAuthenticated = false
        keychain.delete(key: "current_user")
        logger.info("User logged out")
    }
    
    // MARK: - Permission Checking
    func hasPermission(_ permission: Permission) -> Bool {
        guard let user = currentUser else { return false }
        return user.role.permissions.contains(permission)
    }
    
    func canPerformAction(_ action: String) -> Bool {
        guard let permission = Permission(rawValue: action) else { return false }
        return hasPermission(permission)
    }
    
    // MARK: - User Management
    func updateUserPreferences(_ preferences: User.UserPreferences) {
        guard var user = currentUser else { return }
        user.preferences = preferences
        currentUser = user
        saveUserToKeychain(user)
    }
    
    // MARK: - Private Methods
    private func authenticateUser(email: String, password: String) async throws -> User {
        // Simulate API call delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // In production, this would be a real API call
        // For now, we'll simulate authentication
        guard email.contains("@") && password.count >= 6 else {
            throw AuthenticationError.invalidCredentials
        }
        
        // Simulate different user roles based on email
        let role: UserRole
        if email.contains("admin") {
            role = .admin
        } else if email.contains("analyst") {
            role = .analyst
        } else if email.contains("support") {
            role = .support
        } else {
            role = .viewer
        }
        
        return User(
            id: UUID(),
            email: email,
            name: email.components(separatedBy: "@").first?.capitalized ?? "User",
            role: role,
            isActive: true,
            createdAt: Date(),
            lastLoginAt: Date(),
            preferences: User.UserPreferences()
        )
    }
    
    private func saveUserToKeychain(_ user: User) {
        if let userData = try? JSONEncoder().encode(user) {
            keychain.set(key: "current_user", data: userData)
        }
    }
}

// MARK: - Keychain Manager
class KeychainManager {
    private let service = "com.fmld.panel"
    
    func set(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            print("Failed to save to keychain: \(status)")
            return
        }
    }
    
    func get(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            return nil
        }
        
        return result as? Data
    }
    
    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Authentication Errors
enum AuthenticationError: Error, LocalizedError {
    case invalidCredentials
    case accountLocked
    case accountInactive
    case biometricNotAvailable
    case biometricFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .accountLocked:
            return "Account is locked. Please contact support."
        case .accountInactive:
            return "Account is inactive. Please contact support."
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometricFailed:
            return "Biometric authentication failed"
        }
    }
}
