//
//  DiskResponseCache.swift
//  NetworkCore/Cache
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public actor DiskResponseCache: ResponseCacheProtocol {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    public func get(forKey key: String) async -> CachedResponse? {
        let file = fileURL(for: key)
        guard
            let data = try? Data(contentsOf: file),
            let entry = try? decoder.decode(CachedResponse.self, from: data)
        else { return nil }
        return entry
    }

    public func set(_ response: CachedResponse, forKey key: String) async {
        guard let data = try? encoder.encode(response) else { return }
        let destination = fileURL(for: key)
        // Fire-and-forget background write — doesn't block the actor
        Task.detached(priority: .background) {
            try? data.write(to: destination, options: .atomic)
        }

    }

    public func invalidate(forKey key: String) async {
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    public func invalidateAll() async {
        let files =
            (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )) ?? []
        files.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    private func fileURL(for key: String) -> URL {
        // Sanitise the key so it's safe as a filename
        let safe =
            key
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return directory.appending(path: "\(safe).cache")
    }

}
