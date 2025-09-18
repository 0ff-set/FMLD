//
//  Rule.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation

// MARK: - Rule Model
struct Rule: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let category: RuleCategory
    let priority: Int
    var isActive: Bool
    let conditions: [RuleCondition]
    let action: RuleAction
    let createdAt: Date
    let updatedAt: Date
    let createdBy: String
    
    init(id: UUID = UUID(), 
         name: String, 
         description: String, 
         category: RuleCategory, 
         priority: Int = 100, 
         isActive: Bool = true, 
         conditions: [RuleCondition], 
         action: RuleAction, 
         createdAt: Date = Date(), 
         updatedAt: Date = Date(), 
         createdBy: String = "System") {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.priority = priority
        self.isActive = isActive
        self.conditions = conditions
        self.action = action
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
    }
}

// MARK: - Rule Category
enum RuleCategory: String, Codable, CaseIterable {
    case amount = "Amount"
    case velocity = "Velocity"
    case geographic = "Geographic"
    case bin = "BIN"
    case behavioral = "Behavioral"
    case time = "Time"
    case custom = "Custom"
}

// MARK: - Rule Action
enum RuleAction: String, Codable, CaseIterable {
    case approve = "Approve"
    case review = "Review"
    case block = "Block"
    case flag = "Flag"
    case log = "Log"
}

// MARK: - Rule Condition
struct RuleCondition: Codable, Hashable {
    let field: String
    let `operator`: RuleOperator
    let value: String
    let dataType: RuleDataType
    
    init(field: String, operator: RuleOperator, value: String, dataType: RuleDataType) {
        self.field = field
        self.operator = `operator`
        self.value = value
        self.dataType = dataType
    }
}

// MARK: - Rule Operator
enum RuleOperator: String, Codable, CaseIterable {
    case equals = "equals"
    case notEquals = "not_equals"
    case greaterThan = "greater_than"
    case lessThan = "less_than"
    case greaterThanOrEqual = "greater_than_or_equal"
    case lessThanOrEqual = "less_than_or_equal"
    case contains = "contains"
    case notContains = "not_contains"
    case inList = "in_list"
    case notInList = "not_in_list"
    case regex = "regex"
    case isEmpty = "is_empty"
    case isNotEmpty = "is_not_empty"
}

// MARK: - Rule Data Type
enum RuleDataType: String, Codable, CaseIterable {
    case string = "string"
    case number = "number"
    case date = "date"
    case boolean = "boolean"
}

// MARK: - Rule Execution Result
struct RuleExecutionResult: Codable, Hashable {
    let ruleId: UUID
    let transactionId: UUID
    let triggered: Bool
    let score: Double
    let reason: String
    var executionTime: TimeInterval = 0.0
    
    init(ruleId: UUID, transactionId: UUID, triggered: Bool, score: Double, reason: String, executionTime: TimeInterval = 0.0) {
        self.ruleId = ruleId
        self.transactionId = transactionId
        self.triggered = triggered
        self.score = score
        self.reason = reason
        self.executionTime = executionTime
    }
}