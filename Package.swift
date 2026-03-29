// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PelicanCon",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "PelicanCon", targets: ["PelicanCon"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk",
            from: "10.25.0"
        ),
        .package(
            url: "https://github.com/google/GoogleSignIn-iOS",
            from: "7.1.0"
        ),
    ],
    targets: [
        .target(
            name: "PelicanCon",
            dependencies: [
                .product(name: "FirebaseAuth",        package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore",   package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage",     package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging",   package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions",   package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn",        package: "GoogleSignIn-iOS"),
            ],
            path: "Sources/PelicanCon",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
