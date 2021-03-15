# Mughal plugin for Publish

A [Publish](https://github.com/johnsundell/publish) plugin that leverages [Mughal](https://github.com/Cordt/Mughal) Image Processing Library to generate next-gen images and rewrites the css files in a Publish website.

## Installation

To install it into your [Publish](https://github.com/johnsundell/publish) package, add it as a dependency within your `Package.swift` manifest:

```swift
let package = Package(
    ...
    dependencies: [
        ...
        .package(name: "Mughal", url: "https://github.com/Cordt/Mughal", .branch("main"))
    ],
    targets: [
        .target(
            ...
            dependencies: [
                ...
                "MughalPublishPlugin"
            ]
        )
    ]
    ...
)
```

Then import MughalPublishPlugin wherever you’d like to use it:

```swift
import MughalPublishPlugin
```

For more information on how to use the Swift Package Manager, check out [this article by John Sundell](https://www.swiftbysundell.com/articles/managing-dependencies-using-the-swift-package-manager), or [its official documentation](https://github.com/apple/swift-package-manager/tree/master/Documentation).

## Usage

The plugin can then be used within any publishing pipeline like this:

```swift
import MughalPublishPlugin
...
try DeliciousRecipes().publish(using: [
        .installPlugin(.generateOptimizedImages()),
    ...
])
```
