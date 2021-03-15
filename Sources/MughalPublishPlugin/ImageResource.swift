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

// TODO: Align image extensions between the packages (ideally the extensions are in Mughal only)
// TODO: Align size classes between the packages (ideally the size classes are in the Plugin only)
struct ImageRewrite: Equatable {
    struct ImageUrl: Equatable {
        let path: Path
        let fileName: String
        let `extension`: FileExtension

        var filePath: String { "\(path)/\(fileName).\(`extension`.rawValue)" }
        
        init(
            path: Path,
            fileName: String,
            `extension`: FileExtension
        ) {
            var pathString = path.absoluteString.drop(while: { $0 == "/" })
            pathString = pathString.dropLast(pathString.last == "/" ? 1 : 0)
            self.path = Path("\(pathString)")
            self.fileName = fileName
            self.`extension` = `extension`
        }
    }

    enum FileExtension: String, Equatable {
        case jpg
        case webp
        
        init(from: Image.Extension) {
            switch from {
            case .webP: self = .webp
            }
        }
    }

    let source: ImageUrl
    let target: ImageUrl

    var variableName: String { "--\(source.fileName)-img-url" }
}

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
