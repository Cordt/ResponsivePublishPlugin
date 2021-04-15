//
//  Rewrites.swift
//  ResponsivePublishPlugin
//
//  Created by Cordt Zermin on 20.03.21.
//

import Foundation
import Publish
import SwiftGD


fileprivate func fileSpecificRewrites(for rewrites: [ImageRewrite], and urls: [ImageRewrite.ImageUrl]) -> [ImageRewrite] {
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

func rewrite(stylesheet: String, with rewrites: [ImageRewrite]) -> String {
    let urls = imageUrlsFrom(stylesheet: stylesheet)
    let specificRewrites = fileSpecificRewrites(for: rewrites, and: urls)
    
    guard !specificRewrites.isEmpty else {
        return stylesheet
    }
    
    // Create css-variable declarations for the different size classes
    var declaration: String = ""
    var indentation: String = ""
    
    func declarations(from rewrites: [ImageRewrite], for sizeClass: SizeClass, with indentation: String) -> String {
        rewrites
            .filter { $0.targetSizeClass == sizeClass }
            .sorted(by: { $0.variableName < $1.variableName })
            .reduce("") { current, rewrite in
                current +
                    "\(indentation)\(rewrite.variableName): url('\(rewrite.target.filePath)');\n"
        }
    }
    
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

func rewrite(html: String, with rewrites: [ImageRewrite]) -> String {
    let urls = imageUrlsFrom(html: html)
    let specificRewrites = fileSpecificRewrites(for: rewrites, and: urls)
    let groupedRewrites = Dictionary(grouping: specificRewrites) { $0.source.filePath }
    
    struct ImageTagAttribute {
        /// The original source of the image is used to replace the src tag in the images in the html
        let originalSource: String
        let sourceSet: String
    }
    
    // Create image tag attributes for the different size classes
    func replacements(from rewrites: [String: [ImageRewrite]]) -> [ImageTagAttribute] {
        groupedRewrites.map { source, rewrites in
            let srcset = rewrites.reduce("") {
                $0 + "\($1.target.filePath) \($1.targetSizeClass.upperBound)w, "
            }
            .dropLast(2)
            return ImageTagAttribute(
                originalSource: source,
                sourceSet: "srcset=\"\(srcset)\""
            )
        }
    }
    
    var updated: String = html
    
    // Replace the src-attribute of the images with the srcset
    replacements(from: groupedRewrites).forEach { srcset in
        updated = updated.replacingOccurrences(
            of: "src=\"\(srcset.originalSource)\"",
            with: srcset.sourceSet + " src=\"\(srcset.originalSource)\""
        )
    }
    
    return updated
}
