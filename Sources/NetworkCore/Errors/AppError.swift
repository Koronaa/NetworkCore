//
//  AppError.swift
//  NetworkCore/Errors
//
//  Created by Sajith Konara on 30/3/26.
//

import Foundation

public enum AppError: Error, LocalizedError, Equatable {
    case network(NetworkFailure)
    case storage(StorageFailure)
    case validation(String)
    case unauthorized
    case unknown(String)

    public enum NetworkFailure: Equatable, Sendable {
        case noConnection
        case timeout
        case serverError(statusCode: Int)
        case decodingFailed
        case invalidURL
        case cancelled
    }

    public enum StorageFailure: Equatable, Sendable {
        case readFailed
        case writeFailed
        case notFound
    }

    public var errorDescription: String? {
        switch self {
        case .network(.noConnection): return "No internet connection."
        case .network(.timeout): return "Request timed out."
        case .network(.serverError(let code)): return "Server error (\(code))."
        case .network(.decodingFailed): return "Failed to decode response."
        case .network(.invalidURL): return "Invalid URL."
        case .network(.cancelled): return "Request cancelled."
        case .storage(.readFailed): return "Could not read from storage."
        case .storage(.writeFailed): return "Could not write to storage."
        case .storage(.notFound): return "Item not found."
        case .validation(let msg): return msg
        case .unauthorized: return "Not authorised."
        case .unknown(let msg): return msg
        }
    }

}

// AppErrorConvertible lets consuming apps bridge their own error types
// into AppError at the repository boundary without losing type information.
public protocol AppErrorConvertible {
    var asAppError: AppError { get }
}
