//
//  AuthTokenInterceptor.swift
//  NetworkCore/Interceptors
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public final class AuthTokenInterceptor: RequestInterceptorProtocol {

    private let session: any SessionRepositoryProtocol

    public init(session: any SessionRepositoryProtocol) {
        self.session = session
    }

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        guard let token = try? await session.loadToken() else {
            // No token available — pass through unauthenticated.
            // Transport will receive a 401 and throw AppError.unauthorized.
            return request
        }
        var mutated = request
        mutated.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return mutated
    }

}
