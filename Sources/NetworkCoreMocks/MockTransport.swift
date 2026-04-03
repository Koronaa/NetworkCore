//
//  MockTransport.swift
//  NetworkCore/NetworkCoreMocks
//
//  Created by Sajith Konara on 1/4/26.
//

import Foundation
import NetworkCore

public final class MockTransport: TransportProtocol, @unchecked Sendable {

    public var stubbedData: Data?
    public var stubbedResponse: HTTPURLResponse?
    public var stubbedError: Error?
    public private(set) var sentRequests: [URLRequest] = []

    public init() {}

    public func send(_ request: URLRequest) async throws -> (
        Data, HTTPURLResponse
    ) {
        sentRequests.append(request)
        if let error = stubbedError { throw error }
        return (
            stubbedData ?? Data(),
            stubbedResponse ?? HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }

}
