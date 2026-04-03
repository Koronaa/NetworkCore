//
//  ResponseCacheProtocol.swift
//  NetworkCore/Cache
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public protocol ResponseCacheProtocol: Sendable {
    func get(forKey key: String) async -> CachedResponse?
    func set(_ response: CachedResponse, forKey key: String) async
    func invalidate(forKey key: String) async
    func invalidateAll() async
}
