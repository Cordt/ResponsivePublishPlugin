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

    struct ItemMetadata: WebsiteItemMetadata {
    }
    
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
    
    private var rewrites: [ImageRewrite] {
        Plugin<TestWebsite>
            .rewrites(
                from: resourcesFolderPath.appendingComponent("img"),
                to: Path("img-optimized"),
                for: [Image(name: "background", extension: .webP, imageData: Data(), sizeClass: .large)]
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
        
//        try? outputFolder?.delete()
        try? Folder(path: Self.testDirPath.appendingComponent(".publish").absoluteString).delete()
    }
    
    func testVariablesAreAddedToCss() throws {
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
    
    func testCssIsRewritten() throws {
        try TestWebsite()
            .publish(
                at: Self.testDirPath,
                using: [.copyResources()]
            )
        let stylesheet = try? outputFolder?.file(at: "css/styles.css").readAsString()
        var result = stylesheet!
        self.rewrites.forEach { rw in
            print("rewriting")
            result = Plugin<TestWebsite>.rewrite(
                result,
                with: rw
            )
        }
        let expected = try? expectedFolder?
            .file(named: "styles-expected.css")
            .readAsString()
            .trimmingCharacters(in: .newlines)
            .filter { !" \n\t\r".contains($0) }
        result = result
            .trimmingCharacters(in: .newlines)
            .filter { !" \n\t\r".contains($0) }
        XCTAssertEqual(result, expected)
    }
    
    func testRewritesProduceCorrectPathes() {
        var expectation: [ImageRewrite] = [
            .init(
                source: .init(path: Path("Resources/img"), fileName: "background", extension: .jpg),
                target: .init(path: Path("img-optimized"), fileName: "background", extension: .webp)
            )
        ]
        XCTAssertEqual(self.rewrites, expectation)
        
        expectation = [
            .init(
                source: .init(path: Path("Resources/img/"), fileName: "background", extension: .jpg),
                target: .init(path: Path("/img-optimized"), fileName: "background", extension: .webp)
            )
        ]
        XCTAssertEqual(self.rewrites, expectation)
    }
    
    func testCamelCaseIsChangedToKebap() {
        XCTAssertEqual(
            MughalPublishPlugin.SizeClass.extraSmall.fileSuffix,
            "extra-small"
        )
    }
}
