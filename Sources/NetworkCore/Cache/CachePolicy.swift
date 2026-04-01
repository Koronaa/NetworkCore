//
//  CachePolicy.swift
//  NetworkCore/Cache
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public enum CachePolicy: Sendable {
    case ttl(seconds: TimeInterval)
    case staleWhileRevalidate(ttl: TimeInterval)
    case etag
}

public enum CacheStore: Sendable {
    case memory
    case disk(at: URL)
}
