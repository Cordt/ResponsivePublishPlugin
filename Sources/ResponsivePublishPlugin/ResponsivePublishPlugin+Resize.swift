//  ResponsivePublishPlugin

import Publish


func resizedImages<Site: Website>(
  for configurations: [ImageConfiguration],
  in context: PublishingContext<Site>
) -> [ExportableImage] {
  return configurations.reduce([ExportableImage]()) { current, config in
    // Check which images have already been generated
    if let exportableImages = loadImagesFromCache(config: config, in: context) {
      print("Found cached images for \(config.fileName)")
      return current + exportableImages
    }
    else {
      return current + config.targetSizes.compactMap { sizeClass in
        if let exportableImage = env.resizeImage(config, sizeClass) {
          saveImageInCache(sizeClass: sizeClass, originalImageUrl: config.url, image: exportableImage, in: context)
          return exportableImage
        }
        else {
          return nil
        }
      }
    }
  }
}
