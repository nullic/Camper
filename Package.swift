// swift-tools-version: 6.0
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
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0" ..< "604.0.0"),
    ],
    targets: [
        .macro(
            name: "CamperMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        .target(name: "Camper", dependencies: ["CamperMacros"]),

        .executableTarget(name: "CamperClient", dependencies: ["Camper"]),

        .testTarget(name: "CamperMacrosTests", dependencies: [
            "CamperMacros",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
        ]),

        .testTarget(name: "CamperTests", dependencies: ["Camper"]),
    ]
)
