//  ResponsivePublishPlugin

import Foundation
import Publish


func resizedImages<Site: Website>(
  for configurations: [ImageConfiguration],
  in context: PublishingContext<Site>
) -> [ExportableImage] {
  // Load cache once at the start
  let cache = loadImageCache(context: context)

  // Separate cached from uncached, precomputing file chunks for hash efficiency
  var cachedResults: [ExportableImage] = []
  var uncachedConfigs: [(config: ImageConfiguration, fileChunks: Data)] = []

  for config in configurations {
    guard let fileChunks = imageFileChunks(config.url) else { continue }

    if let cached = loadImagesFromCache(config: config, cache: cache, fileChunks: fileChunks, in: context) {
      cachedResults.append(contentsOf: cached)
    } else {
      uncachedConfigs.append((config: config, fileChunks: fileChunks))
    }
  }

  guard !uncachedConfigs.isEmpty else {
    return cachedResults
  }

  // Process uncached images in parallel
  let lock = NSLock()
  var newResults: [[ExportableImage]] = Array(repeating: [], count: uncachedConfigs.count)
  var newCacheEntries: [(hash: String, fileName: String, data: Data)] = []

  DispatchQueue.concurrentPerform(iterations: uncachedConfigs.count) { index in
    let (config, fileChunks) = uncachedConfigs[index]
    let resizedData = env.resizeImage(config, config.targetSizes)

    var localResults: [ExportableImage] = []
    var localCacheEntries: [(hash: String, fileName: String, data: Data)] = []

    for (sizeClass, data) in resizedData {
      localResults.append(ExportableImage(
        relativeOutputFolderPath: config.relativePath,
        name: config.fileName(for: sizeClass),
        extension: .webp,
        imageData: data
      ))

      if let sizeClassData = sizeClass.fileSuffix.data(using: .utf8) {
        let hash = imageHash(fileChunks: fileChunks, sizeClassData: sizeClassData)
        let fileName = "\(UUID().uuidString).webp"
        localCacheEntries.append((hash: hash, fileName: fileName, data: data))
      }
    }

    lock.lock()
    newResults[index] = localResults
    newCacheEntries.append(contentsOf: localCacheEntries)
    lock.unlock()
  }

  // Save all new cache entries sequentially after parallel processing
  var updatedCache = cache
  for entry in newCacheEntries {
    updatedCache[entry.hash] = entry.fileName
    saveImageDataInCache(entry.fileName, imageData: entry.data, in: context)
  }
  saveCacheToDisk(updatedCache, in: context)

  return cachedResults + newResults.flatMap { $0 }
}
