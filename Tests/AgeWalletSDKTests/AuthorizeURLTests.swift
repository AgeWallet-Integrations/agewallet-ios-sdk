import XCTest
@testable import AgeWalletSDK

/// The authorize URL from AgeWallet.buildVerificationURL(metadata:) and the metadata limit.
final class AuthorizeURLTests: NetworkBlockedTestCase {
    private func queryItems(_ url: URL) -> [URLQueryItem] {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }

    private func value(_ name: String, in url: URL) -> String? {
        queryItems(url).first { $0.name == name }?.value
    }

    func testURLCarriesTheEightOIDCParameters() throws {
        let url = try AgeWallet(config: makeConfig()).buildVerificationURL()

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "app.agewallet.io")
        XCTAssertEqual(url.path, "/user/authorize")
        XCTAssertEqual(
            queryItems(url).map { $0.name },
            ["response_type", "client_id", "redirect_uri", "scope", "state", "code_challenge", "code_challenge_method", "nonce"]
        )
        XCTAssertEqual(value("response_type", in: url), "code")
        XCTAssertEqual(value("client_id", in: url), "test-client")
        XCTAssertEqual(value("redirect_uri", in: url), "https://example.com/callback")
        XCTAssertEqual(value("scope", in: url), "openid age")
        XCTAssertEqual(value("code_challenge_method", in: url), "S256")
        XCTAssertTrue(fullyMatches(value("state", in: url) ?? "", "[0-9a-f]{32}"))
        XCTAssertTrue(fullyMatches(value("nonce", in: url) ?? "", "[0-9a-f]{32}"))
        XCTAssertTrue(fullyMatches(value("code_challenge", in: url) ?? "", "[A-Za-z0-9_-]{43}"))
    }

    func testCustomAuthEndpointSetsTheHostAndPath() throws {
        let endpoints = AgeWalletEndpoints(
            auth: "https://aw.test/custom/authorize",
            token: "https://aw.test/custom/token",
            userinfo: "https://aw.test/custom/userinfo"
        )
        let url = try AgeWallet(config: makeConfig(endpoints: endpoints)).buildVerificationURL()

        XCTAssertEqual(url.host, "aw.test")
        XCTAssertEqual(url.path, "/custom/authorize")
    }

    func testEachURLHasItsOwnStateNonceAndChallenge() throws {
        let sdk = AgeWallet(config: makeConfig())
        let first = try sdk.buildVerificationURL()
        let second = try sdk.buildVerificationURL()

        for name in ["state", "nonce", "code_challenge"] {
            XCTAssertNotEqual(value(name, in: first), value(name, in: second), name)
        }
    }

    func testEmptyMetadataIsLeftOut() throws {
        let url = try AgeWallet(config: makeConfig(metadata: "")).buildVerificationURL()
        XCTAssertNil(value("metadata", in: url))
    }

    func testMetadataWithSpacesAmpersandsEqualsAndAccentsComesBackWhole() throws {
        let metadata = "tenant & co = 1 caf\u{E9}"
        let url = try AgeWallet(config: makeConfig(metadata: metadata)).buildVerificationURL()

        XCTAssertEqual(value("metadata", in: url), metadata)
        XCTAssertEqual(queryItems(url).count, 9)
    }

    func testMetadataLimitCountsUTF8Bytes() throws {
        let sdk = AgeWallet(config: makeConfig())
        // "\u{E9}" (é) is 2 bytes in UTF-8
        let atLimit = String(repeating: "\u{E9}", count: AgeWallet.metadataMaxBytes / 2)
        XCTAssertEqual(atLimit.utf8.count, AgeWallet.metadataMaxBytes)

        XCTAssertNoThrow(try sdk.setMetadata(atLimit))
        XCTAssertThrowsError(try sdk.setMetadata(atLimit + "a")) { error in
            guard case AgeWalletError.invalidMetadata = error else {
                return XCTFail("Expected invalidMetadata, got \(error)")
            }
        }
    }

    func testSetMetadataNilClearsTheDefault() throws {
        let sdk = AgeWallet(config: makeConfig(metadata: "tenant-abc"))
        try sdk.setMetadata(nil)

        XCTAssertNil(value("metadata", in: try sdk.buildVerificationURL()))
    }
}
