//
//  SessionRepositoryProtocol.swift
//  NetworkCore/Protocols
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public protocol SessionRepositoryProtocol: Sendable {

    func loadToken() throws -> String
    func cleanToken()

}
