//
//  RiskScorer.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation

// MARK: - Risk Scorer
class RiskScorer: ObservableObject {
    static let shared = RiskScorer()
    
    private let logger = Logger.shared
    
    private init() {
        logger.info("Risk scorer initialized")
    }
    
    // MARK: - Calculate Risk Score
    func calculateRiskScore(for transaction: Transaction) -> Double {
        var riskScore: Double = 0.0
        
        // Amount-based risk
        riskScore += calculateAmountRisk(transaction.amount, currency: transaction.currency)
        
        // Geographic risk
        riskScore += calculateGeographicRisk(country: transaction.country, city: transaction.city)
        
        // BIN risk
        if let binInfo = transaction.binInfo {
            riskScore += calculateBinRisk(binInfo)
        }
        
        // Time-based risk
        riskScore += calculateTimeRisk(timestamp: transaction.timestamp)
        
        // Normalize to 0-1 range
        return min(max(riskScore, 0.0), 1.0)
    }
    
    // MARK: - Amount Risk
    private func calculateAmountRisk(_ amount: Double, currency: String) -> Double {
        let threshold: Double = 1000.0
        if amount > threshold * 10 {
            return 0.4
        } else if amount > threshold * 5 {
            return 0.3
        } else if amount > threshold {
            return 0.2
        } else if amount > threshold / 2 {
            return 0.1
        }
        return 0.0
    }
    
    // MARK: - Geographic Risk
    private func calculateGeographicRisk(country: String, city: String) -> Double {
        let highRiskCountries = ["CN", "RU", "KP", "IR", "SY"]
        if highRiskCountries.contains(country) {
            return 0.3
        }
        
        let mediumRiskCountries = ["BR", "IN", "NG", "PK", "BD"]
        if mediumRiskCountries.contains(country) {
            return 0.15
        }
        
        return 0.0
    }
    
    // MARK: - BIN Risk
    private func calculateBinRisk(_ binInfo: BinInfo) -> Double {
        let highRiskBanks = ["Unknown Bank", "Offshore Bank"]
        if highRiskBanks.contains(binInfo.bank) {
            return 0.2
        }
        
        if binInfo.level == "Premium" || binInfo.level == "Platinum" {
            return 0.1
        }
        
        return 0.0
    }
    
    // MARK: - Time Risk
    private func calculateTimeRisk(timestamp: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: timestamp)
        let weekday = calendar.component(.weekday, from: timestamp)
        
        if hour >= 2 && hour <= 6 {
            return 0.1
        }
        
        if weekday == 1 || weekday == 7 {
            return 0.05
        }
        
        return 0.0
    }
}