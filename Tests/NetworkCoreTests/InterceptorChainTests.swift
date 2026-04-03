//
//  InterceptorChainTests.swift
//  NetworkCore/NetworkCoreTests
//
//  Created by Sajith Konara on 2/4/26.
//

import NetworkCoreMocks
import XCTest

@testable import NetworkCore

final class InterceptorChainTests: XCTestCase {

    func test_emptyChain_returnsRequestUnchanged() async throws {
        let chain = InterceptorChain()
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let result = try await chain.apply(to: request)
        XCTAssertEqual(result.url, result.url)
    }

    func test_interceptorsAppliedInOrder() async throws {
        var order: [Int] = []

        let first = OrderedMockInterceptor(tag: 1) { order.append(1) }
        let second = OrderedMockInterceptor(tag: 2) { order.append(2) }
        let third = OrderedMockInterceptor(tag: 3) { order.append(3) }

        let chain = InterceptorChain(interceptors: [first, second, third])
        let request = URLRequest(url: URL(string: "https://example.com")!)
        _ = try await chain.apply(to: request)

        XCTAssertEqual(order, [1, 2, 3])
    }

}

private final class OrderedMockInterceptor: RequestInterceptorProtocol,
    @unchecked Sendable
{

    let tag: Int
    let action: () -> Void

    init(tag: Int, action: @escaping () -> Void) {
        self.tag = tag
        self.action = action
    }

    func intercept(_ request: URLRequest) async throws -> URLRequest {
        action()
        return request
    }

}
