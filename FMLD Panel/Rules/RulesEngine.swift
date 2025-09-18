//
//  RulesEngine.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation

// MARK: - Rules Execution Result

struct RulesExecutionResult {
    let action: RuleAction
    let matchedRules: [Rule]
    let executionTime: TimeInterval
    let confidence: Double
}

// MARK: - Rules Engine
class RulesEngine: ObservableObject {
    static let shared = RulesEngine()
    
    private let logger = Logger.shared
    private let databaseManager = DatabaseManager.shared
    
    @Published var rules: [Rule] = []
    @Published var isProcessing = false
    
    private init() {
        loadRules()
        createDefaultRules()
    }
    
    // MARK: - Add Rule
    func addRule(_ rule: Rule) {
        do {
            try databaseManager.saveRule(rule)
            rules.append(rule)
            logger.info("Added new rule: \(rule.name)")
        } catch {
            logger.error("Failed to add rule: \(error.localizedDescription)")
        }
    }
    
    func deleteRule(_ rule: Rule) {
        do {
            try databaseManager.deleteRule(rule.id)
            rules.removeAll { $0.id == rule.id }
            logger.info("Deleted rule: \(rule.name)")
        } catch {
            logger.error("Failed to delete rule: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update Rule
    func updateRule(_ rule: Rule) {
        do {
            try databaseManager.saveRule(rule)
            if let index = rules.firstIndex(where: { $0.id == rule.id }) {
                rules[index] = rule
            }
            logger.info("Updated rule: \(rule.name)")
        } catch {
            logger.error("Failed to update rule: \(error.localizedDescription)")
        }
    }
    
    
    // MARK: - Load Rules
    private func loadRules() {
        // First try to load from JSON config
        if loadRulesFromJSON() {
            logger.info("Loaded \(rules.count) rules from JSON config")
            return
        }
        
        // Fallback to database
        do {
            rules = try databaseManager.fetchRules()
            logger.info("Loaded \(rules.count) rules from database")
        } catch {
            logger.error("Failed to load rules: \(error.localizedDescription)")
            createDefaultRules()
        }
    }
    
    private func loadRulesFromJSON() -> Bool {
        guard let jsonPath = Bundle.main.path(forResource: "rules_config", ofType: "json"),
              let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
              let config = try? JSONDecoder().decode(RulesConfig.self, from: jsonData) else {
            logger.warning("Could not load rules from JSON, using fallback")
            return false
        }
        
        rules = config.rules.map { jsonRule in
            Rule(
                id: UUID(uuidString: jsonRule.id) ?? UUID(),
                name: jsonRule.name,
                description: jsonRule.description,
                category: RuleCategory(rawValue: jsonRule.category) ?? .velocity,
                priority: jsonRule.priority,
                isActive: jsonRule.isActive,
                conditions: jsonRule.conditions.map { jsonCondition in
                    RuleCondition(
                        field: jsonCondition.field,
                        operator: RuleOperator(rawValue: jsonCondition.operator) ?? .equals,
                        value: jsonCondition.value,
                        dataType: RuleDataType(rawValue: jsonCondition.dataType) ?? .string
                    )
                },
                action: RuleAction(rawValue: jsonRule.action) ?? .approve
            )
        }
        
        return true
    }
    
    // MARK: - Create Default Rules
    private func createDefaultRules() {
        if rules.isEmpty {
            let defaultRules = [
                createVelocityRule(),
                createHighAmountRule(),
                createGeographicRule(),
                createBinMismatchRule(),
                createNightTimeRule()
            ]
            
            for rule in defaultRules {
                do {
                    try databaseManager.saveRule(rule)
                    rules.append(rule)
                } catch {
                    logger.error("Failed to save default rule: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Execute Rules
    func executeRules(for transaction: Transaction) -> [RuleExecutionResult] {
        isProcessing = true
        var results: [RuleExecutionResult] = []
        
        let activeRules = rules.filter { $0.isActive }
        
        for rule in activeRules {
            let startTime = Date()
            let result = executeRule(rule, for: transaction)
            let executionTime = Date().timeIntervalSince(startTime)
            
            var finalResult = result
            finalResult.executionTime = executionTime
            
            results.append(finalResult)
            
            logger.ruleExecution(rule, transaction: transaction, triggered: result.triggered, score: result.score)
        }
        
        isProcessing = false
        return results
    }
    
    // MARK: - Execute Single Rule
    private func executeRule(_ rule: Rule, for transaction: Transaction) -> RuleExecutionResult {
        var triggered = false
        var score = 0.0
        var reason = ""
        
        for condition in rule.conditions {
            let conditionResult = evaluateCondition(condition, for: transaction)
            if conditionResult.triggered {
                triggered = true
                score += conditionResult.score
                reason += conditionResult.reason + "; "
            }
        }
        
        return RuleExecutionResult(
            ruleId: rule.id,
            transactionId: transaction.id,
            triggered: triggered,
            score: score,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
    
    // MARK: - Evaluate Condition
    private func evaluateCondition(_ condition: RuleCondition, for transaction: Transaction) -> (triggered: Bool, score: Double, reason: String) {
        let fieldValue = getFieldValue(condition.field, from: transaction)
        let conditionValue = condition.value
        
        let triggered = evaluateOperator(fieldValue, condition.`operator`, conditionValue, condition.dataType)
        let score = triggered ? 1.0 : 0.0
        let reason = triggered ? "\(condition.field) \(condition.`operator`.rawValue) \(conditionValue)" : ""
        
        return (triggered, score, reason)
    }
    
    // MARK: - Get Field Value
    private func getFieldValue(_ field: String, from transaction: Transaction) -> String {
        switch field {
        case "amount":
            return String(transaction.amount)
        case "currency":
            return transaction.currency
        case "country":
            return transaction.country
        case "city":
            return transaction.city
        case "bin":
            return transaction.bin
        case "ipAddress":
            return transaction.ipAddress
        case "userAgent":
            return transaction.userAgent
        case "riskScore":
            return String(transaction.riskScore)
        default:
            return ""
        }
    }
    
    // MARK: - Evaluate Operator
    private func evaluateOperator(_ fieldValue: String, _ operator: RuleOperator, _ conditionValue: String, _ dataType: RuleDataType) -> Bool {
        switch dataType {
        case .string:
            return evaluateStringOperator(fieldValue, `operator`, conditionValue)
        case .number:
            return evaluateNumberOperator(fieldValue, `operator`, conditionValue)
        case .date:
            return evaluateDateOperator(fieldValue, `operator`, conditionValue)
        case .boolean:
            return evaluateBooleanOperator(fieldValue, `operator`, conditionValue)
        }
    }
    
    // MARK: - String Operator Evaluation
    private func evaluateStringOperator(_ fieldValue: String, _ operator: RuleOperator, _ conditionValue: String) -> Bool {
        switch `operator` {
        case .equals:
            return fieldValue == conditionValue
        case .notEquals:
            return fieldValue != conditionValue
        case .contains:
            return fieldValue.localizedCaseInsensitiveContains(conditionValue)
        case .notContains:
            return !fieldValue.localizedCaseInsensitiveContains(conditionValue)
        case .regex:
            return fieldValue.range(of: conditionValue, options: .regularExpression) != nil
        default:
            return false
        }
    }
    
    // MARK: - Number Operator Evaluation
    private func evaluateNumberOperator(_ fieldValue: String, _ operator: RuleOperator, _ conditionValue: String) -> Bool {
        guard let fieldNum = Double(fieldValue), let conditionNum = Double(conditionValue) else { return false }
        
        switch `operator` {
        case .equals:
            return fieldNum == conditionNum
        case .notEquals:
            return fieldNum != conditionNum
        case .greaterThan:
            return fieldNum > conditionNum
        case .lessThan:
            return fieldNum < conditionNum
        case .greaterThanOrEqual:
            return fieldNum >= conditionNum
        case .lessThanOrEqual:
            return fieldNum <= conditionNum
        default:
            return false
        }
    }
    
    // MARK: - Date Operator Evaluation
    private func evaluateDateOperator(_ fieldValue: String, _ operator: RuleOperator, _ conditionValue: String) -> Bool {
        // Implementation for date comparison
        return false
    }
    
    // MARK: - Boolean Operator Evaluation
    private func evaluateBooleanOperator(_ fieldValue: String, _ operator: RuleOperator, _ conditionValue: String) -> Bool {
        let fieldBool = fieldValue.lowercased() == "true"
        let conditionBool = conditionValue.lowercased() == "true"
        
        switch `operator` {
        case .equals:
            return fieldBool == conditionBool
        case .notEquals:
            return fieldBool != conditionBool
        default:
            return false
        }
    }
    
    // MARK: - Default Rules Creation
    private func createVelocityRule() -> Rule {
        return Rule(
            name: "High Velocity",
            description: "Multiple transactions in short time period",
            category: .velocity,
            priority: 100,
            conditions: [
                RuleCondition(field: "amount", operator: .greaterThan, value: "500", dataType: .number)
            ],
            action: .review
        )
    }
    
    private func createHighAmountRule() -> Rule {
        return Rule(
            name: "High Amount",
            description: "Transaction amount exceeds threshold",
            category: .amount,
            priority: 90,
            conditions: [
                RuleCondition(field: "amount", operator: .greaterThan, value: "5000", dataType: .number)
            ],
            action: .review
        )
    }
    
    private func createGeographicRule() -> Rule {
        return Rule(
            name: "High Risk Country",
            description: "Transaction from high-risk country",
            category: .geographic,
            priority: 80,
            conditions: [
                RuleCondition(field: "country", operator: .inList, value: "CN,RU,KP,IR,SY", dataType: .string)
            ],
            action: .block
        )
    }
    
    private func createBinMismatchRule() -> Rule {
        return Rule(
            name: "BIN Country Mismatch",
            description: "BIN country doesn't match transaction country",
            category: .bin,
            priority: 70,
            conditions: [
                RuleCondition(field: "bin", operator: .notEquals, value: "country", dataType: .string)
            ],
            action: .review
        )
    }
    
    private func createNightTimeRule() -> Rule {
        return Rule(
            name: "Night Time Transaction",
            description: "Transaction during suspicious hours",
            category: .behavioral,
            priority: 60,
            conditions: [
                RuleCondition(field: "timestamp", operator: .greaterThan, value: "02:00", dataType: .date),
                RuleCondition(field: "timestamp", operator: .lessThan, value: "06:00", dataType: .date)
            ],
            action: .flag
        )
    }
}
