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
}
