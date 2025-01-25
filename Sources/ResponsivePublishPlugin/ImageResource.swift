//
//  ImageResource.swift
//  ResponsivePublishPlugin
//
//  Created by Cordt Zermin on 14.03.21.
//

import Foundation
import Publish
import Files
import SwiftGD

enum ImageFormat: String, Equatable {
    case bmp
    case gif
    case jpg
    case png
    case tiff
    case webp
    
    var importableFormat: ImportableFormat {
        switch self {
        case .bmp: return .bmp
        case .gif: return .gif
        case .jpg: return .jpg
        case .png: return .png
        case .tiff: return .tiff
        case .webp: return .webp
        }
    }
    
    var exportableFormat: ExportableFormat {
        switch self {
        case .bmp: return .bmp(compression: true)
        case .gif: return .gif
        case .jpg: return .jpg(quality: 75)
        case .png: return .png
        case .tiff: return .tiff
        case .webp: return .webp
        }
    }
}


/// Represents the desired configuration of the target image
struct ImageConfiguration {
    let url: URL
    let fileName: String
    let `extension`: ImageFormat
    let relativePath: Path
    let targetExtension: ImageFormat
    let targetSizes: [SizeClass]
    
    init?(url: URL, resourcesLocation: Path, targetExtension: ImageFormat, targetSizes: [SizeClass]) {
        let lastComponents = url.lastPathComponent.split(separator: ".")
        guard let fileName = lastComponents.first.map(String.init),
              let `extension` = lastComponents.last.map(String.init),
              let importableFormat = ImageFormat.init(rawValue: `extension`)
        else { return nil }
        
        self.url = url
        self.fileName = fileName
        self.extension = importableFormat
        self.relativePath = relativeSourcePath(in: url.absoluteString, for: resourcesLocation.string, and: "\(fileName).\(`extension`)")
        self.targetExtension = targetExtension
        self.targetSizes = targetSizes
    }
    
    func fileName(for sizeClass: SizeClass) -> String {
        "\(self.fileName)-\(sizeClass.fileSuffix)"
    }
}

struct ExportableImage {
    /// Name of the file (w/o file extension)
    let relativeOutputFolderPath: Path
    let name: String
    let `extension`: ImageFormat
    let image: Image
    /// Name of the file including the file extension
    var fullFileName: String {
        return "\(name).\(`extension`)"
    }
}

struct ImageRewrite: Equatable {
    struct ImageUrl: Equatable {
        var path: Path
        /// File name including any suffixes (for sizes)
        var fileName: String
        var `extension`: ImageFormat
        
        var filePath: String { "\(path)/\(fileName).\(`extension`)" }
        
        init(
            path: Path,
            fileName: String,
            `extension`: ImageFormat
        ) {
            var pathString = path.string
            pathString = String(pathString.dropLast(pathString.last == "/" ? 1 : 0))
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
            
            let path1 = self.path.string
            let path2 = other.path.string
            
            let prefixedPath = String(path1.reversed())
            let containedPath = String(path2.reversed())
            
            guard path1.count != path2.count else { return Path("") }
            var pathPrefix = path1.count > path2.count ? path1 : path2
            let commonPathLength = containedPath.commonPrefix(with: prefixedPath).count
            pathPrefix.removeLast(commonPathLength)
            
            return Path(pathPrefix)
        }
        
        /// Counts the number of parent directory hops, before going into the directory structure
        /// That is, the function counts the number of '../'
        func noOfParentDirectories() -> Int {
            var counter = 0
            var path = self.filePath
            while path.count > 3 && path.dropLast(path.count - 3) == "../" {
                counter += 1
                path = String(path.dropFirst(3))
            }
            return counter
        }

        /// Removes one directory from the beginning of the path for each number of hops indicated
        /// Adds one parent directory hop at the beginning ('../') instead
        func preprendingParentDirectories(number: Int) -> Path {
            guard number > 0 else { return self.path }
            
            var path = self.path.absoluteString
            if !path.contains("/") { return Path("..") }
            if path.first == "/" { path.removeFirst() }
            for _ in 1 ... number {
                // Need to check this again, in case the path has a leading slash, but not a trailing one
                if !path.contains("/") { return Path("..") }
                path = String(path.drop { $0 != "/" })
                path.removeFirst()
            }
            for _ in 1 ... number {
                path = "../" + path
            }
            return Path(path)
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

func rewrites(from source: Path, to target: Path, for config: ImageConfiguration) -> [ImageRewrite] {
    config.targetSizes.map { size in
        ImageRewrite(
            source: .init(path: source.appendingComponent(config.relativePath.string), fileName: config.fileName, extension: config.extension),
            target: .init(path: target.appendingComponent(config.relativePath.string), fileName: config.fileName(for: size), extension: config.targetExtension),
            targetSizeClass: size
        )
    }
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


/// Calculates Image dimensions within a given upper bound
///
/// The greater of the two dimensions will assume the upper bound
func sizeThatFits(for original: Size, within upperBound: Int) -> Size {
    let factor: Float
    if original.width >= original.height {
        factor = Float(upperBound) / Float(original.width)
    } else {
        factor = Float(upperBound) / Float(original.height)
    }
    return Size(
        width: Int(Float(original.width) * factor),
        height: Int(Float(original.height) * factor)
    )
}


/// Extracts the path of the file, relative to the base path in the project
///
/// For example
/// Base path of the images: `Resources/assets/img`
/// Path of this image: `Resources/assets/img/subfolder/sub-background.jpg`
/// Function will return: `subfolder/`
///
func relativeSourcePath(in urlPath: String, for location: String, and fileName: String) -> Path {
    let pattern = ".*\(location)(.*)\(fileName)$"
    do {
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let stringRange = NSRange(location: 0, length: urlPath.utf16.count)
        let matches = regex.matches(in: urlPath, range: stringRange)
        guard let match = matches.first, match.numberOfRanges == 2
        else { return Path("") }
        
        let range = match.range(at: 1)
        let path = (urlPath as NSString).substring(with: range)
        return Path(String(path.dropLast(path.last == "/" ? 1 : 0)))
        
    } catch let error {
        print(error)
        return Path("")
    }
}
