// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftTA-OpenGL3",
    platforms: [
        .macOS(.v10_12),
        .iOS(.v11),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "SwiftTA-OpenGL3",
            targets: ["SwiftTA-OpenGL3"]),
    ],
    dependencies: [
        .package(path: "../SwiftTA-Core"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "SwiftTA-OpenGL3",
            dependencies: ["SwiftTA-Core"]),
        .testTarget(
            name: "SwiftTA-OpenGL3Tests",
            dependencies: ["SwiftTA-Core"]),
    ]
)
