import Foundation
import XCTest
@testable import AgeWalletSDK

/// URLProtocol that, while registered, receives every request made through URLSession.shared
/// (the session the SDK uses), records it and fails it with URLError(.notConnectedToInternet).
final class BlockingURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var recorded: [URLRequest] = []

    static var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    static func reset() {
        lock.lock()
        recorded = []
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.recorded.append(request)
        Self.lock.unlock()
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}

/// Base class for tests that call the SDK. Each test starts and ends with the SDK's Keychain items
/// cleared, runs with BlockingURLProtocol registered, and fails if it sent any request.
class NetworkBlockedTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        AgeWallet(config: makeConfig()).clearVerification()
        BlockingURLProtocol.reset()
        URLProtocol.registerClass(BlockingURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(BlockingURLProtocol.self)
        let sent = BlockingURLProtocol.requests.compactMap { $0.url?.absoluteString }
        XCTAssertTrue(sent.isEmpty, "Test sent requests without a stub: \(sent)")
        AgeWallet(config: makeConfig()).clearVerification()
        super.tearDown()
    }
}

/// Config with client ID "test-client", redirect URI https://example.com/callback and the default endpoints.
func makeConfig(metadata: String? = nil, endpoints: AgeWalletEndpoints = AgeWalletEndpoints()) -> AgeWalletConfig {
    AgeWalletConfig(
        clientId: "test-client",
        redirectUri: "https://example.com/callback",
        endpoints: endpoints,
        metadata: metadata
    )
}

/// True when the whole of `value` matches the regular expression `pattern`.
func fullyMatches(_ value: String, _ pattern: String) -> Bool {
    value.range(of: "^\(pattern)$", options: .regularExpression) != nil
}
