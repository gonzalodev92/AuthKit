import XCTest
@testable import AuthKit

final class AppleSignInNonceTests: XCTestCase {
    func testRandom_producesRequestedLength() {
        XCTAssertEqual(AppleSignInNonce.random(length: 32).count, 32)
        XCTAssertEqual(AppleSignInNonce.random(length: 1).count, 1)
    }

    func testRandom_producesDifferentValuesEachCall() {
        XCTAssertNotEqual(AppleSignInNonce.random(), AppleSignInNonce.random())
    }

    func testSha256_isDeterministicAndMatchesKnownVector() {
        // SHA256("") — a fixed, well-known test vector.
        XCTAssertEqual(
            AppleSignInNonce.sha256(""),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b85"
        )
        XCTAssertEqual(AppleSignInNonce.sha256("abc"), AppleSignInNonce.sha256("abc"))
    }

    func testAuthState_userIsNilUnlessSignedIn() {
        let user = AuthenticatedUser(uid: "u1", email: "a@b.com", displayName: "A")
        XCTAssertNil(AuthState.loading.user)
        XCTAssertNil(AuthState.signedOut.user)
        XCTAssertEqual(AuthState.signedIn(user).user, user)
    }
}
