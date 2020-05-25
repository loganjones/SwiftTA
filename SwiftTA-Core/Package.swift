// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftTA-Core",
    platforms: [
        .macOS(.v10_12),
        .iOS(.v11),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "SwiftTA-Core",
            targets: ["SwiftTA-Core"]),
    ],
    dependencies: [
        .package(path: "../SwiftTA-Ctypes"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "SwiftTA-Core",
            dependencies: ["SwiftTA-Ctypes"]),
        .testTarget(
            name: "SwiftTA-CoreTests",
            dependencies: ["SwiftTA-Core"]),
    ]
)
