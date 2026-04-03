//
//  InMemoryResponseCache.swift
//  NetworkCore/Cache
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public actor InMemoryResponseCache: ResponseCacheProtocol {
    private var store: [String: CachedResponse] = [:]
    private let maxEntries: Int

    public init(maxEntries: Int = 100) {
        self.maxEntries = maxEntries
    }

    public func get(forKey key: String) async -> CachedResponse? {
        guard let entry = store[key] else { return nil }
        if entry.isExpired {
            store.removeValue(forKey: key)
            return nil
        }
        return entry
    }

    public func set(_ response: CachedResponse, forKey key: String) async {
        if store.count >= maxEntries {
            // Simple eviction: remove the first (oldest) entry
            store.removeValue(forKey: store.keys.first!)
        }
        store[key] = response
    }

    public func invalidate(forKey key: String) async {
        store.removeValue(forKey: key)
    }

    public func invalidateAll() async {
        store.removeAll()
    }

}
