// ResponsivePublishPlugin

import CryptoKit
import Files
import Foundation
import Publish


// MARK: - Cache Lifecycle

/// Loads the image cache dictionary from disk
func loadImageCache<Site: Website>(context: PublishingContext<Site>) -> [String: String] {
  do {
    let cacheFile = try createCacheFileIfNeeded(in: context)
    let data = try cacheFile.read()
    guard !data.isEmpty else {
      return [:]
    }
    return try JSONDecoder().decode([String: String].self, from: data)
  }
  catch {
    print("Failed to load/parse cache from disk: \(error)")
    return [:]
  }
}

/// Checks if cached images exist for all size classes of a given configuration.
/// Returns raw image Data without decoding, for direct write-through to output.
func loadImagesFromCache<Site: Website>(
  config: ImageConfiguration,
  cache: [String: String],
  fileChunks: Data,
  in context: PublishingContext<Site>
) -> [ExportableImage]? {
  var result: [ExportableImage] = []
  for size in config.targetSizes {
    guard let sizeClassData = size.fileSuffix.data(using: .utf8) else { return nil }
    let hash = imageHash(fileChunks: fileChunks, sizeClassData: sizeClassData)
    guard let existingPath = cache[hash],
          let imageData = getImageDataFromCache(existingPath, in: context)
    else { return nil }

    result.append(
      ExportableImage(
        relativeOutputFolderPath: config.relativePath,
        name: config.fileName(for: size),
        extension: .webp,
        imageData: imageData
      )
    )
  }
  return result
}

/// Saves a single image's data to the cache folder
func saveImageDataInCache<Site: Website>(_ filename: String, imageData: Data, in context: PublishingContext<Site>) {
  do {
    let cachesFolder = try createCacheFolderIfNeeded(in: context)
    try cachesFolder.createFile(at: filename, contents: imageData)
  }
  catch {
    print("Failed to save image in Cache: \(error)")
  }
}

/// Persists the cache index dictionary to disk
func saveCacheToDisk<Site: Website>(_ cache: [String: String], in context: PublishingContext<Site>) {
  do {
    let data = try JSONEncoder().encode(cache)
    let cacheFile = try createCacheFileIfNeeded(in: context)
    try cacheFile.write(data)
  }
  catch {
    print("Failed to save cache to disk: \(error)")
  }
}


// MARK: - Hashing

/// Reads the first and last chunks of a file for use in hash computation.
/// Call once per image, then use imageHash(fileChunks:sizeClassData:) for each size class.
func imageFileChunks(_ url: URL, chunkSize: Int = 64 * 1024) -> Data? {
  guard let fileHandle = try? FileHandle(forReadingFrom: url)
  else { return nil }
  defer { try? fileHandle.close() }

  guard let fileSize = try? fileHandle.seekToEnd(), fileSize > 0
  else { return nil }

  try? fileHandle.seek(toOffset: 0)
  let firstChunk = fileHandle.readData(ofLength: min(chunkSize, Int(fileSize)))

  var combined = Data()
  combined.append(firstChunk)

  if fileSize > chunkSize {
    let lastChunkSize = min(chunkSize, Int(fileSize))
    try? fileHandle.seek(toOffset: fileSize - UInt64(lastChunkSize))
    let lastChunk = fileHandle.readData(ofLength: lastChunkSize)
    combined.append(lastChunk)
  }

  return combined
}

/// Generates a SHA-256 hash from precomputed file chunks and a size class identifier
func imageHash(fileChunks: Data, sizeClassData: Data) -> String {
  var combined = fileChunks
  combined.append(sizeClassData)
  let hashValue = SHA256.hash(data: combined)
  return hashValue.compactMap { String(format: "%02x", $0) }.joined()
}


// MARK: - Disk Persistence Helpers

fileprivate func createCacheFileIfNeeded<Site: Website>(in context: PublishingContext<Site>) throws -> File {
  let cachesFolder = try createCacheFolderIfNeeded(in: context)
  return try cachesFolder.createFileIfNeeded(at: "ProcessedImagesCache.json")
}

fileprivate func createCacheFolderIfNeeded<Site: Website>(in context: PublishingContext<Site>) throws -> Folder {
  let cachesFolder = try context.createFolder(at: ".plugins/Caches")
  return try cachesFolder.createSubfolderIfNeeded(withName: "ResponsivePluginImageCaches")
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
