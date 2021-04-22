//
//  UtilTests.swift
//  ResponsivePublishPlugin
//
//  Created by Cordt Zermin on 22.04.21.
//

import XCTest
import Publish
import Files
@testable import ResponsivePublishPlugin


final class UtilTests: XCTestCase {
    
    private static var testDirPath: Path {
        let sourceFileURL = URL(fileURLWithPath: #file)
        return Path(sourceFileURL.deletingLastPathComponent().path)
    }
    
    private var imagesFolder: Folder {
        try! Folder(path: Self.testDirPath.appendingComponent("Resources/img").absoluteString)
    }
    
    private var outputFolder: Folder? {
        try? Folder(path: Self.testDirPath.appendingComponent("Output").absoluteString)
    }
    
    func testSubfoldersAreIncluded() {
        let imageFiles = files(at: imagesFolder)
        let containsFile = imageFiles
            .map { $0.name }
            .contains("sub-background.jpg")
        
        XCTAssertTrue(containsFile)
    }
    
    func testFoldersAreExcluded() {
        let imageFiles = files(
            at: imagesFolder,
            excludingSubfolders: ["icons"]
        )
        
        let containsFile = imageFiles
            .map { $0.name }
            .contains("favicon.ico")
        
        XCTAssertFalse(containsFile)
    }
    
    func testFilesAreExcluded() {
        let imageFiles = files(
            at: imagesFolder,
            excludingFiles: ["favicon.ico"]
        )
        
        let containsFile = imageFiles
            .map { $0.name }
            .contains("favicon.ico")
        
        XCTAssertFalse(containsFile)
    }
}
