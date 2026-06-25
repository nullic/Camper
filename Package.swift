// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Camper",
    platforms: [.macOS(.v14), .iOS(.v17), .macCatalyst(.v17)],
    products: [
        .library(name: "Camper", targets: ["Camper"]),
        .executable(name: "CamperClient", targets: ["CamperClient"]),
    ],
    dependencies: [
        // Widened from `602.0.0` to span 600…602 so Camper can co-resolve
        // with deps that pin swift-syntax 600 (e.g. mlx-swift-lm via
        // mlx-audio-swift). SPM picks the highest version satisfying the
        // whole graph — 602 alone, 600 when a 600-pinned dep is present.
        .package(url: "https://github.com/apple/swift-syntax.git", "600.0.0" ..< "603.0.0"),
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", from: "2.0.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
    ],
    targets: [
        .macro(
            name: "CamperMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        .target(name: "Camper", dependencies: [
            "CamperMacros",
            .product(name: "SwiftyBeaver", package: "SwiftyBeaver"),
            .product(name: "ZIPFoundation", package: "ZIPFoundation"),
        ]),

        .executableTarget(name: "CamperClient", dependencies: ["Camper"]),

        .testTarget(name: "CamperMacrosTests", dependencies: [
            "CamperMacros",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
        ]),

        .testTarget(name: "CamperTests", dependencies: ["Camper"]),
    ]
)
