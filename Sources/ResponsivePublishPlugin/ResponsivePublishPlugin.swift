//
//  ResponsivePublishPlugin.swift
//  ResponsivePublishPlugin
//
//  Created by Cordt Zermin on 14.03.21.
//

import Foundation
import Publish
import Ink
import Files
import SwiftGD


var env: Environment = .live()

extension Plugin {
    public static func generateOptimizedImages(
        from: Path = Path("Resources/assets/img"),
        at: Path = Path("assets/img-optimized"),
        rewriting stylesheet: Path = Path("assets/css/styles.css"),
        excluding: [String] = []) -> Self
    {
        Plugin(name: "Responsive") { context in
            let urls: [URL] = try context
                .folder(at: from)
                .files
                .filter({ !excluding.contains($0.name) })
                .reduce([URL]()) { current, file in
                    current + [URL(fileURLWithPath: file.path)]
                }
            
            let configs: [ImageConfiguration] = urls.compactMap { url in
                return ImageConfiguration(
                    url: url,
                    targetExtension: .webp,
                    targetSizes: SizeClass.allCases
                )
            }
            var images = [ExportableImage]()
            
            // Generate WebP images from all images in all responsive sizes
            env.generateImages(configs)
                .run { images.append(contentsOf: $0) }

            // Save generated images to the optimized images destination path
            do {
                let outputFolder = try context.createOutputFolder(at: at)
                try images.forEach {
                    try outputFolder.createFile(at: $0.fullFileName, contents: $0.image.export(as: .webp))
                }
            }
            catch {
                print("Failed to write image to output folder")
            }
            
            let imageRewrites = configs.flatMap { rewrites(from: from, to: at, for: $0) }
            
            // Rewrite output css file with optimized images
            do {
                let cssFile = try context.outputFile(at: stylesheet)
                var css = try cssFile.readAsString()
                css = rewrite(stylesheet: css, with: imageRewrites)
                try cssFile.write(css)
            }
            catch let error {
                print("Failed to rewrite CSS files with error: \(error)")
            }

            // Rewrite output html files with optimized images
            do {
                let root = try context.outputFolder(at: "")
                let files = root.files.recursive
                
                for file in files where file.extension == "html" {    
                    var html = try file.readAsString()
                    html = rewrite(html: html, with: imageRewrites)
                    
                    try file.write(html)
                }
            }
            catch let error {
                print("Failed to rewrite HTML files with error: \(error)")
            }
        }
    }
}
