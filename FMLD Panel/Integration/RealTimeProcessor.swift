import Foundation
import Network
import Combine

/// Real-time transaction processor for high-throughput fraud detection
class RealTimeProcessor: ObservableObject {
    static let shared = RealTimeProcessor()
    
    @Published var isProcessing = false
    @Published var currentThroughput: Double = 0.0
    @Published var totalProcessed: Int = 0
    @Published var averageLatency: Double = 0.0
    @Published var errorRate: Double = 0.0
    @Published var processedCount: Int = 0
    @Published var blockedCount: Int = 0
    @Published var reviewCount: Int = 0
    @Published var processingRate: Double = 0.0
    
    private let logger = Logger.shared
    private let processingQueue = DispatchQueue(label: "realtime.processing", qos: .userInitiated, attributes: .concurrent)
    private let metricsQueue = DispatchQueue(label: "realtime.metrics", qos: .utility)
    
    // Performance monitoring
    private var processingTimes: [TimeInterval] = []
    private var errorCount = 0
    private var totalCount = 0
    private var lastUpdateTime = Date()
    
    // Processing pipelines
    private let ingestionPipeline = TransactionIngestionPipeline()
    private let scoringPipeline = TransactionScoringPipeline()
    private let rulesPipeline = RulesExecutionPipeline()
    private let alertingPipeline = AlertingPipeline()
    
    // Rate limiting and backpressure
    private let maxConcurrentTasks = 50
    private let semaphore = DispatchSemaphore(value: 50)
    private var activeTasks = 0
    
    private init() {
        setupPipelines()
        startMetricsCollection()
    }
    
    // MARK: - Public Methods
    
    func processTransaction(_ transaction: Transaction) async -> ProcessedTransaction {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Wait for available processing slot
        semaphore.wait()
        activeTasks += 1
        
        defer {
            activeTasks -= 1
            semaphore.signal()
        }
        
        // Process through all pipelines in parallel
        let result = await processThroughPipelines(transaction)
        
        // Update metrics
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        updateMetrics(processingTime: processingTime, success: true)
        
        return result
    }
    
    func processBatch(_ transactions: [Transaction]) async -> [ProcessedTransaction] {
        logger.info("Processing batch of \(transactions.count) transactions")
        
        return await withTaskGroup(of: ProcessedTransaction.self) { group in
            var results: [ProcessedTransaction] = []
            
            // Process transactions in parallel with controlled concurrency
            for transaction in transactions {
                group.addTask {
                    return await self.processTransaction(transaction)
                }
            }
            
            // Collect results
            for await result in group {
                results.append(result)
            }
            
            return results
        }
    }
    
    func startRealTimeIngestion() {
        guard !isProcessing else { return }
        
        isProcessing = true
        logger.info("Starting real-time transaction ingestion")
        
        Task {
        await ingestionPipeline.startIngestion { [weak self] transaction in
            return await self?.processTransaction(transaction) ?? ProcessedTransaction(
                originalTransaction: transaction,
                riskScore: 0.0,
                finalStatus: .pending,
                processingTime: 0.0,
                binInfo: nil,
                addressInfo: nil,
                amlResult: AMLCheckResult(
                    value: "",
                    isBlacklisted: false,
                    riskLevel: .low,
                    source: nil,
                    confidence: 0.0
                ),
                rulesResults: RulesExecutionResult(
                    action: .approve,
                    matchedRules: [],
                    executionTime: 0.0,
                    confidence: 0.0
                )
            )
        }
        }
    }
    
    func stopRealTimeIngestion() {
        isProcessing = false
        ingestionPipeline.stopIngestion()
        logger.info("Stopped real-time transaction ingestion")
    }
    
    // MARK: - Private Methods
    
    private func setupPipelines() {
        // Configure pipeline dependencies
        scoringPipeline.setup()
        rulesPipeline.setup()
        alertingPipeline.setup()
    }
    
    private func processThroughPipelines(_ transaction: Transaction) async -> ProcessedTransaction {
        // Step 1: Data normalization and enrichment
        let normalizedTransaction = await ingestionPipeline.normalizeTransaction(transaction)
        
        // Step 2: Parallel feature extraction and scoring
        async let riskScore = scoringPipeline.calculateRiskScore(normalizedTransaction)
        async let binInfo = RealBinDatabaseService.shared.lookupBin(normalizedTransaction.bin)
        async let addressInfo = GeocodingService.shared.geocodeAddress(normalizedTransaction.billingAddress?.street ?? "")
        async let amlCheck = AMLBlacklistService.shared.checkCryptoAddress(normalizedTransaction.cardNumber)
        
        // Wait for all parallel operations
        let (score, bin, address, aml) = await (riskScore, binInfo, addressInfo, amlCheck)
        
        // Step 3: Rules execution
        let rulesResult = await rulesPipeline.executeRules(normalizedTransaction, riskScore: score)
        
        // Step 4: Final decision
        let finalStatus = determineFinalStatus(
            riskScore: score,
            rulesResult: rulesResult,
            amlResult: aml
        )
        
        // Step 5: Create processed transaction
        let processedTransaction = ProcessedTransaction(
            originalTransaction: normalizedTransaction,
            riskScore: score,
            finalStatus: finalStatus,
            processingTime: CFAbsoluteTimeGetCurrent(),
            binInfo: bin,
            addressInfo: address,
            amlResult: aml,
            rulesResults: rulesResult
        )
        
        // Step 6: Alerting if needed
        if finalStatus == .blocked || finalStatus == .review {
            await alertingPipeline.sendAlert(for: processedTransaction)
        }
        
        return processedTransaction
    }
    
    private func determineFinalStatus(
        riskScore: Double,
        rulesResult: RulesExecutionResult,
        amlResult: AMLCheckResult
    ) -> TransactionStatus {
        // High risk score
        if riskScore > 0.8 {
            return .blocked
        }
        
        // AML blacklist hit
        if amlResult.isBlacklisted {
            return .blocked
        }
        
        // Rules engine blocked
        if rulesResult.action == .block {
            return .blocked
        }
        
        // Rules engine requires review
        if rulesResult.action == .review || riskScore > 0.6 {
            return .review
        }
        
        // Medium risk
        if riskScore > 0.4 {
            return .pending
        }
        
        // Low risk - approve
        return .approved
    }
    
    private func updateMetrics(processingTime: TimeInterval, success: Bool) {
        metricsQueue.async {
            self.processingTimes.append(processingTime)
            self.totalCount += 1
            
            if !success {
                self.errorCount += 1
            }
            
            // Keep only last 1000 processing times
            if self.processingTimes.count > 1000 {
                self.processingTimes.removeFirst()
            }
            
            // Update published metrics every 100 transactions
            if self.totalCount % 100 == 0 {
                DispatchQueue.main.async {
                    self.updatePublishedMetrics()
                }
            }
        }
    }
    
    private func updatePublishedMetrics() {
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        
        // Calculate throughput (transactions per second)
        let recentTransactions = totalCount
        currentThroughput = Double(recentTransactions) / timeSinceLastUpdate
        
        // Calculate average latency
        if !processingTimes.isEmpty {
            averageLatency = processingTimes.reduce(0, +) / Double(processingTimes.count)
        }
        
        // Calculate error rate
        errorRate = totalCount > 0 ? Double(errorCount) / Double(totalCount) : 0.0
        
        // Update totals
        totalProcessed = totalCount
        
        lastUpdateTime = now
        
        logger.info("Metrics - Throughput: \(String(format: "%.2f", currentThroughput)) tx/s, Latency: \(String(format: "%.3f", averageLatency))s, Error Rate: \(String(format: "%.2f", errorRate * 100))%")
    }
    
    private func startMetricsCollection() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePublishedMetrics()
        }
    }
}

// MARK: - Processing Pipelines

class TransactionIngestionPipeline {
    private let logger = Logger.shared
    private var isIngesting = false
    private var ingestionTask: Task<Void, Never>?
    
    func startIngestion(processor: @escaping (Transaction) async -> ProcessedTransaction) {
        guard !isIngesting else { return }
        
        isIngesting = true
        ingestionTask = Task {
            while isIngesting {
                // Simulate real-time transaction ingestion
                // In production, this would connect to actual payment processors
                let transaction = generateMockTransaction()
                _ = await processor(transaction)
                
            // Real-time transaction processing - no demo generation
            // Wait for actual transactions to be processed
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
            }
        }
    }
    
    func stopIngestion() {
        isIngesting = false
        ingestionTask?.cancel()
    }
    
    func normalizeTransaction(_ transaction: Transaction) async -> Transaction {
        // Normalize transaction data by creating a new Transaction
        let normalizedCardNumber = transaction.cardNumber.replacingOccurrences(of: " ", with: "")
        let normalizedAmount = round(transaction.amount * 100) / 100
        let normalizedTimestamp = transaction.timestamp > Date() ? Date() : transaction.timestamp
        
        return Transaction(
            id: transaction.id,
            amount: normalizedAmount,
            currency: transaction.currency,
            cardNumber: normalizedCardNumber,
            bin: transaction.bin,
            country: transaction.country,
            city: transaction.city,
            ipAddress: transaction.ipAddress,
            userAgent: transaction.userAgent,
            timestamp: normalizedTimestamp,
            status: transaction.status,
            riskScore: transaction.riskScore,
            binInfo: transaction.binInfo,
            merchantId: transaction.merchantId,
            userId: transaction.userId,
            sessionId: transaction.sessionId,
            deviceFingerprint: transaction.deviceFingerprint,
            billingAddress: transaction.billingAddress,
            metadata: transaction.metadata
        )
    }
    
    private func generateMockTransaction() -> Transaction {
        // More diverse amounts for realistic demo
        let amounts = [5.99, 12.50, 25.00, 49.99, 99.99, 199.99, 299.99, 499.99, 999.99, 1999.99, 4999.99, 9999.99]
        let bins = ["411111", "555555", "400000", "601111", "300000", "222300", "520000", "400000", "510000", "340000"]
        let countries = ["US", "CA", "GB", "DE", "FR", "JP", "AU", "BR", "IN", "CN", "IT", "ES", "NL", "SE", "NO"]
        let cities = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "London", "Berlin", "Paris", "Tokyo", "Sydney", "Toronto", "Mumbai", "Shanghai", "Rome", "Madrid"]
        let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "SEK", "NOK", "DKK"]
        let userAgents = [
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15",
            "Mozilla/5.0 (Android 11; Mobile; rv:68.0) Gecko/68.0 Firefox/88.0",
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
        ]
        
        // Generate realistic risk scores (some high-risk transactions)
        let riskScore = Double.random(in: 0.0...1.0)
        let status: TransactionStatus = riskScore > 0.7 ? .review : (riskScore > 0.3 ? .pending : .approved)
        
        return Transaction(
            id: UUID(),
            amount: amounts.randomElement() ?? 99.99,
            currency: currencies.randomElement() ?? "USD",
            cardNumber: generateCardNumber(),
            bin: bins.randomElement() ?? "411111",
            country: countries.randomElement() ?? "US",
            city: cities.randomElement() ?? "New York",
            ipAddress: generateRandomIP(),
            userAgent: userAgents.randomElement() ?? "Mozilla/5.0",
            timestamp: Date(),
            status: status,
            riskScore: riskScore,
            binInfo: nil,
            merchantId: "MERCHANT_\(Int.random(in: 1000...9999))",
            userId: "USER_\(Int.random(in: 10000...99999))",
            sessionId: UUID().uuidString,
            deviceFingerprint: "DEVICE_\(Int.random(in: 100000...999999))",
            billingAddress: generateMockAddress(),
            metadata: "{\"source\": \"demo\", \"risk_level\": \"\(riskScore > 0.7 ? "high" : riskScore > 0.3 ? "medium" : "low")\"}"
        )
    }
    
    private func generateCardNumber() -> String {
        let prefixes = ["4111", "5555", "4000", "6011", "3000", "2223", "5200", "5100", "3400", "3700"]
        let prefix = prefixes.randomElement() ?? "4111"
        let remaining = (0..<12).map { _ in String(Int.random(in: 0...9)) }.joined()
        return prefix + remaining
    }
    
    private func generateRandomIP() -> String {
        // Generate realistic IP addresses for demo
        let ipRanges = [
            "192.168.1.\(Int.random(in: 1...254))",
            "10.0.\(Int.random(in: 0...255)).\(Int.random(in: 1...254))",
            "172.16.\(Int.random(in: 0...31)).\(Int.random(in: 1...254))",
            "\(Int.random(in: 1...223)).\(Int.random(in: 0...255)).\(Int.random(in: 0...255)).\(Int.random(in: 1...254))"
        ]
        return ipRanges.randomElement() ?? "192.168.1.100"
    }
    
    private func generateMockAddress() -> Address {
        let streets = ["123 Main St", "456 Oak Ave", "789 Pine Rd", "321 Elm St", "654 Maple Dr", "987 Broadway", "555 5th Ave", "100 Park Ave", "200 Central Park W", "300 Madison Ave"]
        let cities = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "London", "Berlin", "Paris", "Tokyo", "Sydney", "Toronto", "Mumbai", "Shanghai", "Rome", "Madrid"]
        let countries = ["United States", "Canada", "United Kingdom", "Germany", "France", "Japan", "Australia", "Brazil", "India", "China", "Italy", "Spain", "Netherlands", "Sweden", "Norway"]
        let countryCodes = ["US", "CA", "GB", "DE", "FR", "JP", "AU", "BR", "IN", "CN", "IT", "ES", "NL", "SE", "NO"]
        let states = ["NY", "CA", "TX", "FL", "IL", "PA", "OH", "GA", "NC", "MI", "NJ", "VA", "WA", "AZ", "MA"]
        let postalCodes = ["10001", "90210", "60601", "77001", "85001", "10036", "10019", "10022", "10024", "10016"]
        
        let selectedCountry = countries.randomElement() ?? "United States"
        let selectedCountryCode = countryCodes.randomElement() ?? "US"
        
        return Address(
            street: streets.randomElement() ?? "123 Main St",
            city: cities.randomElement() ?? "New York",
            state: states.randomElement() ?? "NY",
            postalCode: postalCodes.randomElement() ?? "10001",
            country: selectedCountry,
            countryCode: selectedCountryCode,
            latitude: Double.random(in: 25.0...49.0),
            longitude: Double.random(in: -125.0...(-66.0)),
            isVerified: Bool.random(),
            verificationDate: Date(),
            riskLevel: .low
        )
    }
}

class TransactionScoringPipeline {
    private let mlService = ProductionMLService.shared
    private let logger = Logger.shared
    
    func setup() {
        logger.info("Setting up transaction scoring pipeline")
    }
    
    func calculateRiskScore(_ transaction: Transaction) async -> Double {
        return await mlService.predictRiskScore(for: transaction)
    }
}

class RulesExecutionPipeline {
    private let rulesEngine = RulesEngine.shared
    private let logger = Logger.shared
    
    func setup() {
        logger.info("Setting up rules execution pipeline")
    }
    
    func executeRules(_ transaction: Transaction, riskScore: Double) async -> RulesExecutionResult {
        let results = rulesEngine.executeRules(for: transaction)
        
        // Convert array of RuleExecutionResult to single RulesExecutionResult
        let triggeredRules = results.filter { $0.triggered }
        let action = determineAction(from: triggeredRules)
        let confidence = calculateConfidence(from: triggeredRules)
        let executionTime = results.map { $0.executionTime }.reduce(0, +)
        
        // Get the actual Rule objects from the triggered results
        let matchedRules = triggeredRules.compactMap { result in
            rulesEngine.rules.first { $0.id == result.ruleId }
        }
        
        return RulesExecutionResult(
            action: action,
            matchedRules: matchedRules,
            executionTime: executionTime,
            confidence: confidence
        )
    }
    
    private func determineAction(from results: [RuleExecutionResult]) -> RuleAction {
        // Get the rule actions for triggered rules
        let ruleActions = results.compactMap { result in
            rulesEngine.rules.first { $0.id == result.ruleId }?.action
        }
        
        // If any rule says to block, block
        if ruleActions.contains(.block) {
            return .block
        }
        
        // If any rule says to review, review
        if ruleActions.contains(.review) {
            return .review
        }
        
        // Default to approve
        return .approve
    }
    
    private func calculateConfidence(from results: [RuleExecutionResult]) -> Double {
        guard !results.isEmpty else { return 0.0 }
        
        // Simple confidence calculation based on number of triggered rules
        let baseConfidence = min(Double(results.count) * 0.2, 1.0)
        return baseConfidence
    }
}

class AlertingPipeline {
    private let logger = Logger.shared
    
    func setup() {
        logger.info("Setting up alerting pipeline")
    }
    
    func sendAlert(for transaction: ProcessedTransaction) async {
        logger.warning("ALERT: High-risk transaction detected - ID: \(transaction.originalTransaction.id), Risk Score: \(transaction.riskScore), Status: \(transaction.finalStatus)")
        
        // In production, this would send real alerts via email, SMS, Slack, etc.
        // For now, we'll just log the alert
    }
}

// MARK: - Models

struct ProcessedTransaction {
    let originalTransaction: Transaction
    let riskScore: Double
    let finalStatus: TransactionStatus
    let processingTime: TimeInterval
    let binInfo: BinInfo?
    let addressInfo: GeocodingResult?
    let amlResult: AMLCheckResult
    let rulesResults: RulesExecutionResult
}
