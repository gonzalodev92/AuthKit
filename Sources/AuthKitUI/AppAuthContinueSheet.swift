import AppDesignKit
import AuthenticationServices
import AuthKit
import SwiftUI

/// The canonical "continue with Apple / continue with Google" auth sheet — ported verbatim
/// from Niko's `ProfileAuthSheet`/`GoogleContinueButton` (same padding, detent, drag
/// indicator, button styling; the system's own native Liquid Glass sheet material, no
/// second background/corner-radius layering of its own). A host presents this via a plain
/// `.sheet(isPresented:) { AppAuthContinueSheet(...) }` and supplies only semantic
/// content — title, subtitle, and what a successful/failed sign-in means to it — never
/// spacing, radius, or font.
///
/// Owns the full Sign in with Apple nonce lifecycle (`AppleSignInNonce`) internally, so a
/// host never has to think about it: generates a fresh raw nonce per appearance, hashes it
/// into the `ASAuthorizationAppleIDRequest`, and hands the raw nonce + extracted identity
/// token + name back to `onAppleSignIn` — a straight pass-through to
/// `AuthenticationServiceProtocol.signInWithApple(idToken:rawNonce:fullName:)`.
public struct AppAuthContinueSheet: View {
    @Environment(\.appDesignTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let title: String
    private let subtitle: String
    private let onAppleSignIn: (String, String, PersonNameComponents?) -> Void
    private let onAppleSignInFailed: (Error) -> Void
    private let onContinueWithGoogle: () -> Void

    @State private var currentAppleNonce = AppleSignInNonce.random()

    public init(
        title: String,
        subtitle: String,
        onAppleSignIn: @escaping (_ idToken: String, _ rawNonce: String, _ fullName: PersonNameComponents?) -> Void,
        onAppleSignInFailed: @escaping (Error) -> Void = { _ in },
        onContinueWithGoogle: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onAppleSignIn = onAppleSignIn
        self.onAppleSignInFailed = onAppleSignInFailed
        self.onContinueWithGoogle = onContinueWithGoogle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(theme.colors.primaryText)

                Text(subtitle)
                    .font(AppTypography.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.colors.secondaryText.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleSignInNonce.sha256(currentAppleNonce)
                } onCompletion: { result in
                    handleAppleCompletion(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .light ? .black : .white)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                AppGoogleContinueButton {
                    onContinueWithGoogle()
                    dismiss()
                }
                .frame(height: 50)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            onAppleSignInFailed(error)
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                onAppleSignInFailed(AuthenticationError.invalidAppleCredential)
                return
            }
            onAppleSignIn(idToken, currentAppleNonce, credential.fullName)
            dismiss()
        }
        // A fresh nonce for the next time this sheet is presented — a used nonce must never
        // be replayed against a second credential exchange.
        currentAppleNonce = AppleSignInNonce.random()
    }
}

/// The exact "G" logo + white pill button `ProfileView+AccountSection.swift`'s
/// `GoogleContinueButton` already used — same colors/corner radius/border, public so any
/// host can reuse it standalone (e.g. inside its own onboarding flow) without pulling in
/// the whole sheet.
public struct AppGoogleContinueButton: View {
    @Environment(\.appDesignTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image("google-g", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)

                Text("Continue with Google")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.12))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(theme.colors.separator.opacity(colorScheme == .light ? 0.9 : 0.18), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
