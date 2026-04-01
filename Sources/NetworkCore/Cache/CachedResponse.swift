//
//  CachedResponse.swift
//  NetworkCore/Cache
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public struct CachedResponse: Codable, Sendable {
    public let data: Data
    public let expiresAt: Date
    public let etag: String?

    public var isExpired: Bool {
        return Date() > expiresAt
    }

    public init(data: Data, expiresAt: Date, etag: String? = nil) {
        self.data = data
        self.expiresAt = expiresAt
        self.etag = etag
    }

}
