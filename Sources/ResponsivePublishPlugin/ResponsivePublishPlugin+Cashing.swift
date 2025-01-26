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
    
    var result: [ExportableImage] = []
    for size in config.targetSizes {
      guard
        let sizeClassData = size.fileSuffix.data(using: .utf8),
        let imageHash = imageHash(config.url, sizeClassData: sizeClassData),
        let existingPath = cache[imageHash],
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
    let imageData = try image.image.export(as: .webp)
    let sizeClassData = sizeClass.fileSuffix.data(using: .utf8)!
    let fileName = "\(UUID().uuidString).\(image.extension.rawValue)"
    
    if let imageHash = imageHash(originalImageUrl, sizeClassData: sizeClassData) {
      cache[imageHash] = fileName
      try saveImageInCache(fileName, image: imageData, in: context)
      saveCacheToDisk(cache, in: context)
    }
    else {
      print("Failed to generate partial hash from Image")
    }
  }
  catch {
    print("Failed to save Image in Cache: \(error)")
  }
}


// MARK: - Hashing

/// Generates a SHA-256 hash string from raw image data.
fileprivate func imageHash(_ url: URL, sizeClassData: Data, chunkSize: Int = 64 * 1024) -> String? {
  guard let fileHandle = try? FileHandle(forReadingFrom: url)
  else { return nil }
  defer { try? fileHandle.close() }
  
  guard let fileSize = try? fileHandle.seekToEnd(), fileSize > 0
  else { return nil }
  
  // Seek back to start to read the first chunk
  try? fileHandle.seek(toOffset: 0)
  let firstChunk = fileHandle.readData(ofLength: min(chunkSize, Int(fileSize)))
  
  // Seek to the position where the last chunk begins
  let lastChunkSize = min(chunkSize, Int(fileSize))
  if fileSize > chunkSize {
    // If there's enough data, read from fileSize - chunkSize
    try? fileHandle.seek(toOffset: fileSize - UInt64(lastChunkSize))
  }
  else {
    // If file is smaller than chunkSize, we've already read it all.
    // We can just reuse `firstChunk`.
  }
  let lastChunk = (fileSize > chunkSize)
  ? fileHandle.readData(ofLength: lastChunkSize)
  : Data()
  
  // Combine them
  var combined = Data()
  combined.append(firstChunk)
  combined.append(lastChunk)
  combined.append(sizeClassData)
  
  // Hash using CryptoKit’s SHA256
  let hashValue = SHA256.hash(data: combined)
  return hashValue.compactMap { String(format: "%02x", $0) }.joined()
}


// MARK: - Disk Persistence

fileprivate func loadImageCache<Site: Website>(context: PublishingContext<Site>) -> [String: String] {
  do {
    let cacheFile = try createCacheFileIfNeeded(in: context)
    let data = try cacheFile.read()
    guard !data.isEmpty else {
      return [:]
    }
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
  let cachesFolder = try context.createFolder(at: ".plugins/Caches")
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
