//
//  ResponsivePublishPluginTests.swift
//  ResponsivePublishPlugin
//
//  Created by Cordt Zermin on 14.03.21.
//

import XCTest
import Publish
import Plot
import Files

@testable import ResponsivePublishPlugin

// MARK: - TestWebsite

private struct TestWebsite: Website {
  enum SectionID: String, WebsiteSectionID {
    case test
  }
  
  struct ItemMetadata: WebsiteItemMetadata { }
  
  var url = URL(string: "https://cordt.zermin.de")!
  var name = "test"
  var description = ""
  var language: Language = .english
  var imagePath: Path? = nil
}

final class ResponsivePublishPluginTests: XCTestCase {
  
  // MARK: - Properties
  
  private static var testDirPath: Path {
    let sourceFileURL = URL(fileURLWithPath: #file)
    return Path(sourceFileURL.deletingLastPathComponent().path)
  }
  
  private var outputFolder: Folder? {
    try? Folder(path: Self.testDirPath.appendingComponent("Output").absoluteString)
  }
  
  private var expectedFolder: Folder? {
    try? Folder(path: Self.testDirPath.appendingComponent("Expected").absoluteString)
  }
  
  private var cacheFolder: Folder? {
    try? Folder(path: Self.testDirPath.appendingComponent(".plugins/Caches/ResponsivePluginImageCaches").absoluteString)
  }
  
  private var resourcesFolderPath: Path {
    Path("Resources")
  }
  
  
  // MARK: - Lifecycle
  
  override func setUp() {
    super.setUp()
    
    env = .mock()
    try? outputFolder?.delete()
  }
  
  override func tearDown() {
    super.tearDown()
    
    try? outputFolder?.delete()
    try? Folder(path: Self.testDirPath.appendingComponent(".publish").absoluteString).delete()
    try? Folder(path: Self.testDirPath.appendingComponent(".plugins").absoluteString).delete()
  }
  
  
  // MARK: - Tests
  
  func testCssIsRewritten() throws {
    try TestWebsite().publish(
      at: Self.testDirPath,
      using: [
        .copyResources(),
        .installPlugin(
          .generateOptimizedImages(
            from: resourcesFolderPath.appendingComponent("img"),
            at: Path("img-optimized"),
            rewriting: [Path("css/styles.css")]
          )
        )
      ]
    )
    
    let output = try? outputFolder?
      .file(at: "css/styles.css")
      .readAsString()
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .filter { !" \n\t\r".contains($0) }
    
    let expected = try? expectedFolder?
      .file(named: "styles-expected.css")
      .readAsString()
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .filter { !" \n\t\r".contains($0) }
    
    XCTAssertEqual(output, expected)
  }
  
  func testImageTagsAreRewritten() throws {
    try TestWebsite().publish(
      at: Self.testDirPath,
      using: [
        .copyResources(),
        .installPlugin(
          .generateOptimizedImages(
            from: resourcesFolderPath.appendingComponent("img"),
            at: Path("img-optimized"),
            rewriting: [Path("css/styles.css")]
          )
        )
      ]
    )
    
    let output = try? outputFolder?
      .file(at: "index.html")
      .readAsString()
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .filter { !" \n\t\r".contains($0) }
    
    let expected = try? expectedFolder?
      .file(named: "index-expected.html")
      .readAsString()
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .filter { !" \n\t\r".contains($0) }
    
    XCTAssertEqual(output, expected)
  }
  
  func testImagesForSizeClassesAreCreated() throws {
    try TestWebsite().publish(
      at: Self.testDirPath,
      using: [
        .copyResources(),
        .installPlugin(
          .generateOptimizedImages(
            from: resourcesFolderPath.appendingComponent("img"),
            at: Path("img-optimized"),
            rewriting: [Path("css/styles.css")]
          )
        )
      ]
    )
    
    let output = try? outputFolder?
      .subfolder(at: "img-optimized")
      .files
      .names()
      .sorted()
    
    let subFolderOutput = try? outputFolder?
      .subfolder(at: "img-optimized/subfolder")
      .files
      .names()
      .sorted()
    
    XCTAssertEqual(output?.count, 4)
    XCTAssertEqual(
      output, [
        "background-extra-small.webp", "background-large.webp", "background-normal.webp", "background-small.webp"
      ]
    )
    XCTAssertEqual(subFolderOutput?.count, 4)
    XCTAssertEqual(
      subFolderOutput, [
        "sub-background-extra-small.webp", "sub-background-large.webp", "sub-background-normal.webp", "sub-background-small.webp"
      ]
    )
  }
  
  func testImagesAreCached() throws {
    // Images need be different (to have different caches), so using the actual Image resizer
    env = .live()
    
    try TestWebsite().publish(
      at: Self.testDirPath,
      using: [
        .copyResources(),
        .installPlugin(
          .generateOptimizedImages(
            from: resourcesFolderPath.appendingComponent("img"),
            at: Path("img-optimized"),
            rewriting: [Path("css/styles.css")]
          )
        )
      ]
    )
    
    let outputCacheData = try? cacheFolder?
      .file(named: "ProcessedImagesCache.json")
      .read()
    
    let expectedCacheData = try? expectedFolder?
      .file(named: "ProcessedImagesCache.json")
      .read()
    
    if let outputCacheData, let expectedCacheData {
      let outputCacheDict = try JSONDecoder().decode([String: String].self, from: outputCacheData)
      let expectedCacheDict = try JSONDecoder().decode([String: String].self, from: expectedCacheData)
      
      // Cannot compare UUIDs
      XCTAssertEqual(outputCacheDict.keys, expectedCacheDict.keys)
    }
    else {
      XCTFail()
    }
    
    let outputCachedFiles = cacheFolder?
      .files
      .count()
    
    XCTAssertEqual(outputCachedFiles, 8+1)
  }
}
