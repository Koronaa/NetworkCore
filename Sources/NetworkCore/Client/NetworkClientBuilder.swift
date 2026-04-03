//
//  NetworkClientBuilder.swift
//  NetworkCore/Client
//
//  Created by Sajith Konara on 1/4/26.
//

import Foundation

public class NetworkClientBuilder {

    private var baseURL: String?
    private var session: (any SessionRepositoryProtocol)?
    private var interceptors: [any RequestInterceptorProtocol] = []
    private var retryPolicy: RetryPolicy?
    private var cachePolicy: CachePolicy?
    private var cacheStore: CacheStore?
    private var decoder: (any ResponseDecoderProtocol)?
    private var transport: (any TransportProtocol)?

    public init() {}

    //MARK: Required
    @discardableResult
    public func baseURL(_ baseURL: String) -> Self {
        self.baseURL = baseURL
        return self
    }

    //MARK: Optional - auth
    @discardableResult
    public func session(_ session: any SessionRepositoryProtocol) -> Self {
        self.session = session
        return self
    }

    //MARK: Optional - interceptors
    @discardableResult
    public func addInterceptor(_ interceptor: any RequestInterceptorProtocol)
        -> Self
    {
        self.interceptors.append(interceptor)
        return self
    }

    //MARK: Optional - retry
    @discardableResult
    public func retryPolicy(_ policy: RetryPolicy) -> Self {
        self.retryPolicy = policy
        return self
    }

    //MARK: Optional - cache
    @discardableResult
    public func cachePolicy(_ policy: CachePolicy, store: CacheStore = .memory)
        -> Self
    {
        self.cachePolicy = policy
        self.cacheStore = store
        return self
    }

    //MARK: Optional - decoder
    @discardableResult
    public func decoder(_ decoder: any ResponseDecoderProtocol) -> Self {
        self.decoder = decoder
        return self
    }

    //MARK: Optional - transport (primarily for testing)
    @discardableResult
    public func transport(_ transport: any TransportProtocol) -> Self {
        self.transport = transport
        return self
    }

    //MARK: Build
    public func build() throws -> any APIClientProtocol {
        guard let baseURLString = baseURL,
            URL(string: baseURLString) != nil
        else {
            throw AppError.network(.invalidURL)
        }

        // Assemble interceptors in correct order:
        // logging first so it sees the raw request,
        // auth second so token is attached before retry,
        // custom interceptors next,
        // retry last so it wraps everything above it.
        var allInterceptors: [any RequestInterceptorProtocol] = []

        //Logging is not added here, Login needs to be added by the developer specifically if needed by calling .addInterceptor(LoggingInterceptor())

        // Auth runs before custom interceptors so the token
        // is present when any custom logic inspects headers
        if let session {
            allInterceptors.append(AuthTokenInterceptor(session: session))
        }

        // Custom interceptors added by the developer via .addInterceptor()
        // This is also where LoggingInterceptor lands if the developer opts in
        allInterceptors.append(contentsOf: interceptors)

        // Retry wraps everything — it re-runs the full chain on each attempt
        if let retryPolicy {
            allInterceptors.append(RetryInterceptor(policy: retryPolicy))
        }

        //Resolve cache store
        let resolvedCache: (any ResponseCacheProtocol)? = cacheStore.flatMap {
            store in
            switch store {
            case .memory:
                return InMemoryResponseCache()
            case .disk(let url):
                return try? DiskResponseCache(directory: url)
            }
        }

        return APIClient(
            chain: InterceptorChain(interceptors: allInterceptors),
            transport: transport ?? URLSessionTransport(),
            decoder: decoder ?? JSONResponseDecoder(),
            cache: resolvedCache,
            cachePolicy: cachePolicy,
            retryPolicy: retryPolicy
        )

    }

}
