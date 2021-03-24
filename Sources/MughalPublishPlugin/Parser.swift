//
//  Parser.swift
//  MughalPublishPlugin
//
//  Created by Cordt Zermin on 20.03.21.
//

import Foundation
import Publish
import Mughal


fileprivate let imagePathPattern: String = #"url\(['"]?((\.\.\/|[A-Za-z-_\+\d]+\/)*)([A-Za-z-_\+\d]*).(jpg|png){1}['"]?\);"#

func imageUrls(from: String) -> [ImageRewrite.ImageUrl] {
    do {
        let regex = try NSRegularExpression(pattern: imagePathPattern, options: [])
        let stringRange = NSRange(location: 0, length: from.utf8.count)
        let matches = regex.matches(in: from, range: stringRange)
        var result: [[String]] = []
        for match in matches {
            var groups: [String] = []
            for rangeIndex in 1 ..< match.numberOfRanges {
                let range = match.range(at: rangeIndex)
                guard range.location != NSNotFound else {
                    groups.append("")
                    continue
                }
                groups.append((from as NSString).substring(with: range))
            }
            if !groups.isEmpty {
                result.append(groups)
            }
        }
        return result
            .compactMap { match -> ImageRewrite.ImageUrl? in
                guard match.count == 4,
                      let `extension` = Image.Extension(rawValue: match[3])
                else { return nil }
                return ImageRewrite.ImageUrl(
                    path: Path(match[0]),
                    fileName: match[2],
                    extension: `extension`
                )
            }
            .reduce([ImageRewrite.ImageUrl]()) { current, imageUrl in
                let paths = current.map { $0.filePath }
                if paths.contains(imageUrl.filePath) { return current }
                else { return current + [imageUrl] }
            }
        
    } catch let error {
        print(error)
        return []
    }
}

func rewrites(from source: Path, to target: Path, for: [ImageConfiguration]) -> [ImageRewrite] {
    `for`.flatMap { config in
        config.targetSizes.map { size in
            ImageRewrite(
                source: .init(path: source, fileName: config.fileName, extension: config.extension),
                target: .init(path: target, fileName: size.fileName, extension: config.targetExtension),
                targetSizeClass: sizeClassFrom(upper: size.dimensionsUpperBound)
            )
        }
    }
}

func rewrite(_ stylesheet: String, with rewrites: [ImageRewrite]) -> String {
    // Create css-variable declarations for the different size classes
    var declaration: String = ""
    var indentation: String = ""
    
    func fileSpecificRewrites(for rewrites: [ImageRewrite], from stylesheet: String) -> [ImageRewrite] {
        let urls = imageUrls(from: stylesheet)
        
        return rewrites.reduce([ImageRewrite]()) { current, rewrite in
            var withoutPrefix = rewrite
            withoutPrefix.source.path = Path(String(withoutPrefix.source.path.string.dropFirst("Resources/".count)))
            
            var counter: Int = 1
            let additionalRewrites: [ImageRewrite] = urls.compactMap { imageUrl in
                if let pathPrefix = imageUrl.contains(other: withoutPrefix.source) {
                    var updatedRewrite = withoutPrefix
                    // Original file path as found in the stylesheet file
                    updatedRewrite.source.path = Path("\(pathPrefix.string)\(updatedRewrite.source.path.string)")
                    // Target file path with original relative path + path to reduced asset
                    updatedRewrite.target.path = Path("\(pathPrefix.string)\(updatedRewrite.target.path.string)")
                    updatedRewrite.variableNameSuffix = "path-\(counter)"
                    counter += 1
                    return updatedRewrite
                }
                else {
                    return nil
                }
            }
            
            return current + additionalRewrites
        }
    }
    
    func declarations(from rewrites: [ImageRewrite], for sizeClass: SizeClass, with indentation: String) -> String {
        rewrites
            .filter { $0.targetSizeClass == sizeClass }
            .sorted(by: { $0.variableName < $1.variableName })
            .reduce("") { current, rewrite in
                current +
                    "\(indentation)\(rewrite.variableName): url('\(rewrite.target.path)/\(rewrite.target.fileName).\(rewrite.target.extension)');\n"
        }
    }
    
    let specificRewrites = fileSpecificRewrites(for: rewrites, from: stylesheet)
    
    SizeClass.allCases.forEach { sizeClass in
        switch sizeClass {
        case .extraSmall:
            declaration += ":root {\n"
            indentation = "\t"
        case .small:
            declaration += "@media screen and (min-width: \(sizeClass.minWidth)px) {\n\t:root {\n"
            indentation = "\t\t"
        case .normal:
            declaration += "@media screen and (min-width: \(sizeClass.minWidth)px) {\n\t:root {\n"
            indentation = "\t\t"
        case .large:
            declaration += "@media screen and (min-width: \(sizeClass.minWidth)px) {\n\t:root {\n"
            indentation = "\t\t"
        }
        
        declaration += declarations(
            from: specificRewrites,
            for: sizeClass,
            with: indentation
        )
        
        switch sizeClass {
        case .extraSmall:   declaration += "}\n\n"
        case .small:        declaration += "\t}\n}\n\n"
        case .normal:       declaration += "\t}\n}\n\n"
        case .large:        declaration += "\t}\n}\n\n"
        }
    }

    var updated: String = stylesheet
    
    // Replace the actual image url with the variable
    specificRewrites.forEach { rewrite in
        updated = updated.replacingOccurrences(of: "url('\(rewrite.source.filePath)')", with: "var(\(rewrite.variableName))")
        updated = updated.replacingOccurrences(of: "url(\"\(rewrite.source.filePath)\")", with: "var(\(rewrite.variableName))")
        updated = updated.replacingOccurrences(of: "url(\(rewrite.source.filePath))", with: "var(\(rewrite.variableName))")
    }

    // Prepend the variable declarations
    return declaration + updated
}
