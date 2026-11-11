import XCTest
@testable import AgeWalletSDK

/// PKCE verifier and challenge, state and nonce, and Base64-URL encoding (Sources/AgeWalletSDK/Security.swift).
final class SecurityTests: XCTestCase {
    func testChallengeMatchesTheRFC7636Example() {
        // RFC 7636 Appendix B: code_verifier and its S256 code_challenge
        XCTAssertEqual(
            Security.generateChallenge(from: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        )
    }

    func testVerifierIs43Base64URLCharacters() {
        let verifier = Security.generateVerifier()
        XCTAssertTrue(fullyMatches(verifier, "[A-Za-z0-9_-]{43}"), verifier)
    }

    func testVerifiersDiffer() {
        XCTAssertNotEqual(Security.generateVerifier(), Security.generateVerifier())
    }

    func testStateAndNonceAre32LowercaseHexCharacters() {
        for value in [Security.generateState(), Security.generateNonce()] {
            XCTAssertTrue(fullyMatches(value, "[0-9a-f]{32}"), value)
        }
    }

    func testStatesDiffer() {
        XCTAssertNotEqual(Security.generateState(), Security.generateState())
    }

    func testBase64URLEncodingReplacesPlusAndSlashAndDropsPadding() {
        // Base64 of these bytes is "+/+/" and "/w=="
        XCTAssertEqual(Data([0xfb, 0xff, 0xbf]).base64URLEncodedString(), "-_-_")
        XCTAssertEqual(Data([0xff]).base64URLEncodedString(), "_w")
    }
}
