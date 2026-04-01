//
//  TransportProtocol.swift
//  NetworkCore/Protocols
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public protocol TransportProtocol: Sendable {

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)

}
