import CryptoKit
import Foundation

/// Nonce generation for Sign in with Apple's replay-protection contract: the raw nonce is
/// handed to `ASAuthorizationAppleIDRequest.nonce` as its SHA256 hash (`sha256(_:)` below),
/// and the same raw value is later passed to Firebase's `OAuthProvider.credential` alongside
/// the identity token it signed. A UI layer generates one raw nonce per presentation, hashes
/// it into the request, and passes the *raw* value through to `signInWithApple`.
public enum AppleSignInNonce {
    public static func random(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            precondition(status == errSecSuccess, "SecRandomCopyBytes failed with status \(status)")

            for byte in randomBytes where remaining > 0 {
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    public static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
