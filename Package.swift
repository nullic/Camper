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
        .package(url: "https://github.com/apple/swift-syntax.git", from: "602.0.0"),
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
    ]
)
