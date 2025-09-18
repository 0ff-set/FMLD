//
//  Transaction.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation

// MARK: - Transaction Model
struct Transaction: Identifiable, Codable, Hashable {
    let id: UUID
    let amount: Double
    let currency: String
    let cardNumber: String
    let bin: String
    let country: String
    let city: String
    let ipAddress: String
    let userAgent: String
    let timestamp: Date
    var status: TransactionStatus
    var riskScore: Double
    var binInfo: BinInfo?
    let merchantId: String?
    let userId: String?
    let sessionId: String?
    let deviceFingerprint: String?
    let billingAddress: Address?
    let metadata: String?
    
    var maskedCardNumber: String {
        guard cardNumber.count >= 4 else { return cardNumber }
        return "************" + String(cardNumber.suffix(4))
    }
    
    var riskLevel: RiskLevel {
        if riskScore > 0.7 {
            return .high
        } else if riskScore > 0.4 {
            return .medium
        } else {
            return .low
        }
    }
    
    init(id: UUID = UUID(), 
         amount: Double, 
         currency: String, 
         cardNumber: String, 
         bin: String, 
         country: String, 
         city: String, 
         ipAddress: String, 
         userAgent: String, 
         timestamp: Date = Date(), 
         status: TransactionStatus = .pending, 
         riskScore: Double = 0.0, 
         binInfo: BinInfo? = nil,
         merchantId: String? = nil,
         userId: String? = nil,
         sessionId: String? = nil,
         deviceFingerprint: String? = nil,
         billingAddress: Address? = nil,
         metadata: String? = nil) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.cardNumber = cardNumber
        self.bin = bin
        self.country = country
        self.city = city
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.timestamp = timestamp
        self.status = status
        self.riskScore = riskScore
        self.binInfo = binInfo
        self.merchantId = merchantId
        self.userId = userId
        self.sessionId = sessionId
        self.deviceFingerprint = deviceFingerprint
        self.billingAddress = billingAddress
        self.metadata = metadata
    }
}

// MARK: - Transaction Status
enum TransactionStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case approved = "Approved"
    case review = "Review"
    case blocked = "Blocked"
    case cancelled = "Cancelled"
}

// MARK: - Risk Level
enum RiskLevel: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}