//
//  JSONResponseDecoder.swift
//  NetworkCore/Decoder
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public final class JSONResponseDecoder: ResponseDecoderProtocol {

    private let decoder: JSONDecoder

    // Default init — sensible out-of-the-box behaviour
    public init() {
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // Custom init — full control when defaults aren't enough
    public init(decoder: JSONDecoder) {
        self.decoder = decoder
    }

    public func decode<T>(_ type: T.Type, from data: Data) throws -> T
    where T: Decodable {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw AppError.network(.decodingFailed)
        }
    }

}
