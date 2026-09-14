// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AuthKit",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "AuthKit", targets: ["AuthKit"]),
        .library(name: "AuthKitUI", targets: ["AuthKitUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "11.0.0")),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", .upToNextMajor(from: "8.0.0")),
        .package(url: "https://github.com/gonzalodev92/AppDesignKit.git", branch: "main")
    ],
    targets: [
        .target(
            name: "AuthKit",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")
            ]
        ),
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
