//
//  APIClientProtocol.swift
//  NetworkCore/Protocols
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public protocol APIClientProtocol: Sendable {

    func request<T: Decodable & Sendable>(_ endpoint: any Endpoint) async throws
        -> T

}
