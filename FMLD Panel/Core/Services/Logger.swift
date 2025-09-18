//
//  Logger.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation
import os.log

// MARK: - Logger Service
class Logger {
    static let shared = Logger()
    
    private let systemLog = OSLog(subsystem: "com.fmld.panel", category: "general")
    private let securityLog = OSLog(subsystem: "com.fmld.panel", category: "security")
    private let performanceLog = OSLog(subsystem: "com.fmld.panel", category: "performance")
    
    private init() {}
    
    // MARK: - General Logging
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        os_log("%{public}@", log: systemLog, type: .info, logMessage)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        os_log("%{public}@", log: systemLog, type: .default, logMessage)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        os_log("%{public}@", log: systemLog, type: .error, logMessage)
    }
    
    // MARK: - Security Logging
    func security(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        os_log("%{public}@", log: securityLog, type: .error, logMessage)
    }
    
    // MARK: - Performance Logging
    func performance(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        os_log("%{public}@", log: performanceLog, type: .info, logMessage)
    }
    
    // MARK: - Transaction Logging
    func transaction(_ transaction: Transaction, action: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - Transaction \(action): ID=\(transaction.id), Amount=\(transaction.amount) \(transaction.currency), Status=\(transaction.status.rawValue), Risk=\(transaction.riskLevel.rawValue)"
        os_log("%{public}@", log: securityLog, type: .info, logMessage)
    }
    
    // MARK: - Rule Execution Logging
    func ruleExecution(_ rule: Rule, transaction: Transaction, triggered: Bool, score: Double, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - Rule '\(rule.name)' \(triggered ? "TRIGGERED" : "not triggered") for Transaction \(transaction.id), Score: \(score)"
        os_log("%{public}@", log: securityLog, type: triggered ? .error : .info, logMessage)
    }
}





