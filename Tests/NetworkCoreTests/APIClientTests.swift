//
//  APIClientTests.swift
//  NetworkCore/NetworkCoreTests
//
//  Created by Sajith Konara on 2/4/26.
//

import NetworkCoreMocks
import XCTest

@testable import NetworkCore

final class APIClientTests: XCTestCase {

    private struct TestDTO: Decodable, Equatable, Sendable {
        let id: Int
        let name: String
    }

    private struct TestEndpoint: Endpoint {

        var baseURL: URL { URL(string: "https://api.example.com")! }
        var path: String { "/test" }
        var method: HTTPMethod { .get }
    }

    func test_request_success_returnsDecodedValue() async throws {
        let json = #"{"id": 1, "name": "Jhon"}"#.data(using: .utf8)!
        let transport = MockTransport()
        transport.stubbedData = json

        let client = try! NetworkClientBuilder()
            .baseURL("https://api.example.com")
            .transport(transport)
            .build()

        let result: TestDTO = try await client.request(TestEndpoint())
        XCTAssertEqual(result, TestDTO(id: 1, name: "Jhon"))
    }

    func test_request_serverError_throwsAppError() async {
        let transport = MockTransport()
        transport.stubbedError = AppError.network(.serverError(statusCode: 500))

        let client = try! NetworkClientBuilder()
            .baseURL("https://api.example.com")
            .transport(transport)
            .build()

        do {
            let _: TestDTO = try await client.request(TestEndpoint())
            XCTFail("Expected error")
        } catch AppError.network(.serverError(let code)) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error: \(error.localizedDescription)")
        }
    }

    func test_request_retries_onTimeout() async throws {
        let transport = MockTransport()
        // First two calls time out, third succeeds
        let json = #"{"id": 1, "name": "Jhon"}"#.data(using: .utf8)!
        transport.stubbedData = json

        let realTransport = CountingTransport(
            wrapped: transport,
            failFirstN: 2,
            error: AppError.network(.timeout)
        )

        let client = try! NetworkClientBuilder()
            .baseURL("https://api.example.com")
            .retryPolicy(.immediate(maxAttempts: 3))
            .transport(realTransport)
            .build()

        let result: TestDTO = try await client.request(TestEndpoint())
        XCTAssertEqual(realTransport.callCount, 3)
        XCTAssertEqual(result.id, 1)
    }

    func test_request_hitsCache_onSecondCall() async throws {
        let json = #"{"id": 1, "name": "Jhon"}"#.data(using: .utf8)!
        let transport = MockTransport()
        transport.stubbedData = json

        let mockCache = MockResponseCache()

        let client = APIClient(
            chain: InterceptorChain(),
            transport: transport,
            decoder: JSONResponseDecoder(),
            cache: mockCache,
            cachePolicy: .ttl(seconds: 300),
            retryPolicy: nil
        )

        let _: TestDTO = try await client.request(TestEndpoint())
        let _: TestDTO = try await client.request(TestEndpoint())

        let setCalls = await mockCache.setCallCount
        let getCalls = await mockCache.getCallCount
        XCTAssertEqual(setCalls, 1)  //written once
        XCTAssertEqual(getCalls, 2)  //checked twice
        XCTAssertEqual(transport.sentRequests.count, 1)  //network hit once
    }

}

//Helper for retry test
private final class CountingTransport: TransportProtocol, @unchecked Sendable {
    private let wrapped: MockTransport
    private let failFirstN: Int
    private let error: Error
    private(set) var callCount = 0

    init(wrapped: MockTransport, failFirstN: Int, error: Error) {
        self.wrapped = wrapped
        self.failFirstN = failFirstN
        self.error = error
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        callCount += 1
        if callCount <= failFirstN { throw error }
        return try await wrapped.send(request)
    }

}
