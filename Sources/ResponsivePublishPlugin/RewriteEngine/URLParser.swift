//
//  URLParser.swift
//  ResponsivePublishPlugin
//
//  Created by Cordt Zermin on 25.03.21.
//

import Foundation
import Publish
import SwiftGD

fileprivate let imageTagPattern: String = #"<img\s*(?:src\s*\=\s*[\'\"](\/?(\.\.\/|[A-Za-z-_\+\d]+\/)*)([A-Za-z-_\+\d]*).(jpg|png)[\'\"].*?\s*|[a-z]+?\s*\=\s*[\'\"].*?[\'\"].*?\s*)+[\s\/]*?>"#
fileprivate let imagePathPattern: String = #"url\(['"]?((\.\.\/|[A-Za-z-_\+\d]+\/)*)([A-Za-z-_\+\d]*).(jpg|png){1}['"]?\);"#

/// Extracts Image URLs from a given HTML file, looking for img-tags and the corresponding src-attribute
func imageUrlsFrom(html: String) -> [ImageRewrite.ImageUrl] {
    imageUrls(from: html, using: imageTagPattern)
}

/// Extracts Image URLs from a given Stylesheet file, looking for url functions that contain image URLs
func imageUrlsFrom(stylesheet: String) -> [ImageRewrite.ImageUrl] {
    imageUrls(from: stylesheet, using: imagePathPattern)
}

fileprivate func imageUrls(from: String, using pattern: String) -> [ImageRewrite.ImageUrl] {
    do {
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let stringRange = NSRange(location: 0, length: from.utf16.count)
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
                      let `extension` = ImageFormat(rawValue: match[3])
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
