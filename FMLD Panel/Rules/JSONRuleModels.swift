//
//  JSONRuleModels.swift
//  FMLD Panel
//
//  Created by AI Assistant on 9/13/25.
//

import Foundation

// MARK: - JSON Rule Configuration Models

struct RulesConfig: Codable {
    let rules: [JSONRule]
    let globalSettings: GlobalSettings
    let riskThresholds: RiskThresholds
    let actionDefinitions: [String: ActionDefinition]
    
    enum CodingKeys: String, CodingKey {
        case rules
        case globalSettings = "global_settings"
        case riskThresholds = "risk_thresholds"
        case actionDefinitions = "action_definitions"
    }
}

struct JSONRule: Codable {
    let id: String
    let name: String
    let description: String
    let category: String
    let priority: Int
    let isActive: Bool
    let conditions: [JSONRuleCondition]
    let action: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, category, priority, action
        case isActive = "isActive"
        case conditions
    }
}

struct JSONRuleCondition: Codable {
    let field: String
    let `operator`: String
    let value: String
    let dataType: String
    
    enum CodingKeys: String, CodingKey {
        case field, value
        case `operator`
        case dataType = "dataType"
    }
}

struct GlobalSettings: Codable {
    let enableRuleEngine: Bool
    let defaultAction: String
    let maxConcurrentRules: Int
    let ruleTimeoutSeconds: Int
    let enableRuleLogging: Bool
    let enableRuleAnalytics: Bool
    
    enum CodingKeys: String, CodingKey {
        case enableRuleEngine = "enable_rule_engine"
        case defaultAction = "default_action"
        case maxConcurrentRules = "max_concurrent_rules"
        case ruleTimeoutSeconds = "rule_timeout_seconds"
        case enableRuleLogging = "enable_rule_logging"
        case enableRuleAnalytics = "enable_rule_analytics"
    }
}

struct RiskThresholds: Codable {
    let lowRisk: Double
    let mediumRisk: Double
    let highRisk: Double
    let criticalRisk: Double
    
    enum CodingKeys: String, CodingKey {
        case lowRisk = "low_risk"
        case mediumRisk = "medium_risk"
        case highRisk = "high_risk"
        case criticalRisk = "critical_risk"
    }
}

struct ActionDefinition: Codable {
    let description: String
    let priority: Int
}

