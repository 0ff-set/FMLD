//
//  Embedding.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation

// MARK: - Embedding Model
struct Embedding: Identifiable, Codable, Hashable {
    let id: UUID
    let transactionId: UUID
    let vector: [Double]
    let modelVersion: String
    let createdAt: Date
    let features: [String: Double]
    
    init(id: UUID = UUID(),
         transactionId: UUID,
         vector: [Double],
         modelVersion: String = "1.0",
         createdAt: Date = Date(),
         features: [String: Double] = [:]) {
        self.id = id
        self.transactionId = transactionId
        self.vector = vector
        self.modelVersion = modelVersion
        self.createdAt = createdAt
        self.features = features
    }
}

// MARK: - Similar Transaction
struct SimilarTransaction: Identifiable, Codable, Hashable {
    let id: UUID
    let transactionId: UUID
    let similarity: Double
    let distance: Double
    let reason: String
    
    init(id: UUID = UUID(),
         transactionId: UUID,
         similarity: Double,
         distance: Double,
         reason: String) {
        self.id = id
        self.transactionId = transactionId
        self.similarity = similarity
        self.distance = distance
        self.reason = reason
    }
}