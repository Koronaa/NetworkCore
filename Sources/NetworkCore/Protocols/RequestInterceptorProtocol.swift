//
//  RequestInterceptorProtocol.swift
//  NetworkCore/Protocols
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public protocol RequestInterceptorProtocol: Sendable {

    func intercept(_ request: URLRequest) async throws -> URLRequest

}
