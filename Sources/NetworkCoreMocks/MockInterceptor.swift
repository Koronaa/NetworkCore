//
//  MockInterceptor.swift
//  NetworkCore/NetworkCoreMocks
//
//  Created by Sajith Konara on 1/4/26.
//

import Foundation
import NetworkCore

public final class MockInterceptor: RequestInterceptorProtocol,
    @unchecked Sendable
{

    public private(set) var interceptedRequests: [URLRequest] = []
    public var modifier: ((URLRequest) -> URLRequest)?

    public init() {}

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        interceptedRequests.append(request)
        return modifier?(request) ?? request
    }

}
