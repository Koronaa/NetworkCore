//
//  ResponseDecoderProtocol.swift
//  NetworkCore/Protocols
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public protocol ResponseDecoderProtocol: Sendable {

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T

}
