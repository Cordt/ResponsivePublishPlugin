//  ResponsivePublishPlugin

import Foundation
import SwiftGD

struct Environment {
  /// Resizes an image to all specified size classes at once, loading the original only once.
  /// Returns a dictionary mapping each size class to its exported WebP data.
  var resizeImage: (_ configuration: ImageConfiguration, _ sizeClasses: [SizeClass]) -> [SizeClass: Data]

  static func live() -> Self {
    return Environment { config, sizeClasses in
      guard let image = Image(url: config.url)
      else { return [:] }

      var results: [SizeClass: Data] = [:]
      for sizeClass in sizeClasses {
        let targetSize = sizeThatFits(for: image.size, within: sizeClass.upperBound)
        if let resized = image.resizedTo(width: targetSize.width, height: targetSize.height),
           let data = try? resized.export(as: .webp) {
          results[sizeClass] = data
        }
      }
      return results
    }
  }

#if DEBUG
  static func mock() -> Self {
    return Environment { _, sizeClasses in
      var results: [SizeClass: Data] = [:]
      for sizeClass in sizeClasses {
        if let image = Image(width: sizeClass.upperBound / 2, height: sizeClass.upperBound),
           let data = try? image.export(as: .webp) {
          results[sizeClass] = data
        }
      }
      return results
    }
  }
#endif
}
