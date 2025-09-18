//
//  CasinoAIService.swift
//  FMLD Panel
//
//  Created by AI Assistant on 9/13/25.
//

import Foundation
import CoreML
import NaturalLanguage
import Network

/// Enhanced AI service specifically designed for casino operations
class CasinoAIService: ObservableObject {
    static let shared = CasinoAIService()
    
    @Published var isActive = false
    @Published var realTimeAlerts: [CasinoAlert] = []
    @Published var playerProfiles: [String: PlayerProfile] = [:]
    @Published var complianceStatus: ComplianceStatus = .compliant
    
    private let logger = Logger.shared
    private let networkMonitor = NWPathMonitor()
    private var isOnline = false
    
    // Real-time monitoring
    private var transactionStream: AsyncStream<Transaction>?
    private var monitoringTask: Task<Void, Never>?
    
    // AI Models
    private var fraudDetector: MLModel?
    private var playerBehaviorAnalyzer: MLModel?
    private var complianceChecker: MLModel?
    private var riskScorer: MLModel?
    
    // Real-time data
    private var recentTransactions: [Transaction] = []
    private var playerSessions: [String: PlayerSession] = [:]
    private var suspiciousPatterns: [SuspiciousPattern] = []
    
    // Casino-specific thresholds
    private let maxTransactionAmount: Double = 100000
    private let maxHourlyTransactions = 50
    private let maxDailyAmount: Double = 500000
    private let suspiciousVelocityThreshold = 10 // transactions per minute
    
    private init() {
        setupNetworkMonitoring()
        initializeCasinoAI()
        startRealTimeMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
        monitoringTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Analyze transaction in real-time for casino operations
    func analyzeCasinoTransaction(_ transaction: Transaction) async -> CasinoAnalysisResult {
        let startTime = Date()
        
        // Real-time risk assessment
        let riskScore = await calculateRealTimeRiskScore(transaction)
        
        // Player behavior analysis
        let playerAnalysis = await analyzePlayerBehavior(transaction)
        
        // Compliance checking
        let complianceCheck = await checkCompliance(transaction)
        
        // Fraud detection
        let fraudAssessment = await detectFraud(transaction)
        
        // Generate real-time alert if needed
        if riskScore > 0.7 || fraudAssessment.isFraudulent {
            await generateRealTimeAlert(transaction, riskScore: riskScore, fraudAssessment: fraudAssessment)
        }
        
        // Update player profile
        await updatePlayerProfile(transaction, analysis: playerAnalysis)
        
        // Generate AI explanation
        let explanation = await generateCasinoAIExplanation(
            transaction: transaction,
            riskScore: riskScore,
            playerAnalysis: playerAnalysis,
            complianceCheck: complianceCheck,
            fraudAssessment: fraudAssessment
        )
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return CasinoAnalysisResult(
            transactionId: transaction.id.uuidString,
            riskScore: riskScore,
            fraudProbability: fraudAssessment.probability,
            playerRiskLevel: playerAnalysis.riskLevel,
            complianceStatus: complianceCheck.status,
            recommendation: generateCasinoRecommendation(riskScore: riskScore, fraudAssessment: fraudAssessment),
            explanation: explanation,
            processingTime: processingTime,
            alerts: realTimeAlerts.filter { $0.transactionId == transaction.id.uuidString },
            playerInsights: playerAnalysis.insights,
            complianceNotes: complianceCheck.notes
        )
    }
    
    /// Get real-time casino insights
    func getRealTimeCasinoInsights() async -> [CasinoInsight] {
        var insights: [CasinoInsight] = []
        
        // High-value transaction insights
        let highValueTransactions = recentTransactions.filter { $0.amount > 10000 }
        if !highValueTransactions.isEmpty {
            insights.append(CasinoInsight(
                type: "high_value",
                severity: "medium",
                title: "High-Value Transactions Detected",
                description: "\(highValueTransactions.count) transactions exceeding $10,000 in the last hour",
                recommendation: "Review high-value transactions for potential money laundering",
                confidence: 0.8
            ))
        }
        
        // Velocity-based insights
        let velocityInsight = await detectVelocityPatterns()
        if let insight = velocityInsight {
            insights.append(insight)
        }
        
        // Player behavior insights
        let behaviorInsight = await detectUnusualPlayerBehavior()
        if let insight = behaviorInsight {
            insights.append(insight)
        }
        
        // Compliance insights
        let complianceInsight = await detectComplianceIssues()
        if let insight = complianceInsight {
            insights.append(insight)
        }
        
        return insights
    }
    
    /// Start real-time monitoring
    func startRealTimeMonitoring() {
        guard monitoringTask == nil else { return }
        
        monitoringTask = Task {
            while !Task.isCancelled {
                await processRealTimeData()
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
        
        isActive = true
        logger.info("Real-time casino monitoring started")
    }
    
    /// Stop real-time monitoring
    func stopRealTimeMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        isActive = false
        logger.info("Real-time casino monitoring stopped")
    }
    
    // MARK: - Private Methods
    
    private func initializeCasinoAI() {
        Task {
            await loadCasinoModels()
            await setupRealTimeStreams()
            
            await MainActor.run {
                self.isActive = true
                self.logger.info("Casino AI service initialized")
            }
        }
    }
    
    private func calculateRealTimeRiskScore(_ transaction: Transaction) async -> Double {
        var riskScore = 0.0
        
        // Amount-based risk
        if transaction.amount > maxTransactionAmount {
            riskScore += 0.4
        } else if transaction.amount > maxTransactionAmount * 0.5 {
            riskScore += 0.2
        }
        
        // Velocity-based risk
        let recentCount = recentTransactions.filter { 
            $0.timestamp > Date().addingTimeInterval(-3600) // Last hour
        }.count
        
        if recentCount > maxHourlyTransactions {
            riskScore += 0.3
        }
        
        // Player-based risk (using session ID as player identifier)
        let playerId = transaction.sessionId ?? "anonymous"
        let playerRisk = await getPlayerRiskLevel(playerId)
        riskScore += playerRisk * 0.3
        
        // Time-based risk
        let hour = Calendar.current.component(.hour, from: transaction.timestamp)
        if hour < 6 || hour > 23 {
            riskScore += 0.1
        }
        
        // Location-based risk
        if transaction.country != "US" {
            riskScore += 0.2
        }
        
        return min(riskScore, 1.0)
    }
    
    private func analyzePlayerBehavior(_ transaction: Transaction) async -> PlayerBehaviorAnalysis {
        let playerId = transaction.sessionId ?? "anonymous"
        
        if playerId == "anonymous" {
            return PlayerBehaviorAnalysis(
                riskLevel: "unknown",
                insights: ["No session ID provided"],
                sessionDuration: 0,
                transactionCount: 0,
                averageAmount: 0,
                behaviorPattern: "unknown"
            )
        }
        
        var session = playerSessions[playerId] ?? PlayerSession(playerId: playerId)
        session.addTransaction(transaction)
        playerSessions[playerId] = session
        
        var riskLevel = "low"
        var insights: [String] = []
        
        // Analyze spending patterns
        if session.totalAmount > maxDailyAmount {
            riskLevel = "high"
            insights.append("Player exceeded daily spending limit")
        } else if session.totalAmount > maxDailyAmount * 0.5 {
            riskLevel = "medium"
            insights.append("Player approaching daily spending limit")
        }
        
        // Analyze transaction frequency
        if session.transactionCount > maxHourlyTransactions {
            riskLevel = "high"
            insights.append("Unusually high transaction frequency detected")
        }
        
        // Analyze session duration
        if session.duration > 3600 { // 1 hour
            insights.append("Long gaming session detected")
        }
        
        return PlayerBehaviorAnalysis(
            riskLevel: riskLevel,
            insights: insights,
            sessionDuration: session.duration,
            transactionCount: session.transactionCount,
            averageAmount: session.averageAmount,
            behaviorPattern: session.behaviorPattern
        )
    }
    
    private func checkCompliance(_ transaction: Transaction) async -> ComplianceCheck {
        var status = ComplianceStatus.compliant
        var notes: [String] = []
        
        // Check transaction limits
        if transaction.amount > maxTransactionAmount {
            status = .nonCompliant
            notes.append("Transaction exceeds maximum allowed amount")
        }
        
        // Check daily limits
        let dailyAmount = recentTransactions
            .filter { Calendar.current.isDate($0.timestamp, inSameDayAs: Date()) }
            .reduce(0) { $0 + $1.amount }
        
        if dailyAmount > maxDailyAmount {
            status = .nonCompliant
            notes.append("Daily transaction limit exceeded")
        }
        
        // Check geographic restrictions
        if transaction.country == "AF" || transaction.country == "IR" || transaction.country == "KP" {
            status = .nonCompliant
            notes.append("Transaction from restricted country")
        }
        
        // Check time restrictions
        let hour = Calendar.current.component(.hour, from: transaction.timestamp)
        if hour < 6 || hour > 23 {
            notes.append("Transaction outside normal operating hours")
        }
        
        return ComplianceCheck(status: status, notes: notes)
    }
    
    private func detectFraud(_ transaction: Transaction) async -> FraudAssessment {
        var isFraudulent = false
        var probability = 0.0
        var indicators: [String] = []
        
        // Check for duplicate transactions
        let duplicates = recentTransactions.filter { 
            $0.amount == transaction.amount && 
            $0.bin == transaction.bin &&
            abs($0.timestamp.timeIntervalSince(transaction.timestamp)) < 60 // Within 1 minute
        }
        
        if duplicates.count > 0 {
            isFraudulent = true
            probability = 0.8
            indicators.append("Duplicate transaction detected")
        }
        
        // Check for velocity fraud
        let recentCount = recentTransactions.filter { 
            $0.timestamp > Date().addingTimeInterval(-60) // Last minute
        }.count
        
        if recentCount > suspiciousVelocityThreshold {
            isFraudulent = true
            probability = max(probability, 0.7)
            indicators.append("Suspicious transaction velocity")
        }
        
        // Check for amount fraud
        if transaction.amount > maxTransactionAmount {
            probability = max(probability, 0.6)
            indicators.append("Transaction amount exceeds normal limits")
        }
        
        return FraudAssessment(
            isFraudulent: isFraudulent,
            probability: probability,
            indicators: indicators
        )
    }
    
    private func generateRealTimeAlert(_ transaction: Transaction, riskScore: Double, fraudAssessment: FraudAssessment) async {
        let alert = CasinoAlert(
            id: UUID().uuidString,
            transactionId: transaction.id.uuidString,
            type: fraudAssessment.isFraudulent ? .fraud : .risk,
            severity: riskScore > 0.8 ? .critical : .high,
            title: fraudAssessment.isFraudulent ? "Fraud Detected" : "High Risk Transaction",
            description: generateAlertDescription(transaction, riskScore: riskScore, fraudAssessment: fraudAssessment),
            timestamp: Date(),
            actionRequired: true
        )
        
        await MainActor.run {
            self.realTimeAlerts.append(alert)
            // Keep only last 100 alerts
            if self.realTimeAlerts.count > 100 {
                self.realTimeAlerts.removeFirst()
            }
        }
        
        // Log critical alerts
        if alert.severity == .critical {
            logger.error("CRITICAL ALERT: \(alert.title) - Transaction ID: \(transaction.id.uuidString)")
        }
    }
    
    private func generateAlertDescription(_ transaction: Transaction, riskScore: Double, fraudAssessment: FraudAssessment) -> String {
        var description = "Transaction ID: \(transaction.id.uuidString)\n"
        description += "Amount: $\(String(format: "%.2f", transaction.amount))\n"
        description += "Risk Score: \(String(format: "%.2f", riskScore))\n"
        description += "Fraud Probability: \(String(format: "%.2f", fraudAssessment.probability))\n"
        
        if !fraudAssessment.indicators.isEmpty {
            description += "Fraud Indicators: \(fraudAssessment.indicators.joined(separator: ", "))\n"
        }
        
        return description
    }
    
    private func updatePlayerProfile(_ transaction: Transaction, analysis: PlayerBehaviorAnalysis) async {
        let playerId = transaction.sessionId ?? "anonymous"
        
        var profile = playerProfiles[playerId] ?? PlayerProfile(playerId: playerId)
        profile.updateWithTransaction(transaction, analysis: analysis)
        playerProfiles[playerId] = profile
    }
    
    private func generateCasinoAIExplanation(
        transaction: Transaction,
        riskScore: Double,
        playerAnalysis: PlayerBehaviorAnalysis,
        complianceCheck: ComplianceCheck,
        fraudAssessment: FraudAssessment
    ) -> String {
        var explanation = "🎰 Casino AI Analysis:\n\n"
        
        explanation += "Risk Assessment: \(riskScore > 0.7 ? "HIGH" : riskScore > 0.4 ? "MEDIUM" : "LOW") (Score: \(String(format: "%.2f", riskScore)))\n\n"
        
        explanation += "Player Behavior: \(playerAnalysis.riskLevel.uppercased()) risk level\n"
        explanation += "Session Duration: \(String(format: "%.1f", playerAnalysis.sessionDuration / 60)) minutes\n"
        explanation += "Transaction Count: \(playerAnalysis.transactionCount)\n"
        explanation += "Average Amount: $\(String(format: "%.2f", playerAnalysis.averageAmount))\n\n"
        
        explanation += "Compliance Status: \(complianceCheck.status.rawValue.uppercased())\n"
        if !complianceCheck.notes.isEmpty {
            explanation += "Compliance Notes: \(complianceCheck.notes.joined(separator: ", "))\n\n"
        }
        
        explanation += "Fraud Assessment: \(fraudAssessment.isFraudulent ? "FRAUDULENT" : "LEGITIMATE")\n"
        explanation += "Fraud Probability: \(String(format: "%.2f", fraudAssessment.probability))\n"
        if !fraudAssessment.indicators.isEmpty {
            explanation += "Fraud Indicators: \(fraudAssessment.indicators.joined(separator: ", "))\n"
        }
        
        return explanation
    }
    
    private func generateCasinoRecommendation(riskScore: Double, fraudAssessment: FraudAssessment) -> String {
        if fraudAssessment.isFraudulent {
            return "BLOCK - Fraudulent transaction detected, immediate blocking required"
        } else if riskScore > 0.8 {
            return "BLOCK - High risk transaction, manual review required"
        } else if riskScore > 0.6 {
            return "REVIEW - Moderate risk transaction, requires manual review"
        } else if riskScore > 0.4 {
            return "MONITOR - Low risk transaction, approve with monitoring"
        } else {
            return "APPROVE - Low risk transaction, safe to approve"
        }
    }
    
    private func getPlayerRiskLevel(_ playerId: String) async -> Double {
        guard let profile = playerProfiles[playerId] else { return 0.5 }
        
        var riskLevel = 0.0
        
        // High spending risk
        if profile.totalSpent > maxDailyAmount {
            riskLevel += 0.4
        }
        
        // High frequency risk
        if profile.transactionCount > maxHourlyTransactions {
            riskLevel += 0.3
        }
        
        // Long session risk
        if profile.averageSessionDuration > 3600 {
            riskLevel += 0.2
        }
        
        // Previous alerts risk
        let playerAlerts = realTimeAlerts.filter { $0.transactionId.contains(playerId) }
        if playerAlerts.count > 5 {
            riskLevel += 0.3
        }
        
        return min(riskLevel, 1.0)
    }
    
    private func detectVelocityPatterns() async -> CasinoInsight? {
        let recentTransactions = recentTransactions.filter { 
            $0.timestamp > Date().addingTimeInterval(-3600) // Last hour
        }
        
        if recentTransactions.count > maxHourlyTransactions {
            return CasinoInsight(
                type: "velocity",
                severity: "high",
                title: "High Transaction Velocity",
                description: "\(recentTransactions.count) transactions in the last hour, exceeding normal limits",
                recommendation: "Implement velocity-based fraud detection rules",
                confidence: 0.9
            )
        }
        
        return nil
    }
    
    private func detectUnusualPlayerBehavior() async -> CasinoInsight? {
        for (playerId, profile) in playerProfiles {
            if profile.totalSpent > maxDailyAmount {
                return CasinoInsight(
                    type: "player_behavior",
                    severity: "high",
                    title: "Unusual Player Spending",
                    description: "Player \(playerId) has spent $\(String(format: "%.2f", profile.totalSpent)) today",
                    recommendation: "Review player spending patterns and implement limits",
                    confidence: 0.8
                )
            }
        }
        
        return nil
    }
    
    private func detectComplianceIssues() async -> CasinoInsight? {
        let nonCompliantTransactions = recentTransactions.filter { transaction in
            transaction.amount > maxTransactionAmount || 
            transaction.country == "AF" || 
            transaction.country == "IR" || 
            transaction.country == "KP"
        }
        
        if !nonCompliantTransactions.isEmpty {
            return CasinoInsight(
                type: "compliance",
                severity: "critical",
                title: "Compliance Issues Detected",
                description: "\(nonCompliantTransactions.count) transactions violate compliance rules",
                recommendation: "Immediate compliance review required",
                confidence: 1.0
            )
        }
        
        return nil
    }
    
    private func processRealTimeData() async {
        // Process recent transactions
        let cutoffTime = Date().addingTimeInterval(-3600) // 1 hour ago
        recentTransactions = recentTransactions.filter { $0.timestamp > cutoffTime }
        
        // Update player sessions
        for (playerId, session) in playerSessions {
            if session.lastActivity < cutoffTime {
                playerSessions.removeValue(forKey: playerId)
            }
        }
        
        // Update compliance status
        await updateComplianceStatus()
    }
    
    private func updateComplianceStatus() async {
        let nonCompliantCount = recentTransactions.filter { transaction in
            transaction.amount > maxTransactionAmount || 
            transaction.country == "AF" || 
            transaction.country == "IR" || 
            transaction.country == "KP"
        }.count
        
        await MainActor.run {
            if nonCompliantCount > 0 {
                self.complianceStatus = .nonCompliant
            } else {
                self.complianceStatus = .compliant
            }
        }
    }
    
    private func loadCasinoModels() async {
        // Load casino-specific ML models
        logger.info("Loading casino AI models...")
        // Implementation would load actual models
    }
    
    private func setupRealTimeStreams() async {
        // Setup real-time data streams
        logger.info("Setting up real-time data streams...")
        // Implementation would setup actual streams
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
            }
        }
        let queue = DispatchQueue(label: "CasinoAIService")
        networkMonitor.start(queue: queue)
    }
}

// MARK: - Supporting Types

struct CasinoAnalysisResult {
    let transactionId: String
    let riskScore: Double
    let fraudProbability: Double
    let playerRiskLevel: String
    let complianceStatus: ComplianceStatus
    let recommendation: String
    let explanation: String
    let processingTime: TimeInterval
    let alerts: [CasinoAlert]
    let playerInsights: [String]
    let complianceNotes: [String]
}

struct PlayerBehaviorAnalysis {
    let riskLevel: String
    let insights: [String]
    let sessionDuration: TimeInterval
    let transactionCount: Int
    let averageAmount: Double
    let behaviorPattern: String
}

struct ComplianceCheck {
    let status: ComplianceStatus
    let notes: [String]
}

struct FraudAssessment {
    let isFraudulent: Bool
    let probability: Double
    let indicators: [String]
}

struct CasinoAlert {
    let id: String
    let transactionId: String
    let type: AlertType
    let severity: CasinoAlertSeverity
    let title: String
    let description: String
    let timestamp: Date
    let actionRequired: Bool
}

struct CasinoInsight {
    let type: String
    let severity: String
    let title: String
    let description: String
    let recommendation: String
    let confidence: Double
}

struct PlayerProfile {
    let playerId: String
    var totalSpent: Double = 0
    var transactionCount: Int = 0
    var averageSessionDuration: TimeInterval = 0
    var lastActivity: Date = Date()
    var riskLevel: String = "low"
    
    mutating func updateWithTransaction(_ transaction: Transaction, analysis: PlayerBehaviorAnalysis) {
        totalSpent += transaction.amount
        transactionCount += 1
        averageSessionDuration = analysis.sessionDuration
        lastActivity = Date()
        riskLevel = analysis.riskLevel
    }
}

struct PlayerSession {
    let playerId: String
    var transactions: [Transaction] = []
    var startTime: Date = Date()
    var lastActivity: Date = Date()
    
    var duration: TimeInterval {
        lastActivity.timeIntervalSince(startTime)
    }
    
    var transactionCount: Int {
        transactions.count
    }
    
    var totalAmount: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }
    
    var averageAmount: Double {
        guard !transactions.isEmpty else { return 0 }
        return totalAmount / Double(transactions.count)
    }
    
    var behaviorPattern: String {
        if transactionCount > 20 {
            return "high_frequency"
        } else if totalAmount > 10000 {
            return "high_value"
        } else if duration > 3600 {
            return "long_session"
        } else {
            return "normal"
        }
    }
    
    mutating func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
        lastActivity = Date()
    }
}

enum ComplianceStatus: String {
    case compliant = "compliant"
    case nonCompliant = "non_compliant"
    case warning = "warning"
}

enum AlertType {
    case fraud
    case risk
    case compliance
    case player
}

enum CasinoAlertSeverity: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

struct SuspiciousPattern {
    let id: String
    let type: String
    let description: String
    let severity: String
    let timestamp: Date
}
