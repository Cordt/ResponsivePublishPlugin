//
//  MughalPublishPlugin+Environment.swift
//  MughalPublishPlugin
//
//  Created by Cordt Zermin on 14.03.21.
//

import Foundation
import Mughal

struct Environment {
    var generateWebP: (_ quality: Quality, _ urls: [URL]) -> Parallel<[Image]>
    
    static func live() -> Self {
        return Environment { quality, urls in
            WebP.generateWebP(with: quality, from: urls)
        }
    }
    
    #if DEBUG
    static func mock() -> Self {
        return Environment { _, urls in
            return Parallel<[Image]> {
                let images = urls.reduce([Image]()) { current, url in
                    current + Mughal.SizeClass.allCases.map { sizeClass in
                        return Image(
                            name: String(url.lastPathComponent.split(separator: ".").first!),
                            extension: .webP,
                            imageData: Data(),
                            sizeClass: sizeClass
                        )
                    }
                }
                return $0(images)
            }
        }
    }
    #endif
}
