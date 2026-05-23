//
//  SessionRepositoryProtocol.swift
//  NetworkCore/Protocols
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public protocol SessionRepositoryProtocol: Sendable {

    func loadAccessToken() async throws -> String
    func clearTokens() async throws
    func saveAccessToken(_ token: String) async throws
    func loadRefreshToken() async throws -> String
    func saveRefreshToken(_ token: String) async throws

}
