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
                .reduce([URL]()) { current, file in
                    current + [URL(fileURLWithPath: file.path)]
                }
            let configs: [ImageConfiguration] = urls.compactMap { url in
                let components = url
                        .lastPathComponent
                        .split(separator: ".")
                guard let fileName = components.first,
                      let `extension` = components.last
                        .flatMap({ Image.Extension.init(rawValue: String($0)) })
                else {
                    print("Could not extract file name or extension from source image.")
                    return nil
                }
                
                return ImageConfiguration(
                    url: url,
                    extension: `extension`,
                    targetExtension: .webp,
                    targetSizes: SizeClass.allCases.map { sizeClass in
                        ImageConfiguration.Size(
                            fileName: "\(fileName)-\(sizeClass.fileSuffix)",
                            dimensionsUpperBound: sizeClass.upperBound
                        )
                    }
                )
            }
            var images = [Image]()

            // Generate WebP images from all images in all responsive sizes
            env.generateImages(.high, configs)
                .run { images.append(contentsOf: $0) }
            
            // Save generated images to the optimized images destination path
            do {
                let outputFolder = try context.createOutputFolder(at: at)
                try images.forEach {
                    try outputFolder.createFile(at: $0.fullFileName, contents: $0.imageData)
                }
            } catch {
                print("Failed to write image to output folder")
            }

            // Rewrite output css file with optimized images
            do {
                let imageRewrites = rewrites(from: from, to: at, for: configs)
                let cssFile = try context.outputFile(at: stylesheet)
                var css = try cssFile.readAsString()
                css = rewrite(css, with: imageRewrites)
                try cssFile.write(css)
            }
            catch let error {
                print("Failed to rewrite files with error: \(error)")
            }
        }
    }
    
    
    static func rewrites(from source: Path, to target: Path, for: [ImageConfiguration]) -> [ImageRewrite] {
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
    
    static func rewrite(_ stylesheet: String, with rewrites: [ImageRewrite]) -> String {
        // Create css-variable declarations for the different size classes
        var declaration: String = ""
        var indentation: String = ""
        
        func declarations(for sizeClass: SizeClass, with indentation: String) -> String {
            rewrites
                .filter { $0.targetSizeClass == sizeClass }
                .sorted(by: { $0.variableName < $1.variableName })
                .reduce("") { current, rewrite in
                    current +
                        "\(indentation)\(rewrite.variableName): url('\(rewrite.target.path)/\(rewrite.target.fileName).\(rewrite.target.extension)');\n"
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
            
            declaration += declarations(for: sizeClass, with: indentation)
            
            switch sizeClass {
            case .extraSmall:   declaration += "}\n\n"
            case .small:        declaration += "\t}\n}\n\n"
            case .normal:       declaration += "\t}\n}\n\n"
            case .large:        declaration += "\t}\n}\n\n"
            }
        }

        var updated: String = stylesheet
        let prefix: String = "Resources/"
        
        // Replace the actual image url with the variable
        rewrites.forEach { rewrite in
            precondition(rewrite.source.path.string.hasPrefix(prefix), "Only images from the resources path can be rewritten")
            let sourceImagePath: String = String(rewrite.source.path.string.dropFirst(prefix.count))
            updated = updated.replacingOccurrences(of: "url('\(sourceImagePath)/\(rewrite.source.fileName).\(rewrite.source.extension)')", with: "var(\(rewrite.variableName))")
            updated = updated.replacingOccurrences(of: "url(\(sourceImagePath)/\(rewrite.target.fileName).\(rewrite.source.extension))", with: "var(\(rewrite.variableName))")
            updated = updated.replacingOccurrences(of: "url(\(sourceImagePath)/\"\(rewrite.target.fileName).\(rewrite.source.extension)\")", with: "var(\(rewrite.variableName))")
        }

        // Prepend the variable declarations
        return declaration + updated
    }
    
}
