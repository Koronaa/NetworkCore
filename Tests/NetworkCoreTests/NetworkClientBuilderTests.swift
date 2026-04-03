//
//  NetworkClientBuilderTests.swift
//  NetworkCore/NetworkCoreTests
//
//  Created by Sajith Konara on 3/4/26.
//

import XCTest

@testable import NetworkCore

final class NetworkClientBuilderTests: XCTestCase {

    func test_build_withoutBaseURL_throwsInvalidURL() {
        XCTAssertThrowsError(try NetworkClientBuilder().build()) { error in
            XCTAssertEqual(error as? AppError, AppError.network(.invalidURL))
        }
    }

    func test_build_minimalConfig_returnsClient() {
        let client = try? NetworkClientBuilder()
            .baseURL("https://api.example.com")
            .build()
        XCTAssertNotNil(client)
    }

    func test_build_withAllOptions_doesNotCrash() throws {
        let cacheURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("TestCache")

        let client = try? NetworkClientBuilder()
            .baseURL("https://api.example.com")
            .retryPolicy(.exponential(maxAttempts: 3, baseDelay: 1.0))
            .cachePolicy(.ttl(seconds: 300), store: .disk(at: cacheURL))
            .decoder(JSONResponseDecoder())
            .addInterceptor(LoggingInterceptor(level: .verbose))
            .build()

        XCTAssertNotNil(client)
    }

}
