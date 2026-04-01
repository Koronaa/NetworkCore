//
//  MockResponseCache.swift
//  NetworkCore/NetworkCoreMocks
//
//  Created by Sajith Konara on 1/4/26.
//

import Foundation
import NetworkCore

public actor MockResponseCache: ResponseCacheProtocol {
    public private(set) var store: [String: CachedResponse] = [:]
    public private(set) var getCallCount: Int = 0
    public private(set) var setCallCount: Int = 0
    public private(set) var invalidatedKeys: [String] = []
    public private(set) var invalidatedAllCallCount: Int = 0

    public init() {}

    public func get(forKey key: String) async -> NetworkCore.CachedResponse? {
        getCallCount += 1
        return store[key]
    }

    public func set(_ response: NetworkCore.CachedResponse, forKey key: String)
        async
    {
        setCallCount += 1
        store[key] = response
    }

    public func invalidate(forKey key: String) async {
        invalidatedKeys.append(key)
        store.removeValue(forKey: key)
    }

    public func invalidateAll() async {
        invalidatedAllCallCount += 1
        store.removeAll()
    }

}
