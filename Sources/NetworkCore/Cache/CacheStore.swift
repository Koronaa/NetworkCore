//
//  CacheStore.swift
//  NetworkCore/Cache
//
//  Created by Sajith Konara on 1/4/26.
//

import Foundation

public enum CacheStore: Sendable {
    case memory
    case disk(at: URL)
}
