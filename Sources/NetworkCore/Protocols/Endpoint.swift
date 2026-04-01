//
//  Endpoint.swift
//  NetworkCore/Protocols
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

public protocol Endpoint: Sendable {
    var baseURL: URL { get }
    var path: String { get }
    var methods: HTTPMethod { get }
    var headers: [String: String] { get }
    var queryItems: [URLQueryItem] { get }
    var body: Data? { get }
}

extension Endpoint {
    public var headers: [String: String] { [:] }
    public var queryItems: [URLQueryItem] { [] }
    public var body: Data? { nil }

    public var urlRequest: URLRequest {
        guard
            var components = URLComponents(
                url: baseURL.appendingPathComponent(path),
                resolvingAgainstBaseURL: false
            )
        else {
            preconditionFailure("Invalid URL: \(baseURL)\(path)")
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            preconditionFailure("Could not construct URL from components.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = methods.rawValue
        request.httpBody = body
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request

    }
}
