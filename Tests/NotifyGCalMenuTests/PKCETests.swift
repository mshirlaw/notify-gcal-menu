import XCTest
@testable import NotifyGCalMenu

final class PKCETests: XCTestCase {

    func testRandomURLSafeStringContainsNoUnsafeCharacters() {
        let value = PKCE.randomURLSafeString()

        XCTAssertFalse(value.contains("+"))
        XCTAssertFalse(value.contains("/"))
        XCTAssertFalse(value.contains("="))
    }

    func testRandomURLSafeStringLengthMatchesByteCount() {
        // 32 bytes of base64 is 44 characters with padding; one "=" is stripped for 32 bytes.
        let value = PKCE.randomURLSafeString(byteCount: 32)

        XCTAssertEqual(value.count, 43)
    }

    func testRandomURLSafeStringIsNotDeterministic() {
        let first = PKCE.randomURLSafeString()
        let second = PKCE.randomURLSafeString()

        XCTAssertNotEqual(first, second)
    }

    func testCodeChallengeMatchesRFC7636TestVector() {
        // The official verifier/challenge pair from RFC 7636 Appendix B.
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

        let challenge = PKCE.codeChallenge(forVerifier: verifier)

        XCTAssertEqual(challenge, "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testCodeChallengeIsDeterministicForTheSameVerifier() {
        let verifier = "some-fixed-verifier-value"

        XCTAssertEqual(PKCE.codeChallenge(forVerifier: verifier), PKCE.codeChallenge(forVerifier: verifier))
    }
}
