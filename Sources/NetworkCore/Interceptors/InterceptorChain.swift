//
//  InterceptorChain.swift
//  NetworkCore/Interceptors
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public final class InterceptorChain: Sendable {

    private let interceptors: [any RequestInterceptorProtocol]

    public init(interceptors: [any RequestInterceptorProtocol] = []) {
        self.interceptors = interceptors
    }

    public func apply(to request: URLRequest) async throws -> URLRequest {
        var current = request
        for interceptor in interceptors {
            current = try await interceptor.intercept(current)
        }
        return current
    }

}
