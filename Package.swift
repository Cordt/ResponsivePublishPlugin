// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "ResponsivePublishPlugin",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "ResponsivePublishPlugin",
            targets: ["ResponsivePublishPlugin"]),
    ],
    dependencies: [
      .package(name: "Publish", url: "https://github.com/johnsundell/publish.git", "0.7.0"..."0.8.0"),
        .package(name: "SwiftGD", url: "https://github.com/twostraws/SwiftGD.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "ResponsivePublishPlugin",
            dependencies: ["Publish", "SwiftGD"]),
        .testTarget(
            name: "ResponsivePublishPluginTests",
            dependencies: ["ResponsivePublishPlugin"]),
    ]
)
