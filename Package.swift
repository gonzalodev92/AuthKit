// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AuthKit",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "AuthKit", targets: ["AuthKit"]),
        .library(name: "AuthKitFirebase", targets: ["AuthKitFirebase"]),
        .library(name: "AuthKitUI", targets: ["AuthKitUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "11.0.0")),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", .upToNextMajor(from: "8.0.0")),
        .package(url: "https://github.com/gonzalodev92/AppDesignKit.git", branch: "main")
    ],
    targets: [
        // Pure domain: AuthenticatedUser, AuthState, AuthenticationServiceProtocol,
        // AuthenticationError, AppleSignInNonce. No Firebase, no GoogleSignIn — every host
        // (and every consumer, including test targets that only need the types/a stub) can
        // depend on just this, with zero third-party linkage.
        .target(name: "AuthKit"),
        // The one Firebase/GoogleSignIn adapter — FirebaseAuthenticationService. Depends on
        // AuthKit (the protocol/types it implements), never the other way around.
        .target(
            name: "AuthKitFirebase",
            dependencies: [
                "AuthKit",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")
            ]
        ),
        // The shared auth sheet. Deliberately depends on AuthKit only (never
        // AuthKitFirebase/Firebase/GoogleSignIn directly) — it only calls host-supplied
        // closures and AuthKit's own AppleSignInNonce, so a host wiring it to
        // AuthKitFirebase's service is a one-line pass-through, not a hard dependency this
        // package needs itself.
        .target(
            name: "AuthKitUI",
            dependencies: [
                "AuthKit",
                .product(name: "AppDesignKit", package: "AppDesignKit")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(name: "AuthKitTests", dependencies: ["AuthKit"])
    ]
)
