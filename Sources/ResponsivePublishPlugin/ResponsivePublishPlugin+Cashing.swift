// ResponsivePublishPlugin

import CryptoKit
import Files
import Foundation
import Publish
import SwiftGD


/// Checks if a set of images by the data-hash of the original are already processed
/// Only returns if images for all size classes are present
func loadImagesFromCache<Site: Website>(
  config: ImageConfiguration,
  in context: PublishingContext<Site>
) -> [ExportableImage]? {
  do {
    let cache = loadImageCache(context: context)
    let imageData = try Data(contentsOf: config.url)
    
    var result: [ExportableImage] = []
    for size in config.targetSizes {
      guard
        let sizeClassData = size.fileSuffix.data(using: .utf8),
        let existingPath = cache[hashImageData(imageData + sizeClassData)],
        let imageData = getImageDataFromCache(existingPath, in: context)
      else { return nil }
      
      let image = try Image(data: imageData, as: .webp)
      
      result.append(
        ExportableImage(
          relativeOutputFolderPath: config.relativePath,
          name: config.fileName(for: size),
          extension: .webp,
          image: image
        )
      )
    }
    return result
  }
  catch {
    print("Failed to find cached images: \(error)")
    return nil
  }
}

func saveImageInCache<Site: Website>(
  sizeClass: SizeClass,
  originalImageUrl: URL,
  image: ExportableImage,
  in context: PublishingContext<Site>
) {
  do {
    var cache = loadImageCache(context: context)
    let originalImageData = try Data(contentsOf: originalImageUrl)
    let imageData = try image.image.export(as: .webp)
    let sizeClassData = sizeClass.fileSuffix.data(using: .utf8)!
    let fileName = "\(UUID().uuidString).\(image.extension.rawValue)"
    
    cache[hashImageData(originalImageData + sizeClassData)] = fileName
    try saveImageInCache(fileName, image: imageData, in: context)
    saveCacheToDisk(cache, in: context)
  }
  catch {
    print("Failed to save Image in Cache: \(error)")
  }
}


// MARK: - Hashing

/// Generates a SHA-256 hash string from raw image data.
fileprivate func hashImageData(_ data: Data) -> String {
  let hash = SHA256.hash(data: data)
  return hash.map { String(format: "%02x", $0) }.joined()
}


// MARK: - Disk Persistence

fileprivate func loadImageCache<Site: Website>(context: PublishingContext<Site>) -> [String: String] {
  do {
    let cacheFile = try createCacheFileIfNeeded(in: context)
    let data = try cacheFile.read()
    let dict = try JSONDecoder().decode([String: String].self, from: data)
    return dict
  }
  catch {
    print("Failed to load/parse cache from disk: \(error)")
    return [:]
  }
}

fileprivate func createCacheFileIfNeeded<Site: Website>(in context: PublishingContext<Site>) throws -> File {
  let cachesFolder = try createCacheFolderIfNeeded(in: context)
  return try cachesFolder.createFileIfNeeded(at: "ProcessedImagesCache.json")
}

fileprivate func createCacheFolderIfNeeded<Site: Website>(in context: PublishingContext<Site>) throws -> Folder {
  let cachesFolder = try context.folder(at: ".publish/Caches")
  return try cachesFolder.createSubfolderIfNeeded(withName: "ResponsivePluginImageCaches")
}

fileprivate func saveCacheToDisk<Site: Website>(_ cache: [String: String], in context: PublishingContext<Site>) {
  do {
    let data = try JSONEncoder().encode(cache)
    let cacheFile = try createCacheFileIfNeeded(in: context)
    try cacheFile.write(data)
  }
  catch {
    print("Failed to save cache to disk: \(error)")
  }
}

fileprivate func saveImageInCache<Site: Website>(_ filename: String, image: Data, in context: PublishingContext<Site>) throws {
  do {
    let cachesFolder = try createCacheFolderIfNeeded(in: context)
    try cachesFolder.createFile(at: filename, contents: image)
  }
  catch {
    print("Failed to save image in Cache: \(error)")
  }
}

fileprivate func getImageDataFromCache<Site: Website>(_ filename: String, in context: PublishingContext<Site>) -> Data? {
  do {
    let cachesFolder = try createCacheFolderIfNeeded(in: context)
    return try cachesFolder.file(named: filename).read()
  }
  catch {
    print("Failed to get image data from Cache: \(error)")
    return nil
  }
}
