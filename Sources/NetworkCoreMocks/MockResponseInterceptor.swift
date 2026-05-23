//
//  MockResponseInterceptor.swift
//  NetworkCore/NetworkCoreMocks
//
//  Created by Sajith Konara on 22/5/26.
//

import Foundation
import NetworkCore

public final class MockResponseInterceptor: ResponseInterceptorProtocol,
    @unchecked Sendable
{

    public struct Call {
        public let request: URLRequest
        public let response: HTTPURLResponse
        public let data: Data
    }

    public private(set) var calls: [Call] = []
    public private(set) var retryCount = 0

    public var stubbedData: Data?
    public var shouldRetry = false
    public var stubbedError: Error?

    public init() {}

    public func intercept(
        request: URLRequest,
        response: HTTPURLResponse,
        data: Data,
        retryHandler: @Sendable () async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {

        calls.append(Call(request: request, response: response, data: data))
        if let error = stubbedError { throw error }

        if shouldRetry {
            retryCount += 1
            return try await retryHandler()
        }

        if let overridden = stubbedData {
            return (overridden, response)
        }

        return (data, response)
    }

}
