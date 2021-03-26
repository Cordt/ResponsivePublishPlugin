//
//  MughalPublishPluginTests.swift
//  MughalPublishPlugin
//
//  Created by Cordt Zermin on 14.03.21.
//

import XCTest
import Publish
import Plot
import Files
import Mughal

@testable import MughalPublishPlugin

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

final class MughalPublishPluginTests: XCTestCase {
    
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
    
    private var resourcesFolderPath: Path {
        Path("Resources")
    }
    
    private func rewrites(using maxDimensions: [Int]) -> [ImageRewrite] {
        MughalPublishPlugin.rewrites(
            from: resourcesFolderPath.appendingComponent("img"),
            to: Path("img-optimized"),
            for: maxDimensions.map {
                    ImageConfiguration(
                        url: URL(fileURLWithPath: #file).appendingPathComponent("img/background.jpg"),
                        extension: .jpg,
                        targetExtension: .webp,
                        targetSizes: [.init(fileName: "background-\(sizeClassFrom(upper: $0).fileSuffix)", dimensionsUpperBound: $0)]
                    )
                }
        )
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
                        rewriting: Path("css/styles.css")
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
    
    func testRewritesProduceCorrectPathes() {
        // Different sizes produce different target file names
        var expectation: [ImageRewrite] = [
            .init(
                source: .init(path: Path("Resources/img"), fileName: "background", extension: .jpg),
                target: .init(path: Path("img-optimized"), fileName: "background-normal", extension: .webp),
                targetSizeClass: .normal
            )
        ]
        XCTAssertEqual(self.rewrites(using: [1200]), expectation)
        print(self.rewrites(using: [1200]))
        expectation = [
            .init(
                source: .init(path: Path("Resources/img"), fileName: "background", extension: .jpg),
                target: .init(path: Path("img-optimized"), fileName: "background-extra-small", extension: .webp),
                targetSizeClass: .extraSmall
            )
        ]
        XCTAssertEqual(self.rewrites(using: [600]), expectation)
        
        expectation = [
            .init(
                source: .init(path: Path("Resources/img/"), fileName: "background", extension: .jpg),
                target: .init(path: Path("/img-optimized"), fileName: "background-normal", extension: .webp),
                targetSizeClass: .normal
            )
        ]
        XCTAssertEqual(self.rewrites(using: [1200]), expectation)
    }
    
    func testCamelCaseIsChangedToKebap() {
        XCTAssertEqual(
            MughalPublishPlugin.SizeClass.extraSmall.fileSuffix,
            "extra-small"
        )
    }
    
    func testImageTagsAreRewritten() throws {
        let staticPages: [Page] = [
            Page(
                path: Path("Home"),
                content: Content(
                    title: "Page - Home",
                    description: "Description of page",
                    body: Content.Body(
                        node: .div(
                            .img(.src(""))
                        )
                    ),
                    lastModified: Date()
                )
            )
        ]
    }
}
