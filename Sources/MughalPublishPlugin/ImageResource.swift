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
        var path: Path
        /// File name including any suffixes (for sizes)
        var fileName: String
        var `extension`: Image.Extension

        var filePath: String { "\(path)/\(fileName).\(`extension`)" }
        
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
        
        /// Checks whether the other image url is at the same location, except for being at a different relative position
        /// Returns the Path difference between the two image urls, if they point at the same location and nil, otherwise
        func contains(other: ImageUrl) -> Path? {
            guard self.fileName == other.fileName,
                  self.extension == other.extension,
                  self.path.string.count >= other.path.string.count
            else { return nil }
            
            let path1 = self.path.absoluteString
            let path2 = other.path.absoluteString

            let prefixedPath = String(path1.reversed())
            let containedPath = String(path2.reversed())

            guard path1.count != path2.count else { return Path("") }
            var pathPrefix = path1.count > path2.count ? path1: path2
            pathPrefix
                .removeLast(containedPath.commonPrefix(with: prefixedPath).count)
            pathPrefix
                .removeFirst()
            pathPrefix += "/"
            
            return Path(pathPrefix)
        }
    }

    var source: ImageUrl
    var target: ImageUrl
    var targetSizeClass: SizeClass
    var variableNameSuffix: String? = nil

    var variableName: String {
        let suffix = variableNameSuffix != nil ? "-\(variableNameSuffix!)" : ""
        return "--\(source.fileName)\(suffix)-img-url" }
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
