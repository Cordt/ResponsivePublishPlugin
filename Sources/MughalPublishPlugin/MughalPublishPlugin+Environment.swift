//
//  MughalPublishPlugin+Environment.swift
//  MughalPublishPlugin
//
//  Created by Cordt Zermin on 14.03.21.
//

import Foundation
import Mughal

struct Environment {
    var generateImages: (_ quality: Quality, _ configurations: [ImageConfiguration]) -> Parallel<[Image]>
    
    static func live() -> Self {
        return Environment { quality, configs in
            WebP.generateImages(with: quality, for: configs)
        }
    }
    
    #if DEBUG
    static func mock() -> Self {
        return Environment { _, configs in
            return Parallel<[Image]> {
                let images = configs.reduce([Image]()) { current, config in
                    current + config.targetSizes.map { size in
                        return Image(
                            name: size.fileName,
                            extension: .webp,
                            imageData: Data(),
                            width: size.dimensionsUpperBound / 2,
                            height: size.dimensionsUpperBound
                        )
                    }
                }
                return $0(images)
            }
        }
    }
    #endif
}
