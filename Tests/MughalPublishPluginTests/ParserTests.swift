//
//  ParserTests.swift
//  MughalPublishPlugin
//
//  Created by Cordt Zermin on 20.03.21.
//

import XCTest
import Publish
import Files

@testable import MughalPublishPlugin

final class ParserTests: XCTestCase {
    
    
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
    
    
    // MARK: - Tests
    
    func testImagePathsAreFound() throws {
        let imagePaths = imageUrls(from: css)
        XCTAssertEqual(imagePaths, expectedImagePaths)
        
    }
    
    func testRewrites() {
        let updatedStylesheet = rewrite(css, with: [
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
}
