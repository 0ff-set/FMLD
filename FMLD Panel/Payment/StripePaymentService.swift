//
//  StripePaymentService.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation
import Network

// MARK: - Stripe Payment Service
class StripePaymentService: ObservableObject {
    static let shared = StripePaymentService()
    
    private let session = URLSession.shared
    private let logger = Logger.shared
    private let networkMonitor = NWPathMonitor()
    
    // Stripe API endpoints
    private let stripeAPI = "https://api.stripe.com/v1"
    private let stripePublishableKey = "pk_test_your_publishable_key" // Replace with real key
    private let stripeSecretKey = "sk_test_your_secret_key" // Replace with real key
    
    // Rate limiting
    private var lastRequestTime: Date = Date.distantPast
    private let minRequestInterval: TimeInterval = 0.5 // 500ms between requests
    
    private init() {
        startNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    func createPaymentIntent(amount: Double, currency: String = "usd") async throws -> PaymentIntent {
        guard await isNetworkAvailable() else {
            throw PaymentError.networkUnavailable
        }
        
        try await enforceRateLimit()
        
        let url = URL(string: "\(stripeAPI)/payment_intents")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(stripeSecretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("FMLD-Panel/1.0", forHTTPHeaderField: "User-Agent")
        
        // Convert amount to cents
        let amountInCents = Int(amount * 100)
        
        let body = "amount=\(amountInCents)&currency=\(currency)&automatic_payment_methods[enabled]=true"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaymentError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw PaymentError.serverError(httpResponse.statusCode)
        }
        
        let paymentIntent = try JSONDecoder().decode(StripePaymentIntent.self, from: data)
        return convertToPaymentIntent(paymentIntent)
    }
    
    func confirmPaymentIntent(_ paymentIntentId: String, paymentMethodId: String) async throws -> PaymentIntent {
        guard await isNetworkAvailable() else {
            throw PaymentError.networkUnavailable
        }
        
        try await enforceRateLimit()
        
        let url = URL(string: "\(stripeAPI)/payment_intents/\(paymentIntentId)/confirm")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(stripeSecretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("FMLD-Panel/1.0", forHTTPHeaderField: "User-Agent")
        
        let body = "payment_method=\(paymentMethodId)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaymentError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw PaymentError.serverError(httpResponse.statusCode)
        }
        
        let paymentIntent = try JSONDecoder().decode(StripePaymentIntent.self, from: data)
        return convertToPaymentIntent(paymentIntent)
    }
    
    func createCustomer(email: String, name: String) async throws -> Customer {
        guard await isNetworkAvailable() else {
            throw PaymentError.networkUnavailable
        }
        
        try await enforceRateLimit()
        
        let url = URL(string: "\(stripeAPI)/customers")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(stripeSecretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("FMLD-Panel/1.0", forHTTPHeaderField: "User-Agent")
        
        let body = "email=\(email)&name=\(name)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaymentError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw PaymentError.serverError(httpResponse.statusCode)
        }
        
        let customer = try JSONDecoder().decode(StripeCustomer.self, from: data)
        return convertToCustomer(customer)
    }
    
    func createSubscription(customerId: String, priceId: String) async throws -> Subscription {
        guard await isNetworkAvailable() else {
            throw PaymentError.networkUnavailable
        }
        
        try await enforceRateLimit()
        
        let url = URL(string: "\(stripeAPI)/subscriptions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(stripeSecretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("FMLD-Panel/1.0", forHTTPHeaderField: "User-Agent")
        
        let body = "customer=\(customerId)&items[0][price]=\(priceId)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaymentError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw PaymentError.serverError(httpResponse.statusCode)
        }
        
        let subscription = try JSONDecoder().decode(StripeSubscription.self, from: data)
        return convertToSubscription(subscription)
    }
    
    func cancelSubscription(_ subscriptionId: String) async throws -> Subscription {
        guard await isNetworkAvailable() else {
            throw PaymentError.networkUnavailable
        }
        
        try await enforceRateLimit()
        
        let url = URL(string: "\(stripeAPI)/subscriptions/\(subscriptionId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(stripeSecretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("FMLD-Panel/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaymentError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw PaymentError.serverError(httpResponse.statusCode)
        }
        
        let subscription = try JSONDecoder().decode(StripeSubscription.self, from: data)
        return convertToSubscription(subscription)
    }
    
    func getPaymentMethods(customerId: String) async throws -> [PaymentMethod] {
        guard await isNetworkAvailable() else {
            throw PaymentError.networkUnavailable
        }
        
        try await enforceRateLimit()
        
        let url = URL(string: "\(stripeAPI)/payment_methods?customer=\(customerId)&type=card")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(stripeSecretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("FMLD-Panel/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaymentError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw PaymentError.serverError(httpResponse.statusCode)
        }
        
        let paymentMethodsResponse = try JSONDecoder().decode(StripePaymentMethodsResponse.self, from: data)
        return paymentMethodsResponse.data.map { convertToPaymentMethod($0) }
    }
    
    // MARK: - Private Methods
    
    private func isNetworkAvailable() async -> Bool {
        return await withCheckedContinuation { continuation in
            networkMonitor.pathUpdateHandler = { path in
                continuation.resume(returning: path.status == .satisfied)
            }
        }
    }
    
    private func enforceRateLimit() async throws {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        
        if timeSinceLastRequest < minRequestInterval {
            let delay = minRequestInterval - timeSinceLastRequest
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        lastRequestTime = Date()
    }
    
    private func convertToPaymentIntent(_ stripeIntent: StripePaymentIntent) -> PaymentIntent {
        return PaymentIntent(
            id: stripeIntent.id,
            amount: Double(stripeIntent.amount) / 100.0, // Convert from cents
            currency: stripeIntent.currency,
            status: stripeIntent.status,
            clientSecret: stripeIntent.clientSecret,
            createdAt: Date(timeIntervalSince1970: TimeInterval(stripeIntent.created))
        )
    }
    
    private func convertToCustomer(_ stripeCustomer: StripeCustomer) -> Customer {
        return Customer(
            id: stripeCustomer.id,
            email: stripeCustomer.email ?? "",
            name: stripeCustomer.name ?? "",
            createdAt: Date(timeIntervalSince1970: TimeInterval(stripeCustomer.created))
        )
    }
    
    private func convertToSubscription(_ stripeSubscription: StripeSubscription) -> Subscription {
        return Subscription(
            id: stripeSubscription.id,
            customerId: stripeSubscription.customer,
            status: stripeSubscription.status,
            currentPeriodStart: Date(timeIntervalSince1970: TimeInterval(stripeSubscription.currentPeriodStart)),
            currentPeriodEnd: Date(timeIntervalSince1970: TimeInterval(stripeSubscription.currentPeriodEnd)),
            createdAt: Date(timeIntervalSince1970: TimeInterval(stripeSubscription.created))
        )
    }
    
    private func convertToPaymentMethod(_ stripeMethod: StripePaymentMethod) -> PaymentMethod {
        return PaymentMethod(
            id: stripeMethod.id,
            type: stripeMethod.type,
            card: stripeMethod.card.map { card in
                PaymentMethodCard(
                    brand: card.brand,
                    last4: card.last4,
                    expMonth: card.expMonth,
                    expYear: card.expYear
                )
            }
        )
    }
    
    private func startNetworkMonitoring() {
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
}

// MARK: - Data Models

struct PaymentIntent {
    let id: String
    let amount: Double
    let currency: String
    let status: String
    let clientSecret: String
    let createdAt: Date
}

struct Customer {
    let id: String
    let email: String
    let name: String
    let createdAt: Date
}

struct Subscription {
    let id: String
    let customerId: String
    let status: String
    let currentPeriodStart: Date
    let currentPeriodEnd: Date
    let createdAt: Date
}

struct PaymentMethod {
    let id: String
    let type: String
    let card: PaymentMethodCard?
}

struct PaymentMethodCard {
    let brand: String
    let last4: String
    let expMonth: Int
    let expYear: Int
}

// MARK: - Stripe API Response Models

struct StripePaymentIntent: Codable {
    let id: String
    let amount: Int
    let currency: String
    let status: String
    let clientSecret: String
    let created: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case currency
        case status
        case clientSecret = "client_secret"
        case created
    }
}

struct StripeCustomer: Codable {
    let id: String
    let email: String?
    let name: String?
    let created: Int
}

struct StripeSubscription: Codable {
    let id: String
    let customer: String
    let status: String
    let currentPeriodStart: Int
    let currentPeriodEnd: Int
    let created: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case customer
        case status
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case created
    }
}

struct StripePaymentMethodsResponse: Codable {
    let data: [StripePaymentMethod]
}

struct StripePaymentMethod: Codable {
    let id: String
    let type: String
    let card: StripeCard?
}

struct StripeCard: Codable {
    let brand: String
    let last4: String
    let expMonth: Int
    let expYear: Int
    
    enum CodingKeys: String, CodingKey {
        case brand
        case last4
        case expMonth = "exp_month"
        case expYear = "exp_year"
    }
}

// MARK: - Error Types

enum PaymentError: LocalizedError {
    case networkUnavailable
    case invalidResponse
    case serverError(Int)
    case invalidAmount
    case invalidCurrency
    case customerNotFound
    case subscriptionNotFound
    case paymentMethodNotFound
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network connection is not available."
        case .invalidResponse:
            return "Invalid response from payment service."
        case .serverError(let code):
            return "Server error: \(code)"
        case .invalidAmount:
            return "Invalid payment amount."
        case .invalidCurrency:
            return "Invalid currency code."
        case .customerNotFound:
            return "Customer not found."
        case .subscriptionNotFound:
            return "Subscription not found."
        case .paymentMethodNotFound:
            return "Payment method not found."
        }
    }
}
