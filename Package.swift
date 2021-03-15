// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MughalPublishPlugin",
    products: [
        .library(
            name: "MughalPublishPlugin",
            targets: ["MughalPublishPlugin"]),
    ],
    dependencies: [
        .package(name: "Publish", url: "https://github.com/johnsundell/publish.git", from: "0.7.0"),
        .package(name: "Mughal", url: "https://github.com/Cordt/mughal.git", .branch("main")),
    ],
    targets: [
        .target(
            name: "MughalPublishPlugin",
            dependencies: ["Publish", "Mughal"]),
        .testTarget(
            name: "MughalPublishPluginTests",
            dependencies: ["MughalPublishPlugin"]),
    ]
)
