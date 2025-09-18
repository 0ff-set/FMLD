//
//  Card.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation

// MARK: - Card Model
struct Card: Identifiable, Codable, Hashable {
    let id: UUID
    let cardNumber: String
    let bin: String
    let lastFour: String
    let expiryMonth: Int
    let expiryYear: Int
    let cardholderName: String?
    let isActive: Bool
    let createdAt: Date
    let lastUsedAt: Date?
    let binInfo: BinInfo?
    let riskProfile: CardRiskProfile
    
    var maskedNumber: String {
        guard cardNumber.count >= 4 else { return cardNumber }
        return "************" + lastFour
    }
    
    var isExpired: Bool {
        let currentDate = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: currentDate)
        let currentMonth = calendar.component(.month, from: currentDate)
        
        if expiryYear < currentYear {
            return true
        } else if expiryYear == currentYear && expiryMonth < currentMonth {
            return true
        }
        return false
    }
    
    init(id: UUID = UUID(),
         cardNumber: String,
         bin: String,
         lastFour: String,
         expiryMonth: Int,
         expiryYear: Int,
         cardholderName: String? = nil,
         isActive: Bool = true,
         createdAt: Date = Date(),
         lastUsedAt: Date? = nil,
         binInfo: BinInfo? = nil,
         riskProfile: CardRiskProfile = CardRiskProfile()) {
        self.id = id
        self.cardNumber = cardNumber
        self.bin = bin
        self.lastFour = lastFour
        self.expiryMonth = expiryMonth
        self.expiryYear = expiryYear
        self.cardholderName = cardholderName
        self.isActive = isActive
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.binInfo = binInfo
        self.riskProfile = riskProfile
    }
}

// MARK: - Card Risk Profile
struct CardRiskProfile: Codable, Hashable {
    let velocityScore: Double
    let geographicScore: Double
    let behavioralScore: Double
    let deviceScore: Double
    let overallScore: Double
    let flags: [String]
    let lastUpdated: Date
    
    init(velocityScore: Double = 0.0,
         geographicScore: Double = 0.0,
         behavioralScore: Double = 0.0,
         deviceScore: Double = 0.0,
         overallScore: Double = 0.0,
         flags: [String] = [],
         lastUpdated: Date = Date()) {
        self.velocityScore = velocityScore
        self.geographicScore = geographicScore
        self.behavioralScore = behavioralScore
        self.deviceScore = deviceScore
        self.overallScore = overallScore
        self.flags = flags
        self.lastUpdated = lastUpdated
    }
}