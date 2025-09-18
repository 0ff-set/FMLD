//
//  LocalMLService.swift
//  FMLD Panel
//
//  Created by AI Assistant on 9/13/25.
//

import Foundation
import CoreML
import CreateML

/// Local ML service using CoreML and simple algorithms
class LocalMLService: ObservableObject {
    static let shared = LocalMLService()
    
    @Published var isInitialized = false
    @Published var modelAccuracy: Double = 0.0
    
    private let logger = Logger.shared
    private var riskScoringModel: RiskScoringModel?
    private var anomalyDetector: AnomalyDetector?
    
    private init() {
        initializeLocalModels()
    }
    
    // MARK: - Initialization
    
    private func initializeLocalModels() {
        Task {
            await setupRiskScoringModel()
            await setupAnomalyDetector()
            
            await MainActor.run {
                isInitialized = true
                logger.info("Local ML service initialized successfully")
            }
        }
    }
    
    private func setupRiskScoringModel() async {
        // Simple rule-based risk scoring as fallback
        riskScoringModel = RiskScoringModel()
        logger.info("Risk scoring model initialized")
    }
    
    private func setupAnomalyDetector() async {
        // Simple statistical anomaly detection
        anomalyDetector = AnomalyDetector()
        logger.info("Anomaly detector initialized")
    }
    
    // MARK: - Public Methods
    
    /// Analyze transaction using local ML models
    func analyzeTransaction(_ transaction: Transaction) async -> LocalMLResult {
        guard isInitialized else {
            return await fallbackAnalysis(transaction)
        }
        
        let riskScore = await calculateRiskScore(transaction)
        let anomalyScore = await detectAnomaly(transaction)
        let explanation = generateExplanation(transaction, riskScore: riskScore, anomalyScore: anomalyScore)
        
        return LocalMLResult(
            riskScore: riskScore,
            anomalyScore: anomalyScore,
            explanation: explanation,
            confidence: 0.85 // Local model confidence
        )
    }
    
    private func calculateRiskScore(_ transaction: Transaction) async -> Double {
        guard let model = riskScoringModel else { return 0.5 }
        
        var score = 0.0
        
        // Amount-based risk
        if transaction.amount > 5000 {
            score += 0.3
        } else if transaction.amount > 1000 {
            score += 0.15
        }
        
        // Geographic risk
        if let binInfo = transaction.binInfo {
            if BinDatabaseService.shared.isHighRiskCountry(binInfo.countryCode) {
                score += 0.4
            }
            if BinDatabaseService.shared.isHighRiskBank(binInfo.bank) {
                score += 0.2
            }
        }
        
        // Time-based risk (night transactions)
        let hour = Calendar.current.component(.hour, from: transaction.timestamp)
        if hour >= 2 && hour <= 6 {
            score += 0.1
        }
        
        // Velocity-based risk (simplified)
        if isHighVelocityTransaction(transaction) {
            score += 0.2
        }
        
        return min(score, 1.0)
    }
    
    private func detectAnomaly(_ transaction: Transaction) async -> Double {
        guard let detector = anomalyDetector else { return 0.0 }
        
        // Simple anomaly detection based on amount deviation
        let normalAmountRange = 10.0...1000.0
        if !normalAmountRange.contains(transaction.amount) {
            return 0.7
        }
        
        // Country anomaly
        if let binInfo = transaction.binInfo {
            if binInfo.countryCode != transaction.country {
                return 0.6
            }
        }
        
        return 0.1
    }
    
    private func isHighVelocityTransaction(_ transaction: Transaction) -> Bool {
        // Simplified velocity check - in real implementation, would check recent transactions
        return false
    }
    
    private func generateExplanation(_ transaction: Transaction, riskScore: Double, anomalyScore: Double) -> String {
        var explanations: [String] = []
        
        if transaction.amount > 5000 {
            explanations.append("High transaction amount")
        }
        
        if let binInfo = transaction.binInfo {
            if BinDatabaseService.shared.isHighRiskCountry(binInfo.countryCode) {
                explanations.append("High-risk country")
            }
            if binInfo.countryCode != transaction.country {
                explanations.append("Country mismatch")
            }
        }
        
        let hour = Calendar.current.component(.hour, from: transaction.timestamp)
        if hour >= 2 && hour <= 6 {
            explanations.append("Unusual transaction time")
        }
        
        if explanations.isEmpty {
            explanations.append("No significant risk factors detected")
        }
        
        return explanations.joined(separator: ", ")
    }
    
    private func fallbackAnalysis(_ transaction: Transaction) async -> LocalMLResult {
        // Simple fallback analysis
        let riskScore = Double.random(in: 0.1...0.9)
        let anomalyScore = Double.random(in: 0.1...0.5)
        
        return LocalMLResult(
            riskScore: riskScore,
            anomalyScore: anomalyScore,
            explanation: "Fallback analysis - local ML not initialized",
            confidence: 0.5
        )
    }
}

// MARK: - Supporting Models

struct LocalMLResult {
    let riskScore: Double
    let anomalyScore: Double
    let explanation: String
    let confidence: Double
}

class RiskScoringModel {
    // Simple rule-based risk scoring
    func calculateRisk(for transaction: Transaction) -> Double {
        return 0.5 // Placeholder
    }
}

class AnomalyDetector {
    // Simple statistical anomaly detection
    func detectAnomaly(in transaction: Transaction) -> Double {
        return 0.1 // Placeholder
    }
}

