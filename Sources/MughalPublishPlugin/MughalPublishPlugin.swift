//
//  MughalPublishPlugin.swift
//  MughalPublishPlugin
//
//  Created by Cordt Zermin on 14.03.21.
//

import Foundation
import Publish
import Files
import Mughal


var env: Environment = .live()

// TODO: Guard against missing or superfluous leading or trailing slashes
// TODO: Do not hardcode the original target path (assets/img/...)
extension Plugin {
    public static func generateOptimizedImages(
        from: Path = Path("Resources/assets/img"),
        at: Path = Path("assets/img-optimized"),
        rewriting stylesheet: Path = Path("assets/css/styles.css")) -> Self
    {
        Plugin(name: "Mughal") { context in
            let urls: [URL] = try context
                .folder(at: from)
                .files
                .reduce([URL]()) { $0 + [URL(fileURLWithPath: $1.path)] }
            
            var images = [Image]()

            // Generate WebP images from all images in all responsive sizes
            env.generateWebP(.high, urls)
                .run { images.append(contentsOf: $0) }
            
            // Save generated images to the optimized images destination path
            do {
                let outputFolder = try context.createOutputFolder(at: at)
                try images.forEach {
                    let filePath: String = "\($0.name)-\($0.sizeClass).\($0.`extension`)"
                    try outputFolder.createFile(at: filePath, contents: $0.imageData)
                }
            } catch {
                print("Failed to write image to output folder")
            }

            // Rewrite output css file with optimized images
            do {
                let imageRewrites = rewrites(from: from, to: at, for: images)
                let cssFile = try context.outputFile(at: stylesheet)
                var css = try cssFile.readAsString()
                imageRewrites.forEach { imageRewrite in
                    css = rewrite(css, with: imageRewrite)
                }
                try cssFile.write(css)
            }
            catch let error {
                print("Failed to rewrite files with error: \(error)")
            }
        }
    }
    
    
    static func rewrites(from source: Path, to target: Path, for: [Image]) -> [ImageRewrite] {
        `for`.map { image in
            ImageRewrite(
                // FIXME: Source extension hard coded - should be dynamic from image
                source: .init(path: source, fileName: image.name, extension: .jpg),
                target: .init(path: target, fileName: image.name, extension: ImageRewrite.FileExtension(from: image.extension))
            )
        }
    }
    
    static func rewrite(_ stylesheet: String, with rewrites: ImageRewrite...) -> String {
        // Create css-variable declarations for the different size classes
        var declaration: String = ""
        var indentation: String = ""
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
            rewrites.forEach { rewrite in
                declaration +=
                    """
                    \(indentation)\(rewrite.variableName): url('\(rewrite.target.path)/\(rewrite.target.fileName)-\(sizeClass.fileSuffix).\(rewrite.target.extension)');\n
                    """
            }
            switch sizeClass {
            case .extraSmall:   declaration += "}\n\n"
            case .small:        declaration += "\t}\n}\n\n"
            case .normal:       declaration += "\t}\n}\n\n"
            case .large:        declaration += "\t}\n}\n\n"
            }
        }

        var updated: String = stylesheet

        // Replace the actual image url with the variable
        rewrites.forEach { image in
            updated = updated.replacingOccurrences(of: "url('assets/img/\(image.source.fileName).\(image.source.extension)')", with: "var(\(image.variableName))")
            updated = updated.replacingOccurrences(of: "url(assets/img/\(image.target.fileName).\(image.source.extension))", with: "var(\(image.variableName))")
            updated = updated.replacingOccurrences(of: "url(assets/img/\"\(image.target.fileName).\(image.source.extension)\")", with: "var(\(image.variableName))")
        }

        // Prepend the variable declarations
        return declaration + updated
    }
}
