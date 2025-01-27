//  ResponsivePublishPlugin

import Publish


func resizedImages<Site: Website>(
  for configurations: [ImageConfiguration],
  in context: PublishingContext<Site>
) -> [ExportableImage] {
  return configurations.reduce([ExportableImage]()) { current, config in
    // Check which images have already been generated
    if let exportableImages = loadImagesFromCache(config: config, in: context) {
      return current + exportableImages
    }
    else {
      var imagesToCache: [SizeClass: ExportableImage] = [:]
      config.targetSizes.forEach { sizeClass in
        if let exportableImage = env.resizeImage(config, sizeClass) {
          imagesToCache[sizeClass] = exportableImage
        }
      }
      saveImagesInCache(imagesToCache: imagesToCache, originalImageUrl: config.url, in: context)
      return current + imagesToCache.values
    }
  }
}
