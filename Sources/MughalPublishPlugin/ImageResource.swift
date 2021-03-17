//
//  ImageResource.swift
//  MughalPublishPlugin
//
//  Created by Cordt Zermin on 14.03.21.
//

import Foundation
import Publish
import Files
import Mughal


struct ImageRewrite: Equatable {
    struct ImageUrl: Equatable {
        let path: Path
        /// File name including any suffixes (for sizes)
        let fileName: String
        let `extension`: Image.Extension

        var filePath: String { "\(path)/\(fileName).\(`extension`.rawValue)" }
        
        init(
            path: Path,
            fileName: String,
            `extension`: Image.Extension
        ) {
            var pathString = path.absoluteString.drop(while: { $0 == "/" })
            pathString = pathString.dropLast(pathString.last == "/" ? 1 : 0)
            self.path = Path("\(pathString)")
            self.fileName = fileName
            self.`extension` = `extension`
        }
    }

    let source: ImageUrl
    let target: ImageUrl
    let targetSizeClass: SizeClass

    var variableName: String { "--\(source.fileName)-img-url" }
}

/// Reflects 'natural' css breakpoints
///
/// See this article by David Gilbertson for reference: [The correct way to do css breakpoints](https://www.freecodecamp.org/news/the-100-correct-way-to-do-css-breakpoints-88d6a5ba1862/)
/// extraLarge is not covered, as the images are defined by their upper bound, which this size class does not have by default
enum SizeClass: String, CaseIterable {
    case extraSmall
    case small
    case normal
    case large

    var fileSuffix: String { self.rawValue.changeCamelCase(to: .kebap) }
    var minWidth: Int {
        switch self {
        case .extraSmall:   return 0
        case .small:        return 600
        case .normal:       return 900
        case .large:        return 1200
        }
    }
    var upperBound: Int {
        switch self {
        case .extraSmall:   return 600
        case .small:        return 900
        case .normal:       return 1200
        case .large:        return 1800
        }
    }
}

func sizeClassFrom(upper bound: Int) -> SizeClass {
    sizeClassFrom(dimensions: (bound, bound))
}

func sizeClassFrom(dimensions: (Int, Int)) -> SizeClass {
    SizeClass.allCases
        .map { ($0, $0.upperBound) }
        .sorted { $0.1 < $1.1 }
        .filter { max(dimensions.0, dimensions.1) <= $0.1 }
        .map { $0.0 }
        .first ?? .extraSmall
}

extension String {
    enum SeparationStyle {
        case snake
        case kebap
    }

    func changeCamelCase(to: SeparationStyle) -> String {
        let acronymPattern = "([A-Z]+)([A-Z][a-z]|[0-9])"
        let normalPattern = "([a-z0-9])([A-Z])"
        return self
            .camel(to: to, using: acronymPattern)?
            .camel(to: to, using: normalPattern)?
            .lowercased() ?? self.lowercased()
    }

    fileprivate func camel(to: SeparationStyle, using pattern: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: count)
        let delimiter: String
        switch to {
        case .snake: delimiter = "_"
        case .kebap: delimiter = "-"
        }
        return regex?.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1\(delimiter)$2")
    }
}
