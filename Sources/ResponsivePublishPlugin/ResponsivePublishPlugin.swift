//
//  ResponsivePublishPlugin.swift
//  ResponsivePublishPlugin
//
//  Created by Cordt Zermin on 14.03.21.
//

import Foundation
import Publish
import Ink
import Files
import SwiftGD


var env: Environment = .live()

extension Plugin {
  public static func generateOptimizedImages(
    from: Path = Path("Resources/assets/img"),
    at: Path = Path("assets/img-optimized"),
    rewriting stylesheets: [Path] = [Path("assets/css/styles.css")],
    excludedSubfolders: [String] = [],
    excludedFiles: [String] = []) -> Self {
      
      Plugin(name: "Responsive") { context in
        
        let imageFiles = try files(at: context.folder(at: from), excludingSubfolders: excludedSubfolders, excludingFiles: excludedFiles)
        let configs: [ImageConfiguration] = configurations(from: imageFiles, at: from)
        
        var images = [ExportableImage]()
        
        // Generate WebP images from all images in all responsive sizes
        images.append(contentsOf: resizedImages(for: configs, in: context))
        
        // Save generated images to the optimized images destination path
        do {
          try images.forEach {
            let outputFolder = try context.createOutputFolder(at: at.appendingComponent($0.relativeOutputFolderPath.string))
            try outputFolder.createFile(at: $0.fullFileName, contents: $0.image.export(as: .webp))
          }
        }
        catch {
          print("Failed to write image to output folder")
        }
        
        let imageRewrites = configs.flatMap { rewrites(from: from, to: at, for: $0) }
        
        // Rewrite output css file with optimized images
        do {
          for stylesheet in stylesheets {
            let cssFile = try context.outputFile(at: stylesheet)
            var css = try cssFile.readAsString()
            css = rewrite(stylesheet: css, with: imageRewrites)
            try cssFile.write(css)
          }
        }
        catch let error {
          print("Failed to rewrite CSS files with error: \(error)")
        }
        
        // Rewrite output html files with optimized images
        do {
          let root = try context.outputFolder(at: "")
          let files = root.files.recursive
          
          for file in files where file.extension == "html" {
            var html = try file.readAsString()
            html = rewrite(html: html, with: imageRewrites)
            
            try file.write(html)
          }
        }
        catch let error {
          print("Failed to rewrite HTML files with error: \(error)")
        }
      }
    }
}
