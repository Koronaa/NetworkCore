//
//  ResponseInterceptorProtocol.swift
//  NetworkCore/Protocols
//
//  Created by Sajith Konara on 22/5/26.
//

import Foundation

/*
- Intercepts a response after the transport returns it.
- Conformers can inspect the response, mutate date, or trigger a re-try by calling
 'retryHandler' - which re-runs the full request pipeline including all request interceptors.

 */

public protocol ResponseInterceptorProtocol: Sendable {

    func intercept(
        request: URLRequest,
        response: HTTPURLResponse,
        data: Data,
        retryHandler: @Sendable () async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse)

}
