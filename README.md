# NetworkCore

A modular, protocol-first Swift networking package built for reuse across multiple projects. Designed around Clean Architecture and SOLID principles with Swift strict concurrency from the ground up.

---

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Core concepts](#core-concepts)
  - [Endpoint](#endpoint)
  - [APIClientProtocol](#apiclientprotocol)
  - [Builder](#builder)
  - [Interceptors](#interceptors)
  - [Retry](#retry)
  - [Cache](#cache)
  - [Session and auth](#session-and-auth)
  - [Error handling](#error-handling)
- [Testing](#testing)
- [Architecture](#architecture)
- [Module structure](#module-structure)
- [License](#license)

---

## Features

- Protocol-first design — every layer is swappable
- Interceptor chain — auth, logging, retry, and custom interceptors composable in any order
- Built-in retry with immediate and exponential back-off strategies
- Response caching with TTL, stale-while-revalidate, and ETag policies
- Two cache backends — in-memory and disk — both swappable via protocol
- Auth token injection decoupled from storage — bring your own Keychain/UserDefaults
- `NetworkCoreMocks` target ships ready-made test doubles for all protocols
- Full Swift strict concurrency — `actor`-based internals, `Sendable` on all boundaries
- Zero third-party dependencies

---

## Requirements

| | Minimum |
|---|---|
| iOS | 17.0 |
| macOS | 14.0 |
| Swift | 5.9 |
| Xcode | 15.0 |

---

## Installation

### Swift Package Manager

In Xcode go to **File → Add Package Dependencies** and enter the repository URL:

```
https://github.com/Koronaa/NetworkCore
```

Or add it directly to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Koronaa/NetworkCore", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["NetworkCore"]
    ),
    .testTarget(
        name: "YourAppTests",
        dependencies: ["NetworkCore", "NetworkCoreMocks"]
    )
]
```

> Import `NetworkCoreMocks` in test targets only. It is a separate library product and will not inflate your production binary.

---

## Quick start

### Minimum configuration

```swift
import NetworkCore

let client = NetworkClientBuilder()
    .build()
```

### With auth

```swift
let client = NetworkClientBuilder()
    .session(sessionRepository)   // your SessionRepositoryProtocol conformer
    .build()
```

### Full configuration

```swift
let cacheURL = FileManager.default
    .urls(for: .cachesDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("NetworkCache")

let client = try NetworkClientBuilder()
    .session(sessionRepository)
    .addInterceptor(LoggingInterceptor(level: .verbose))
    .retryPolicy(.exponential(maxAttempts: 3, baseDelay: 1.0))
    .cachePolicy(.ttl(seconds: 300), store: .disk(at: cacheURL))
    .decoder(JSONResponseDecoder())
    .build()
```

### Making a request

Define an endpoint:

```swift
import NetworkCore

enum PostsEndpoint: Endpoint {
    case list
    case detail(id: Int)

    var baseURL: URL { URL(string: "https://api.example.com")! }

    var path: String {
        switch self {
        case .list:          return "/posts"
        case .detail(let id): return "/posts/\(id)"
        }
    }

    var method: HTTPMethod { .get }
}
```

Call it from a repository:

```swift
final class PostsRepository {
    private let client: any APIClientProtocol

    init(client: any APIClientProtocol) {
        self.client = client
    }

    func fetchPosts() async throws -> [Post] {
        try await client.request(PostsEndpoint.list)
    }

    func fetchPost(id: Int) async throws -> Post {
        try await client.request(PostsEndpoint.detail(id: id))
    }
}
```

---

## Core concepts

### Endpoint

`Endpoint` describes a single API request as a value type. Each endpoint is its own type — adding a new endpoint never touches existing ones (Open/Closed Principle).

```swift
public protocol Endpoint: Sendable {
    var baseURL:    URL              { get }
    var path:       String           { get }
    var method:     HTTPMethod       { get }
    var headers:    [String: String] { get }   // default: [:]
    var queryItems: [URLQueryItem]   { get }   // default: []
    var body:       Data?            { get }   // default: nil
}
```

A POST endpoint with a body:

```swift
enum AuthEndpoint: Endpoint {
    case login(email: String, password: String)

    var baseURL: URL { URL(string: "https://api.example.com")! }

    var path: String {
        switch self { case .login: return "/auth/login" }
    }

    var method: HTTPMethod { .post }

    var body: Data? {
        switch self {
        case .login(let email, let password):
            return try? JSONEncoder().encode([
                "email": email,
                "password": password
            ])
        }
    }
}
```

---

### APIClientProtocol

The only type your feature layer should depend on. Import this protocol, never the concrete `APIClient`.

```swift
public protocol APIClientProtocol: Sendable {
    func request<T: Decodable & Sendable>(_ endpoint: any Endpoint) async throws -> T
}
```

This is the Dependency Inversion boundary — your repositories depend on the abstraction, the concrete implementation is wired at the composition root and never leaks upward.

---

### Builder

`NetworkClientBuilder` is the single configuration point. All options except `baseURL` are optional and have sensible defaults.

```swift
NetworkClientBuilder()
    .session(any SessionRepositoryProtocol)             // optional — enables auth
    .addInterceptor(any RequestInterceptorProtocol)     // optional — repeatable
    .retryPolicy(RetryPolicy)                           // optional — default: none
    .cachePolicy(CachePolicy, store: CacheStore)        // optional — default: none
    .decoder(any ResponseDecoderProtocol)               // optional — default: JSONResponseDecoder
    .transport(any TransportProtocol)                   // optional — default: URLSessionTransport
    .build()                                            
```

Interceptors are assembled in this order regardless of the order you call `addInterceptor`:

```
AuthTokenInterceptor   (if session provided)
custom interceptors    (in the order added)
RetryInterceptor       (if retryPolicy provided)
```

Retry is always outermost so each attempt re-runs the full chain — including re-attaching a potentially refreshed auth token.

---

### Interceptors

Interceptors conform to `RequestInterceptorProtocol` and are composed via `InterceptorChain`. Each interceptor has one job (Single Responsibility). Adding a new cross-cutting concern means adding a new type, not editing existing ones (Open/Closed).

```swift
public protocol RequestInterceptorProtocol: Sendable {
    func intercept(_ request: URLRequest) async throws -> URLRequest
}
```

**Interceptors included in the package:**

| Type | Purpose | Added automatically |
|---|---|---|
| `AuthTokenInterceptor` | Injects `Bearer` token from `SessionRepositoryProtocol` | Yes, if `.session()` is set |
| `LoggingInterceptor` | Prints request details | No — opt in via `.addInterceptor()` |
| `RetryInterceptor` | Tags request with retry limit | Yes, if `.retryPolicy()` is set |

**Writing a custom interceptor:**

```swift
// Add a correlation ID to every request for distributed tracing
struct CorrelationIDInterceptor: RequestInterceptorProtocol {
    func intercept(_ request: URLRequest) async throws -> URLRequest {
        var mutated = request
        mutated.setValue(UUID().uuidString, forHTTPHeaderField: "X-Correlation-ID")
        return mutated
    }
}

// Register it
let client = NetworkClientBuilder()
    .addInterceptor(CorrelationIDInterceptor())
    .build()
```

**Logging levels:**

```swift
.addInterceptor(LoggingInterceptor(level: .minimal))   // method + URL only
.addInterceptor(LoggingInterceptor(level: .verbose))   // headers + body
```

---

### Retry

Two strategies are available. Both skip retry for client errors (`401`, decoding failures, invalid URLs) where retrying would never help.

```swift
// Retry up to 3 times with no delay between attempts
.retryPolicy(.immediate(maxAttempts: 3))

// Retry up to 3 times with exponential back-off: 1s, 2s, 4s (capped at 30s)
.retryPolicy(.exponential(maxAttempts: 3, baseDelay: 1.0))
```

Errors that are never retried regardless of policy:

- `AppError.unauthorized` — retrying with the same token won't help
- `AppError.network(.decodingFailed)` — a bug, not a transient failure
- `AppError.network(.invalidURL)` — a programming error

---

### Cache

**Policies:**

```swift
// Cache for a fixed duration
.cachePolicy(.ttl(seconds: 300), store: .memory)

// Return stale data immediately, refresh in background
.cachePolicy(.staleWhileRevalidate(ttl: 60), store: .disk(at: cacheURL))

// Validate with server using ETag / If-None-Match
.cachePolicy(.etag, store: .memory)
```

**Stores:**

```swift
// In-memory — fast, cleared on app restart
.cachePolicy(.ttl(seconds: 60), store: .memory)

// Disk-backed — persists across launches, app provides the path
let cacheURL = FileManager.default
    .urls(for: .cachesDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("NetworkCache")

.cachePolicy(.ttl(seconds: 300), store: .disk(at: cacheURL))
```

The disk path is always provided by the consuming app — the package makes no assumptions about where your app stores files. This ensures correct behaviour in app extensions, app groups, and sandboxed macOS targets.

**Cache invalidation from a repository:**

The package ships `ResponseCacheProtocol` so repositories can invalidate entries after mutations:

```swift
final class PostsRepository {
    private let client: any APIClientProtocol
    private let cache:  any ResponseCacheProtocol

    func createPost(_ post: NewPost) async throws -> Post {
        let created: Post = try await client.request(PostsEndpoint.create(post))
        // Invalidate the list so the next fetch is fresh
        await cache.invalidate(forKey: "/posts")
        return created
    }
}
```

---

### Session and auth

The package defines `SessionRepositoryProtocol` — a narrow contract covering only what the network layer needs. Your app implements it against whatever storage you choose (Keychain, UserDefaults, in-memory for tests).

```swift
public protocol SessionRepositoryProtocol: Sendable {
    func loadToken() throws -> String
    func clearToken()
}
```

A typical Keychain-backed implementation:

```swift
final class KeychainSessionRepository: SessionRepositoryProtocol {
    private let keychain: KeychainStorage

    func loadToken() throws -> String {
        try keychain.load(String.self, forKey: "session.token")
    }

    func clearToken() throws{
        keychain.delete(forKey: "session.token")
    }
    
    func saveToken(_ token:String) throws{
        try keychain.save(token, forKey: "session.token")
    }
}
```

Token saving is intentionally not part of this protocol — that belongs in your `AuthRepository` after a successful login response, not in the network layer.

```swift
// ✅ Correct — token saved at repository level after login
final class AuthRepository {
    private let client:  any APIClientProtocol
    private let session: any SessionRepositoryProtocol

    func login(email: String, password: String) async throws -> User {
        let response: AuthResponse = try await client.request(
            AuthEndpoint.login(email: email, password: password)
        )
        try session.saveToken(response.token)  // ← here, not inside APIClient
        return response.user.toDomain()
    }
}
```

---

### Error handling

All errors flow through `AppError`. Map them at the repository boundary to keep your domain layer clean.

```swift
public enum AppError: Error, LocalizedError, Equatable {
    case network(NetworkFailure)
    case storage(StorageFailure)
    case validation(String)
    case unauthorized
    case unknown(String)
}
```

Handling errors in a ViewModel:

```swift
func fetchPosts() async {
    state = .loading
    do {
        let posts = try await fetchPostsUseCase.execute()
        state = .success(posts)
    } catch AppError.network(.noConnection) {
        state = .failure(.noConnection)
    } catch AppError.unauthorized {
        // Token expired — trigger re-login flow
        coordinator.showLogin()
    } catch let error as AppError {
        state = .failure(error)
    }
}
```

Bridging your own domain errors with `AppErrorConvertible`:

```swift
enum PaymentError: Error, AppErrorConvertible {
    case insufficientFunds
    case cardDeclined

    var asAppError: AppError {
        switch self {
        case .insufficientFunds: return .validation("Insufficient funds.")
        case .cardDeclined:      return .validation("Card declined.")
        }
    }
}
```

---

## Testing

Add `NetworkCoreMocks` to your test target. It ships four ready-made test doubles.

### MockAPIClient

```swift
import NetworkCoreMocks

final class PostsRepositoryTests: XCTestCase {

    func test_fetchPosts_returnsMappedPosts() async throws {
        let mock = MockAPIClient()
        mock.stubbedResult = [
            PostDTO(id: 1, title: "Hello", body: "World", userId: 1)
        ]

        let repo   = PostsRepository(client: mock)
        let posts  = try await repo.fetchPosts()

        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(posts[0].title, "Hello")
        XCTAssertEqual(mock.callCount, 1)
    }

    func test_fetchPosts_onNetworkError_throwsAppError() async {
        let mock = MockAPIClient()
        mock.stubbedError = AppError.network(.noConnection)

        let repo = PostsRepository(client: mock)

        do {
            _ = try await repo.fetchPosts()
            XCTFail("Expected error")
        } catch AppError.network(.noConnection) {
            // ✅
        }
    }
}
```

### MockTransport

Use when you want to test `APIClient` internals — simulates raw server responses without a network connection.

```swift
func test_request_mapsServerError() async {
    let transport = MockTransport()
    transport.stubbedError = AppError.network(.serverError(statusCode: 503))

    let client = NetworkClientBuilder()
        .transport(transport)
        .build()

    do {
        let _: SomeDTO = try await client.request(SomeEndpoint())
        XCTFail("Expected error")
    } catch AppError.network(.serverError(let code)) {
        XCTAssertEqual(code, 503)
    }
}
```

### MockInterceptor

Verifies that interceptors are called and can inspect or mutate requests in tests.

```swift
func test_interceptorIsCalledOnRequest() async throws {
    let interceptor = MockInterceptor()
    interceptor.modifier = { request in
        var r = request
        r.setValue("test-value", forHTTPHeaderField: "X-Custom")
        return r
    }

    let transport = MockTransport()
    transport.stubbedData = validJSON

    let client = NetworkClientBuilder()
        .addInterceptor(interceptor)
        .transport(transport)
        .build()

    let _: SomeDTO = try await client.request(SomeEndpoint())

    XCTAssertEqual(interceptor.interceptedRequests.count, 1)
    XCTAssertEqual(
        interceptor.interceptedRequests[0].value(forHTTPHeaderField: "X-Custom"),
        "test-value"
    )
}
```

### MockResponseCache

Verifies cache reads, writes, and invalidations without touching disk or memory stores.

```swift
func test_repository_invalidatesCache_afterCreate() async throws {
    let client = MockAPIClient()
    client.stubbedResult = PostDTO(id: 99, title: "New", body: "Body", userId: 1)

    let cache = MockResponseCache()
    let repo  = PostsRepository(client: client, cache: cache)

    try await repo.createPost(NewPost(title: "New", body: "Body"))

    let invalidatedKeys = await cache.invalidateKeys
    XCTAssertTrue(invalidatedKeys.contains("/posts"))
}
```

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Feature layer (ViewModel / UseCase)            │
│  depends on APIClientProtocol only              │
└────────────────────┬────────────────────────────┘
                     │
          ╔══════════▼══════════╗
          ║  APIClientProtocol  ║  ← DIP boundary
          ╚══════════╤══════════╝
                     │  conforms to
┌────────────────────▼────────────────────────────┐
│  APIClient (actor)                              │
│  ├── InterceptorChain                           │
│  │     ├── AuthTokenInterceptor                 │
│  │     ├── [custom interceptors]                │
│  │     └── RetryInterceptor                     │
│  ├── TransportProtocol → URLSessionTransport    │
│  ├── ResponseDecoderProtocol → JSONDecoder      │
│  └── ResponseCacheProtocol?                     │
│        ├── InMemoryResponseCache (actor)        │
│        └── DiskResponseCache (actor)            │
└─────────────────────────────────────────────────┘
```

**Dependency directions:**

- Feature layer → `APIClientProtocol` (compile-time)
- `APIClient` → `TransportProtocol`, `ResponseDecoderProtocol`, `ResponseCacheProtocol` (runtime, injected)
- `AuthTokenInterceptor` → `SessionRepositoryProtocol` (runtime, injected by app)
- Nothing in the package → app code (unidirectional)

---

## Module structure

```
NetworkCore/
├── Sources/
│   ├── NetworkCore/
│   │   ├── Errors/
│   │   │   └── AppError.swift
│   │   ├── Protocols/
│   │   │   ├── APIClientProtocol.swift
│   │   │   ├── Endpoint.swift
│   │   │   ├── TransportProtocol.swift
│   │   │   ├── ResponseDecoderProtocol.swift
│   │   │   ├── RequestInterceptorProtocol.swift
│   │   │   └── SessionRepositoryProtocol.swift
│   │   ├── Client/
│   │   │   ├── APIClient.swift
│   │   │   └── NetworkClientBuilder.swift
│   │   ├── Interceptors/
│   │   │   ├── InterceptorChain.swift
│   │   │   ├── AuthTokenInterceptor.swift
│   │   │   ├── LoggingInterceptor.swift
│   │   │   └── RetryInterceptor.swift
│   │   ├── Transport/
│   │   │   └── URLSessionTransport.swift
│   │   ├── Decoder/
│   │   │   └── JSONResponseDecoder.swift
│   │   └── Cache/
│   │       ├── CachePolicy.swift
│   │       ├── CachedResponse.swift
│   │       ├── ResponseCacheProtocol.swift
│   │       ├── InMemoryResponseCache.swift
│   │       └── DiskResponseCache.swift
│   │
│   └── NetworkCoreMocks/
│       ├── MockAPIClient.swift
│       ├── MockTransport.swift
│       ├── MockInterceptor.swift
│       └── MockResponseCache.swift
│
└── Tests/
    └── NetworkCoreTests/
        ├── APIClientTests.swift
        ├── InterceptorChainTests.swift
        ├── AuthTokenInterceptorTests.swift
        ├── RetryInterceptorTests.swift
        ├── ResponseCacheTests.swift
        └── NetworkClientBuilderTests.swift
```

---

## License

MIT License. See [LICENSE](LICENSE) for details.
