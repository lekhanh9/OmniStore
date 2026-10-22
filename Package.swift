// swift-tools-version: 5.9
import PackageDescription

var dependencies: [Package.Dependency] = [
    .package(path: "../ghost-code"),
    .package(path: "../ghost-sign"),
    .package(path: "../minimuxer"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
]

var products: [Product] = [
    .library(name: "OmnistoreKit", targets: ["OmnistoreKit"]),
    .executable(name: "omnistore", targets: ["OmnistoreCLI"]),
]

var targets: [Target] = [
    .target(
        name: "OmnistoreKit",
        dependencies: [
            .product(name: "GhostSign", package: "ghost-sign"),
            .product(name: "GhostCode", package: "ghost-code"),
            .product(name: "Minimuxer", package: "minimuxer", condition: .when(platforms: [.iOS])),
            .product(name: "Crypto", package: "swift-crypto"),
            .product(name: "ZIPFoundation", package: "ZIPFoundation"),
        ],
        path: "Sources/OmnistoreKit"
    ),
    .executableTarget(
        name: "OmnistoreCLI",
        dependencies: ["OmnistoreKit"],
        path: "Sources/OmnistoreCLI"
    ),
    .testTarget(
        name: "OmnistoreKitTests",
        dependencies: [
            "OmnistoreKit",
            .product(name: "ZIPFoundation", package: "ZIPFoundation"),
        ],
        path: "Tests/OmnistoreKitTests"
    ),
]

// The SwiftUI application is compiled by the Xcode project in `OmniStore.xcodeproj`.
// SwiftPM deliberately builds only the portable core and CLI here.
let package = Package(
    name: "Omnistore",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: products,
    dependencies: dependencies,
    targets: targets
)
