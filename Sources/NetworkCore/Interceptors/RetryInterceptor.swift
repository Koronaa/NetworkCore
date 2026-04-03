//
//  File.swift
//  NetworkCore/Interceptors
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public enum RetryPolicy: Sendable {

    case immediate(maxAttempts: Int)
    case exponential(maxAttempts: Int, baseDelay: TimeInterval)

    public var maxAttempts: Int {
        switch self {
        case .immediate(let max): return max
        case .exponential(let max, _): return max
        }
    }

    public func delay(forAttempt attempt: Int) -> TimeInterval {
        switch self {
        case .immediate:
            return 0
        case .exponential(_, let base):
            // 1s, 2s, 4s, 8s ...  capped at 30s
            return min(base * pow(2.0, Double(attempt - 1)), 30)
        }
    }

}

public final class RetryInterceptor: RequestInterceptorProtocol {

    private let policy: RetryPolicy

    public init(policy: RetryPolicy) {
        self.policy = policy
    }

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        // Tagging the request — actual retry loop lives in APIClient
        // so it can retry the full chain, not just this interceptor.
        var mutated = request
        mutated.setValue(
            "\(policy.maxAttempts)",
            forHTTPHeaderField: "X-Retry-Limit"
        )
        return mutated
    }

}
