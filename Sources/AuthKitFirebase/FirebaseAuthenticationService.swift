import AuthKit
import Combine
import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import OSLog
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AuthKitFirebase", category: "FirebaseAuth")

extension AuthenticatedUser {
    init(from user: FirebaseAuth.User) {
        self.init(uid: user.uid, email: user.email, displayName: user.displayName)
    }
}

/// The one place `Auth.auth()`/`FirebaseAuth.User`/`GIDSignIn` are referenced — every other
/// call site (views, coordinators) only ever sees `AuthenticationServiceProtocol`,
/// `AuthenticatedUser`, `AuthState`. Always resolves the **default** `FirebaseApp` (Firebase's
/// own ambient `Auth.auth()`) — never a named secondary app; a host with a Shared Content
/// app must never construct this against it.
///
/// A host's own post-sign-in side effects (bootstrapping/syncing its own Firestore user
/// document, hydrating locally-cached profile fields, etc.) are injected as closures rather
/// than baked in here, so this stays a pure Firebase/Google/Apple adapter:
/// - `onSignedIn` fires once after an *interactive* sign-in completes (Google or Apple).
/// - `onAuthStateChanged` fires on every `addStateDidChangeListener` callback that reports a
///   signed-in uid — including a session restored at launch, not just interactive sign-in.
public final class FirebaseAuthenticationService: AuthenticationServiceProtocol, @unchecked Sendable {

    private let userSubject: CurrentValueSubject<AuthenticatedUser?, Never>
    private let stateSubject: CurrentValueSubject<AuthState, Never>
    private var stateListenerHandle: AuthStateDidChangeListenerHandle?
    private let onSignedIn: (AuthenticatedUser) async -> Void
    private let onAuthStateChanged: (String) async -> Void

    public var authStatePublisher: AnyPublisher<AuthenticatedUser?, Never> { userSubject.eraseToAnyPublisher() }
    public var authStateStatePublisher: AnyPublisher<AuthState, Never> { stateSubject.eraseToAnyPublisher() }
    public var currentUser: AuthenticatedUser? { userSubject.value }
    public var authState: AuthState { stateSubject.value }

    public init(
        onSignedIn: @escaping (AuthenticatedUser) async -> Void = { _ in },
        onAuthStateChanged: @escaping (String) async -> Void = { _ in }
    ) {
        self.onSignedIn = onSignedIn
        self.onAuthStateChanged = onAuthStateChanged

        let initial = Auth.auth().currentUser.map(AuthenticatedUser.init)
        userSubject = CurrentValueSubject(initial)
        stateSubject = CurrentValueSubject(.loading)

        stateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self else { return }
            let user = firebaseUser.map(AuthenticatedUser.init)
            self.userSubject.send(user)
            self.stateSubject.send(user.map(AuthState.signedIn) ?? .signedOut)
            if let uid = firebaseUser?.uid {
                Task { await self.onAuthStateChanged(uid) }
            }
        }
    }

    deinit {
        if let handle = stateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Sign In with Google

    public func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthenticationError.missingClientID
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let rootVC = await rootViewController() else {
            throw AuthenticationError.noRootViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthenticationError.cancelled
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )

        let authResult = try await Auth.auth().signIn(with: credential)
        let user = AuthenticatedUser(from: authResult.user)
        logger.debug("[FirebaseAuth] Google Sign-In succeeded uid=\(user.uid, privacy: .public) email=\(user.email ?? "nil", privacy: .public)")

        await onSignedIn(user)
    }

    // MARK: - Sign In with Apple

    /// `idToken`/`rawNonce`/`fullName` are already extracted by the UI layer from a real
    /// `ASAuthorizationAppleIDCredential` (this package never imports `AuthenticationServices`
    /// itself) — `rawNonce` must be the exact unhashed value whose SHA256 was set on the
    /// original `ASAuthorizationAppleIDRequest.nonce` (see `AppleSignInNonce`).
    public func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {
        let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: rawNonce, fullName: fullName)
        let authResult = try await Auth.auth().signIn(with: credential)

        // Apple only ever returns the user's name on the *first* authorization for this app —
        // Firebase's own profile won't have it yet on that first sign-in, so backfill it here,
        // the same way displayName would already be present for Google.
        if authResult.user.displayName == nil, let fullName, !fullName.isEmptyName {
            let changeRequest = authResult.user.createProfileChangeRequest()
            changeRequest.displayName = PersonNameComponentsFormatter().string(from: fullName)
            try? await changeRequest.commitChanges()
        }

        let user = AuthenticatedUser(from: Auth.auth().currentUser ?? authResult.user)
        logger.debug("[FirebaseAuth] Apple Sign-In succeeded uid=\(user.uid, privacy: .public)")

        await onSignedIn(user)
    }

    // MARK: - Sign Out

    public func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        logger.debug("[FirebaseAuth] signed out")
    }

    // MARK: - Delete Account

    public func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.delete()
        logger.debug("[FirebaseAuth] account deleted")
    }

    // MARK: - Private Helpers

    @MainActor
    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            .flatMap { $0.windows.first(where: { $0.isKeyWindow }) }?
            .rootViewController
    }
}

private extension PersonNameComponents {
    var isEmptyName: Bool {
        givenName == nil && familyName == nil && middleName == nil && namePrefix == nil && nameSuffix == nil && nickname == nil
    }
}
