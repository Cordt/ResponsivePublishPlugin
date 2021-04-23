//
//  ResponsivePublishPlugin+Environment.swift
//  ResponsivePublishPlugin
//
//  Created by Cordt Zermin on 14.03.21.
//

import Foundation
import SwiftGD

struct Environment {
    var generateImages: (_ configurations: [ImageConfiguration]) -> Parallel<[ExportableImage]>
    
    static func live() -> Self {
        Environment(
            generateImages: reducedImages(for:)
        )
    }
    
    #if DEBUG
    static func mock() -> Self {
        return Environment { configs in
            return Parallel<[ExportableImage]> {
                let images = configs.reduce([ExportableImage]()) { current, config in
                    current + config.targetSizes.compactMap { sizeClass in
                        guard let image = Image(width: sizeClass.upperBound / 2, height: sizeClass.upperBound) else { return nil }
                        return ExportableImage(
                            relativeOutputFolderPath: config.relativePath,
                            name: config.fileName(for: sizeClass),
                            extension: .webp,
                            image: image
                        )
                    }
                }
                return $0(images)
            }
        }
    }
    #endif
}

fileprivate func reducedImages(for configurations: [ImageConfiguration]) -> Parallel<[ExportableImage]> {
    Parallel<[ExportableImage]> { callback in
        let images = configurations.reduce([ExportableImage]()) { current, config in
            current + config.targetSizes.compactMap { sizeClass -> ExportableImage? in
                guard let image = Image(url: config.url) else { return nil }
                let targetSize = sizeThatFits(for: image.size, within: sizeClass.upperBound)
                guard let resizedImage = image.resizedTo(width: targetSize.width, height: targetSize.height) else { return nil }
                return ExportableImage(
                    relativeOutputFolderPath: config.relativePath,
                    name: config.fileName(for: sizeClass),
                    extension: config.targetExtension,
                    image: resizedImage
                )
            }
        }
        callback(images)
    }
}
