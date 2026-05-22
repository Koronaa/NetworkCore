//
//  InterceptorChain.swift
//  NetworkCore/Interceptors
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public final class InterceptorChain: Sendable {

    private let requestInterceptors: [any RequestInterceptorProtocol]
    private let responseInterceptors: [any ResponseInterceptorProtocol]

    public init(
        requestInterceptors: [any RequestInterceptorProtocol] = [],
        responseInterceptors: [any ResponseInterceptorProtocol] = []
    ) {
        self.requestInterceptors = requestInterceptors
        self.responseInterceptors = responseInterceptors
    }

    public func apply(to request: URLRequest) async throws -> URLRequest {
        var current = request
        for interceptor in requestInterceptors {
            current = try await interceptor.intercept(current)
        }
        return current
    }

    public func apply(
        to response: HTTPURLResponse,
        request: URLRequest,
        data: Data,
        retryHandler: @Sendable () async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        var current = (data, response)
        for interceptor in responseInterceptors {
            current = try await interceptor.intercept(
                request: request,
                response: current.1,
                data: current.0,
                retryHandler: retryHandler
            )
        }
        return current
    }

}
