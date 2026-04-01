//
//  APIClient.swift
//  NetworkCore/Client
//
//  Created by Sajith Konara on 31/3/26.
//

import Foundation

public actor APIClient: APIClientProtocol {
    private let chain: InterceptorChain
    private let transport: any TransportProtocol
    private let decoder: any ResponseDecoderProtocol
    private let cache: (any ResponseCacheProtocol)?
    private let cachePolicy: CachePolicy?
    private let retryPolicy: RetryPolicy?

    init(
        chain: InterceptorChain,
        transport: any TransportProtocol,
        decoder: any ResponseDecoderProtocol,
        cache: (any ResponseCacheProtocol)? = nil,
        cachePolicy: CachePolicy? = nil,
        retryPolicy: RetryPolicy? = nil
    ) {
        self.chain = chain
        self.transport = transport
        self.decoder = decoder
        self.cache = cache
        self.cachePolicy = cachePolicy
        self.retryPolicy = retryPolicy
    }

    public func request<T>(_ endpoint: any Endpoint) async throws -> T
    where T: Decodable & Sendable {

        let cacheKey = makeCacheKey(for: endpoint)
        // ── Cache read ───────────────────────────────────────────────────────
        if let cache, let policy = cachePolicy {
            if let cached = await cache.get(forKey: cacheKey) {
                switch policy {
                case .ttl, .etag:
                    if !cached.isExpired {
                        return try decoder.decode(T.self, from: cached.data)
                    }
                case .staleWhileRevalidate(let ttl):
                    if !cached.isExpired {
                        return try decoder.decode(T.self, from: cached.data)
                    }

                    // Stale but within revalidation window — return stale,
                    // fire background refresh
                    if Date().timeIntervalSince(cached.expiresAt) < ttl {
                        Task {
                            await self.revalidate(endpoint, key: cacheKey)
                        }
                        return try decoder.decode(T.self, from: cached.data)
                    }

                }
            }
        }

        // ── Network fetch (with optional retry) ──────────────────────────────
        return try await fetchAndCache(endpoint, key: cacheKey)
    }

    //MARK: private

    // Works at Data level — no generic T needed, safe to call from a
    // background Task where the return type can't be inferred.
    private func revalidate(_ endpoint: any Endpoint, key: String) async {
        guard let cache, let policy = cachePolicy else { return }
        do {
            let data = try await fetchWithRetry(endpoint)
            let ttl: TimeInterval
            switch policy {
            case .ttl(let seconds):
                ttl = seconds
            case .staleWhileRevalidate(let seconds):
                ttl = seconds
            case .etag:
                ttl = 3600
            }
            await cache.set(
                CachedResponse(
                    data: data,
                    expiresAt: Date().addingTimeInterval(ttl)
                ),
                forKey: key
            )
        } catch {
            // Background revalidation failure is silent —
            // the caller already has a usable stale response
        }
    }

    @discardableResult
    private func fetchAndCache<T: Decodable & Sendable>(
        _ endpoint: any Endpoint,
        key: String
    ) async throws -> T {

        let data = try await fetchWithRetry(endpoint)
        let decoded: T = try decoder.decode(T.self, from: data)

        // ── Cache write ──────────────────────────────────────────────────────
        if let cache, let policy = cachePolicy {
            let ttl: TimeInterval
            switch policy {
            case .ttl(let seconds):
                ttl = seconds
            case .staleWhileRevalidate(let seconds):
                ttl = seconds
            case .etag:
                ttl = 3600
            }
            await cache.set(
                CachedResponse(
                    data: data,
                    expiresAt: Date().addingTimeInterval(ttl)
                ),
                forKey: key
            )
        }

        return decoded

    }

    @discardableResult
    private func fetchWithRetry(_ endpoint: any Endpoint) async throws -> Data {
        let maxAttempts = retryPolicy?.maxAttempts ?? 1
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                let raw = endpoint.urlRequest
                let enriched = try await chain.apply(to: raw)
                let (data, _) = try await transport.send(enriched)
                return data
            } catch {
                lastError = error
                // Don't retry client errors or auth failures
                if let appError = error as? AppError {
                    switch appError {
                    case .unauthorized, .network(.decodingFailed),
                        .network(.invalidURL):
                        throw appError
                    default: break
                    }
                }
                if attempt < maxAttempts, let policy = retryPolicy {
                    let delay = policy.delay(forAttempt: attempt)
                    if delay > 0 {
                        try await Task.sleep(
                            nanoseconds: UInt64(delay * 1_000_000_000)
                        )
                    }
                }
            }
        }
        throw lastError
            ?? AppError.unknown("Request failed after \(maxAttempts) attempts")
    }

    private func makeCacheKey(for endpoint: any Endpoint) -> String {
        let url = endpoint.baseURL.absoluteString + endpoint.path
        let params = endpoint.queryItems
            .sorted { $0.name < $1.name }
            .map { "\($0.name)=\($0.value ?? "")" }
            .joined(separator: "&")
        return params.isEmpty ? url : "\(url)?\(params)"
    }

}
