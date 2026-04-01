//
//  URLSessionTransport.swift
//  NetworkCore/Transport
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public final class URLSessionTransport: TransportProtocol {

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (
        Data, HTTPURLResponse
    ) {
        do {
            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw AppError.network(.decodingFailed)
            }

            switch http.statusCode {
            case 200..<300:
                return (data, http)
            case 401:
                throw AppError.unauthorized
            case 408, 504:
                throw AppError.network(.timeout)
            default:
                throw AppError.network(
                    .serverError(statusCode: http.statusCode)
                )

            }
        } catch let error as AppError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw AppError.network(.noConnection)
            case .timedOut:
                throw AppError.network(.timeout)
            case .cancelled:
                throw AppError.network(.cancelled)
            default:
                throw AppError.unknown(error.localizedDescription)
            }
        }
    }

}
