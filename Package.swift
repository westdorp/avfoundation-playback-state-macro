// swift-tools-version: 6.2
// Requires Swift 6.2 toolchain (Xcode 26+ SDKs).

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "PlaybackState",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(name: "PlaybackState", targets: ["PlaybackState"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.6.4"),
    ],
    targets: [
        .target(
            name: "PlaybackStateMacroPluginUtilities",
            dependencies: [
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                        ],
            path: "Sources/MacroPluginUtilities"
        ),

        .macro(
            name: "PlaybackStateMacroPlugin",
            dependencies: [
                "PlaybackStateMacroPluginUtilities",
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "PlaybackState",
            dependencies: ["PlaybackStateMacroPlugin"]
        ),

        .testTarget(
            name: "MacroPluginUtilitiesTests",
            dependencies: [
                "PlaybackStateMacroPluginUtilities",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        .testTarget(
            name: "PlaybackStateTests",
            dependencies: [
                "PlaybackState",
                "PlaybackStateMacroPlugin",
                .product(name: "MacroTesting", package: "swift-macro-testing"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
    ]
)
