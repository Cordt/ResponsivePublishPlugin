//
//  RewriteEngineTests.swift
//  ResponsivePublishPlugin
//
//  Created by Cordt Zermin on 20.03.21.
//

import XCTest
import Publish
import Files

@testable import ResponsivePublishPlugin

final class RewriteEngineTests: XCTestCase {
    
    
    // MARK: - Properties
    
    fileprivate var css: String {
        """
        .image-container {
            background: url('img/background.jpg');
        }
        .image-container-detail {
            background: url('../img/background.jpg');
        }
        .image-container-more-detail {
            background: url('../img/background.jpg');
        }
        .image-container-more-detail {
            background: url('assets/img/another-background.jpg');
        }
        .image-container-more-detail {
            background: url('../assets-folder/img/image_name.jpg');
        }
        .image-container {
            background: url(img/background-blue.jpg);
        }
        .image-container-detail {
            background: url(../img/background.jpg);
        }
        .image-container-more-detail {
            background: url(background.jpg);
        }
        .image-container-detail {
            background: url("../assets/img/background.jpg");
        }
        .image-container-more-detail {
            background: url("../../img/background.jpg");
        }
        """
    }
    
    fileprivate var expectedCss: String {
        """
        :root {
        }

        @media screen and (min-width: 600px) {
            :root {
            }
        }

        @media screen and (min-width: 900px) {
            :root {
                --background-path-1-img-url: url('img-optimized/background-normal.webp');
                --background-path-2-img-url: url('../img-optimized/background-normal.webp');
                --background-path-3-img-url: url('../assets/img-optimized/background-normal.webp');
                --background-path-4-img-url: url('../../img-optimized/background-normal.webp');
            }
        }

        @media screen and (min-width: 1200px) {
            :root {
            }
        }

        .image-container {
            background: var(--background-path-1-img-url);
        }
        .image-container-detail {
            background: var(--background-path-2-img-url);
        }
        .image-container-more-detail {
            background: var(--background-path-2-img-url);
        }
        .image-container-more-detail {
            background: url('assets/img/another-background.jpg');
        }
        .image-container-more-detail {
            background: url('../assets-folder/img/image_name.jpg');
        }
        .image-container {
            background: url(img/background-blue.jpg);
        }
        .image-container-detail {
            background: var(--background-path-2-img-url);
        }
        .image-container-more-detail {
            background: url(background.jpg);
        }
        .image-container-detail {
            background: var(--background-path-3-img-url);
        }
        .image-container-more-detail {
            background: var(--background-path-4-img-url);
        }
        """
    }
    
    fileprivate var html: String {
        """
        <!DOCTYPE html>
        <html>
            <head>
                <title>Test page title</title>
            </head>
            <body>
                <h1>HTML Body</h1>
                <img src="img/background.jpg" alt="Background Image" style="width:100%" />
                <img alt="Background Image" src="img/detail/background.jpg" style="width:128px;height:128px;" />
                <a href="/imprint">
                    <img src="assets/img/opaque.png" alt="Why am I opaque?" style="width:42px;height:42px;" />
                </a>
                <img src="assets/img/background.jpg" alt="Background" width="500" height="600" />
                <img src="assets/img/background.jpg" />
            </body>
        </html>
        """
    }
    
    fileprivate var expectedHtml: String {
        """
        <!DOCTYPE html>
        <html>
            <head>
                <title>Test page title</title>
            </head>
            <body>
                <h1>HTML Body</h1>
                <img srcset="
                    img-optimized/background-normal.webp 1200w,
                    img-optimized/background-large.webp 1800w"
                    src="img/background.jpg" alt="Background Image" style="width:100%" />
                <img alt="Background Image" src="img/detail/background.jpg" style="width:128px;height:128px;" />
                <a href="/imprint">
                    <img src="assets/img/opaque.png" alt="Why am I opaque?" style="width:42px;height:42px;" />
                </a>
                <img srcset="
                    assets/img-optimized/background-normal.webp 1200w,
                    assets/img-optimized/background-large.webp 1800w"
                    src="assets/img/background.jpg" alt="Background" width="500" height="600" />
                <img srcset="
                    assets/img-optimized/background-normal.webp 1200w,
                    assets/img-optimized/background-large.webp 1800w"
                    src="assets/img/background.jpg" />
            </body>
        </html>
        """
    }
    
    fileprivate var expectedImagePaths: [ImageRewrite.ImageUrl] {
        [
            .init(path: "img/", fileName: "background", extension: .jpg),
            .init(path: "../img/", fileName: "background", extension: .jpg),
            .init(path: "assets/img/", fileName: "another-background", extension: .jpg),
            .init(path: "../assets-folder/img/", fileName: "image_name", extension: .jpg),
            .init(path: "img/", fileName: "background-blue", extension: .jpg),
            .init(path: "", fileName: "background", extension: .jpg),
            .init(path: "../assets/img/", fileName: "background", extension: .jpg),
            .init(path: "../../img/", fileName: "background", extension: .jpg)
        ]
    }
    
    fileprivate var resourcesFolderPath: Path {
        Path("Resources")
    }
    
    fileprivate func rewrites(using maxDimensions: [Int], targetPath: Path) -> [ImageRewrite] {
        maxDimensions.flatMap {
            ResponsivePublishPlugin.rewrites(
                from: resourcesFolderPath.appendingComponent("img"),
                to: targetPath,
                for: ImageConfiguration(
                    url: URL(fileURLWithPath: #file).appendingPathComponent("img/background.jpg"),
                    resourcesLocation: Path("Resources/img"),
                    targetExtension: .webp,
                    targetSizes: [sizeClassFrom(upper: $0)]
                )!
            )
        }
    }
    
    // MARK: - Tests
    
    func testContainedRelativePathsAreFound() {
        var prefixedPath = ImageRewrite.ImageUrl(path: "img/detail", fileName: "background", extension: .jpg)
        var path = ImageRewrite.ImageUrl(path: "detail", fileName: "background", extension: .jpg)
        var result = prefixedPath.contains(other: path)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, Path("img/"))
        
        prefixedPath = ImageRewrite.ImageUrl(path: "assets/img/detail", fileName: "background", extension: .jpg)
        path = ImageRewrite.ImageUrl(path: "img/detail", fileName: "background", extension: .jpg)
        result = prefixedPath.contains(other: path)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, Path("assets/"))
        
        prefixedPath = ImageRewrite.ImageUrl(path: "img/detail/", fileName: "background", extension: .jpg)
        path = ImageRewrite.ImageUrl(path: "detail", fileName: "background", extension: .jpg)
        result = prefixedPath.contains(other: path)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, Path("img/"))
        
        prefixedPath = ImageRewrite.ImageUrl(path: "/img/detail", fileName: "background", extension: .jpg)
        path = ImageRewrite.ImageUrl(path: "detail", fileName: "background", extension: .jpg)
        result = prefixedPath.contains(other: path)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, Path("/img/"))
    }
    
    func testImagePathsAreFound() throws {
        let imagePaths = imageUrlsFrom(stylesheet: css)
        XCTAssertEqual(imagePaths, expectedImagePaths)
    }
    
    func testRewritesProduceCorrectPaths() {
        
        let target: Path = Path("img-optimized")
        
        // Different sizes produce different target file names
        var expectation: [ImageRewrite] = [
            .init(
                source: .init(path: Path("Resources/img"), fileName: "background", extension: .jpg),
                target: .init(path: target, fileName: "background-normal", extension: .webp),
                targetSizeClass: .normal
            )
        ]
        XCTAssertEqual(self.rewrites(using: [1200], targetPath: target), expectation)
        
        expectation = [
            .init(
                source: .init(path: Path("Resources/img"), fileName: "background", extension: .jpg),
                target: .init(path: target, fileName: "background-extra-small", extension: .webp),
                targetSizeClass: .extraSmall
            )
        ]
        XCTAssertEqual(self.rewrites(using: [600], targetPath: target), expectation)
    }
    
    func testRewritesKeepCorrectPrefix() {
        
        let targetPath = Path("img-optimized")
        var expectation: [ImageRewrite] = [
            .init(
                source: .init(path: Path("Resources/img/"), fileName: "background", extension: .jpg),
                target: .init(path: targetPath, fileName: "background-normal", extension: .webp),
                targetSizeClass: .normal
            )
        ]
        XCTAssertEqual(self.rewrites(using: [1200], targetPath: targetPath), expectation)
        
        let targetPathWithPrefix = Path("/img-optimized")
        expectation = [
            .init(
                source: .init(path: Path("Resources/img/"), fileName: "background", extension: .jpg),
                target: .init(path: targetPathWithPrefix, fileName: "background-normal", extension: .webp),
                targetSizeClass: .normal
            )
        ]
        XCTAssertEqual(self.rewrites(using: [1200], targetPath: targetPathWithPrefix), expectation)
    }
    
    func testCamelCaseIsChangedToKebap() {
        XCTAssertEqual(
            ResponsivePublishPlugin.SizeClass.extraSmall.fileSuffix,
            "extra-small"
        )
    }
    
    
    func testStylesheetRewrites() {
        let updatedStylesheet = rewrite(stylesheet: css, with: [
            ImageRewrite(
                source: .init(
                    path: Path("Resources/img"),
                    fileName: "background",
                    extension: .jpg
                ),
                target: .init(
                    path: Path("img-optimized"),
                    fileName: "background-normal",
                    extension: .webp
                ),
                targetSizeClass: .normal
            )
        ])
        
        let result = updatedStylesheet
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !" \n\t\r".contains($0) }
        
        let expectation = expectedCss
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !" \n\t\r".contains($0) }
        
        XCTAssertEqual(result, expectation)
    }
    
    func testHtmlRewrites() {
        let updatedHtml = rewrite(html: html, with: [
            ImageRewrite(
                source: .init(
                    path: Path("Resources/img"),
                    fileName: "background",
                    extension: .jpg
                ),
                target: .init(
                    path: Path("img-optimized"),
                    fileName: "background-normal",
                    extension: .webp
                ),
                targetSizeClass: .normal
            ),
            ImageRewrite(
                source: .init(
                    path: Path("Resources/img"),
                    fileName: "background",
                    extension: .jpg
                ),
                target: .init(
                    path: Path("img-optimized"),
                    fileName: "background-large",
                    extension: .webp
                ),
                targetSizeClass: .large
            )
        ])
        
        let result = updatedHtml
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !" \n\t\r".contains($0) }
        
        let expectation = expectedHtml
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !" \n\t\r".contains($0) }
            
        XCTAssertEqual(result, expectation)
    }
}
