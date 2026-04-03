//
//  LoggingInterceptor.swift
//  NetworkCore/Interceptors
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public final class LoggingInterceptor: RequestInterceptorProtocol {

    public enum LogLevel: Sendable { case minimal, verbose }

    private let level: LogLevel

    public init(level: LogLevel = .minimal) {
        self.level = level
    }

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        switch level {
        case .minimal:
            print(
                "[NetworkCore] -> \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")"
            )
        case .verbose:
            print(
                "[NetworkCore] -> \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")"
            )
            request.allHTTPHeaderFields?.forEach {
                print("[NetworkCore] \($0.key): \($0.value)")
            }
            if let body = request.httpBody {
                if let pretty = String(data: body, encoding: .utf8) {
                    print("[NetworkCore] body: \(pretty)")
                }
            }
        }
        return request
    }

}
