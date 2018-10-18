// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Cglfw",
    pkgConfig: "glfw3",
    providers: [
        .apt(["libglfw3"]),
        .apt(["libglfw3-dev"])
    ]
)

