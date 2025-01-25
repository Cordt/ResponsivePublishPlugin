//  ResponsivePublishPlugin

import SwiftGD

struct Environment {
  var resizeImage: (_ configuration: ImageConfiguration, _ sizeClass: SizeClass) -> ExportableImage?
  
  static func live() -> Self {
    return Environment { config, sizeClass in
      guard let image = Image(url: config.url)
      else { return nil }
      
      let targetSize = sizeThatFits(for: image.size, within: sizeClass.upperBound)
      guard let resizedImage = image.resizedTo(width: targetSize.width, height: targetSize.height)
      else { return nil }
      
      return ExportableImage(
        relativeOutputFolderPath: config.relativePath,
        name: config.fileName(for: sizeClass),
        extension: .webp,
        image: resizedImage
      )
    }
  }
  
#if DEBUG
  static func mock() -> Self {
    return Environment { config, sizeClass in
      guard let image = Image(width: sizeClass.upperBound / 2, height: sizeClass.upperBound)
      else { return nil }
      
      return ExportableImage(
        relativeOutputFolderPath: config.relativePath,
        name: config.fileName(for: sizeClass),
        extension: .webp,
        image: image
      )
    }
  }
#endif
}
