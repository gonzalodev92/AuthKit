import Combine
import Foundation

/// The one seam a host app's UI/domain code should depend on for authentication — never
/// `Auth.auth()`/`FirebaseAuth.User` directly. A concrete `FirebaseAuthenticationService`
/// (this package) implements this against Firebase; anything consuming auth state only ever
/// sees `AuthenticatedUser`/`AuthState`.
public protocol AuthenticationServiceProtocol: AnyObject, Sendable {
    var currentUser: AuthenticatedUser? { get }
    var authState: AuthState { get }
    var authStatePublisher: AnyPublisher<AuthenticatedUser?, Never> { get }
    var authStateStatePublisher: AnyPublisher<AuthState, Never> { get }

    func signInWithGoogle() async throws
    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws
    func signOut() throws
    /// Updates the identity FirebaseAuth exposes to the host. App-private profile
    /// repositories remain responsible for their own durable profile documents.
    func updateDisplayName(_ displayName: String) async throws
    func deleteAccount() async throws
}

/// A provider-agnostic slice of an Apple ID credential's name, so this package's public API
/// never has to expose `AuthenticationServices` types (a UI layer maps `PersonNameComponents`
/// from the real `ASAuthorizationAppleIDCredential` before calling `signInWithApple`).
public typealias PersonNameComponents = Foundation.PersonNameComponents

public enum AuthenticationError: LocalizedError, Equatable, Sendable {
    case missingClientID
    case noRootViewController
    case cancelled
    case invalidAppleCredential

    public var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Firebase client ID is missing. Enable Google Sign-In in Firebase Console."
        case .noRootViewController:
            return "Could not find a root view controller to present sign-in."
        case .cancelled:
            return "Sign-in was cancelled."
        case .invalidAppleCredential:
            return "Apple Sign-In did not return a usable identity token."
        }
    }
}
