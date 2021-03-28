# Responsive plugin for Publish

A [Publish](https://github.com/johnsundell/publish) plugin that uses [SwiftGD](https://github.com/twostraws/SwiftGD) Image Processing Library to generate next-gen images and rewrites the css and html files in a Publish website.

## Installation

To install it into your [Publish](https://github.com/johnsundell/publish) package, add it as a dependency within your `Package.swift` manifest:

```swift
let package = Package(
    ...
    dependencies: [
        ...
        .package(name: "ResponsivePublishPlugin", url: "https://github.com/Cordt/ResponsivePublishPlugin", .branch("main"))
    ],
    targets: [
        .target(
            ...
            dependencies: [
                ...
                "ResponsivePublishPlugin"
            ]
        )
    ]
    ...
)
```

Then import ResponsivePublishPlugin wherever you’d like to use it:

```swift
import ResponsivePublishPlugin
```

For more information on how to use the Swift Package Manager, check out [this article by John Sundell](https://www.swiftbysundell.com/articles/managing-dependencies-using-the-swift-package-manager), or [its official documentation](https://github.com/apple/swift-package-manager/tree/master/Documentation).

## Usage

The plugin can then be used within any publishing pipeline like this:

```swift
import ResponsivePublishPlugin
...
try DeliciousRecipes().publish(using: [
    ...
        .generateHTML(),
        .installPlugin(.generateOptimizedImages()),
    ...
])
```
It is important that the HTML files are generated prior to installing the plugin, otherwise they cannot be rewritten.
