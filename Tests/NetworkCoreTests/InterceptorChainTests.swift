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

    // MARK: - Request chain

    func test_emptyChain_returnsRequestUnchanged() async throws {
        let chain = InterceptorChain()
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let result = try await chain.apply(to: request)
        XCTAssertEqual(result.url, request.url)  // compare against original
    }

    func test_requestInterceptors_appliedInOrder() async throws {
        var order: [Int] = []

        let first = OrderedMockInterceptor(tag: 1) { order.append(1) }
        let second = OrderedMockInterceptor(tag: 2) { order.append(2) }
        let third = OrderedMockInterceptor(tag: 3) { order.append(3) }

        let chain = InterceptorChain(requestInterceptors: [
            first, second, third,
        ])
        let request = URLRequest(url: URL(string: "https://example.com")!)
        _ = try await chain.apply(to: request)

        XCTAssertEqual(order, [1, 2, 3])
    }

    func test_requestInterceptor_canMutateHeader() async throws {
        let interceptor = MockRequestInterceptor()
        interceptor.modifier = { request in
            var r = request
            r.setValue("test-value", forHTTPHeaderField: "X-Custom")
            return r
        }

        let chain = InterceptorChain(requestInterceptors: [interceptor])
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let result = try await chain.apply(to: request)

        XCTAssertEqual(
            result.value(forHTTPHeaderField: "X-Custom"),
            "test-value"
        )
    }

    func test_requestInterceptor_whenThrows_propagatesError() async throws {
        let interceptor = MockRequestInterceptor()
        interceptor.stubbedError = AppError.unauthorized

        let chain = InterceptorChain(requestInterceptors: [interceptor])
        let request = URLRequest(url: URL(string: "https://example.com")!)

        do {
            _ = try await chain.apply(to: request)
            XCTFail("Expected error to be thrown")
        } catch AppError.unauthorized {
            // ✅
        }
    }

    // MARK: - Response chain

    func test_emptyResponseChain_returnsDataUnchanged() async throws {
        let chain = InterceptorChain()
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let data = Data("hello".utf8)
        let response = makeResponse(statusCode: 200)

        let (resultData, resultResponse) = try await chain.apply(
            to: response,
            request: request,
            data: data,
            retryHandler: { (data, response) }
        )

        XCTAssertEqual(resultData, data)
        XCTAssertEqual(resultResponse.statusCode, 200)
    }

    func test_responseInterceptors_appliedInOrder() async throws {
        var order: [Int] = []

        let first = OrderedMockResponseInterceptor(tag: 1) { order.append(1) }
        let second = OrderedMockResponseInterceptor(tag: 2) { order.append(2) }

        let chain = InterceptorChain(responseInterceptors: [first, second])
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let response = makeResponse(statusCode: 200)

        _ = try await chain.apply(
            to: response,
            request: request,
            data: Data(),
            retryHandler: { (Data(), response) }
        )

        XCTAssertEqual(order, [1, 2])
    }

    func test_responseInterceptor_canTriggerRetry() async throws {
        let interceptor = MockResponseInterceptor()
        interceptor.shouldRetry = true

        let chain = InterceptorChain(responseInterceptors: [interceptor])
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let response = makeResponse(statusCode: 401)
        let retryData = Data("retried".utf8)
        let retryResponse = makeResponse(statusCode: 200)

        let (resultData, _) = try await chain.apply(
            to: response,
            request: request,
            data: Data(),
            retryHandler: {
                return (retryData, retryResponse)
            }
        )

        XCTAssertEqual(resultData, retryData)
        XCTAssertEqual(interceptor.retryCount, 1)
    }

    func test_responseInterceptor_canMutateData() async throws {
        let newData = Data("mutated".utf8)
        let interceptor = MockResponseInterceptor()
        interceptor.stubbedData = newData

        let chain = InterceptorChain(responseInterceptors: [interceptor])
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let response = makeResponse(statusCode: 200)

        let (resultData, _) = try await chain.apply(
            to: response,
            request: request,
            data: Data("original".utf8),
            retryHandler: { (Data(), response) }
        )

        XCTAssertEqual(resultData, newData)
    }

    func test_responseInterceptor_whenThrows_propagatesError() async throws {
        let interceptor = MockResponseInterceptor()
        interceptor.stubbedError = AppError.unauthorized

        let chain = InterceptorChain(responseInterceptors: [interceptor])
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let response = makeResponse(statusCode: 401)

        do {
            _ = try await chain.apply(
                to: response,
                request: request,
                data: Data(),
                retryHandler: { (Data(), response) }
            )
            XCTFail("Expected error to be thrown")
        } catch AppError.unauthorized {
            // ✅
        }
    }

    // MARK: - Helpers

    private func makeResponse(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}

// MARK: - Private test helpers

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

private final class OrderedMockResponseInterceptor: ResponseInterceptorProtocol,
    @unchecked Sendable
{
    let tag: Int
    let action: () -> Void

    init(tag: Int, action: @escaping () -> Void) {
        self.tag = tag
        self.action = action
    }

    func intercept(
        request: URLRequest,
        response: HTTPURLResponse,
        data: Data,
        retryHandler: @Sendable () async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        action()
        return (data, response)
    }
}
