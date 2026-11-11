import XCTest
@testable import AgeWalletSDK

/// AgeWallet.handleCallback(url:) for callbacks it rejects before any network call, and the
/// verified state after clearVerification().
final class CallbackTests: NetworkBlockedTestCase {
    private func callback(_ query: String) -> URL {
        URL(string: "https://example.com/callback?\(query)")!
    }

    func testDeniedRequestReturnsDenied() async {
        let result = await AgeWallet(config: makeConfig()).handleCallback(
            url: callback("error=access_denied&error_description=The%20user%20denied%20the%20request")
        )
        XCTAssertEqual(result, .denied)
    }

    func testOtherErrorReturnsFailed() async {
        let result = await AgeWallet(config: makeConfig()).handleCallback(
            url: callback("error=server_error&error_description=Something%20went%20wrong")
        )
        XCTAssertEqual(result, .failed)
    }

    func testMissingCodeReturnsFailed() async {
        let result = await AgeWallet(config: makeConfig()).handleCallback(url: callback("state=abc"))
        XCTAssertEqual(result, .failed)
    }

    func testMissingStateReturnsFailed() async {
        let result = await AgeWallet(config: makeConfig()).handleCallback(url: callback("code=abc"))
        XCTAssertEqual(result, .failed)
    }

    func testStateThatDoesNotMatchReturnsFailed() async throws {
        let sdk = AgeWallet(config: makeConfig())
        _ = try sdk.buildVerificationURL()

        let result = await sdk.handleCallback(url: callback("code=abc&state=not-the-saved-state"))
        XCTAssertEqual(result, .failed)
    }

    func testCallbackWithNoSavedStateReturnsFailed() async {
        let sdk = AgeWallet(config: makeConfig())
        sdk.clearVerification()

        let result = await sdk.handleCallback(url: callback("code=abc&state=0123456789abcdef0123456789abcdef"))
        XCTAssertEqual(result, .failed)
    }

    func testNotVerifiedAfterClearVerification() {
        let sdk = AgeWallet(config: makeConfig())
        sdk.clearVerification()

        XCTAssertFalse(sdk.isVerified())
        XCTAssertNil(sdk.getMetadata())
    }
}
