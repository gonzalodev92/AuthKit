import Foundation

/// A signed-in user's identity — the only shape the rest of a host app should ever consume.
/// Deliberately minimal and Firebase-agnostic: no `FirebaseAuth.User`, no provider-specific
/// fields. Hosts map their own richer profile (avatar, gamification, etc.) from `uid`
/// separately; this type only carries what every provider (Google, Apple) actually gives you.
public struct AuthenticatedUser: Equatable, Sendable {
    public let uid: String
    public let email: String?
    public let displayName: String?

    public init(uid: String, email: String?, displayName: String?) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
    }
}

/// Deterministic auth state for root-screen gating — distinguishes "Firebase hasn't reported
/// back yet" from "confirmed signed out", so a host can avoid flashing the wrong root screen
/// while the SDK is still resolving a persisted session at launch.
public enum AuthState: Equatable, Sendable {
    case loading
    case signedOut
    case signedIn(AuthenticatedUser)

    public var user: AuthenticatedUser? {
        if case .signedIn(let user) = self { return user }
        return nil
    }
}
