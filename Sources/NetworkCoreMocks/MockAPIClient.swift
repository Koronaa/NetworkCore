//
//  MockAPIClient.swift
//  NetworkCore/NetworkCoreMocks
//
//  Created by Sajith Konara on 1/4/26.
//

import NetworkCore

//@unchecked Sendable since this is a mock
public final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    public var stubbedResult: (any Sendable)?
    public var stubbedError: Error?
    public private(set) var requestEndpoints: [any Endpoint] = []
    public private(set) var callCount = 0

    public init() {}

    public func request<T: Decodable & Sendable>(
        _ endpoint: any Endpoint
    ) async throws
        -> T
    {
        callCount += 1
        requestEndpoints.append(endpoint)
        if let error = stubbedError { throw error }
        guard let result = stubbedResult as? T else {
            throw AppError.unknown("MockAPIClient: no stub for \(T.self)")
        }
        return result
    }

}
