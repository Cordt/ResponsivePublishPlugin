//
//  ResponsivePublishPlugin+Util.swift
//  ResponsivePublishPlugin
//
//  Created by Cordt Zermin on 22.04.21.
//

import Foundation
import Files

func files(at folder: Folder,
           excludingSubfolders: [String] = [],
           excludingFiles: [String] = []) -> [File] {
    
    let subFiles = folder
        .subfolders
        .filter { !excludingSubfolders.contains($0.path(relativeTo: folder)) }
        .reduce([File]()) { current, folder in
            current + files(at: folder, excludingSubfolders: excludingSubfolders, excludingFiles: excludingFiles)
                .filter { !excludingFiles.contains($0.name) }
        }
    
    return folder.files.map { $0 } + subFiles
}

func urls(from files: [File]) -> [URL] {
    files.reduce([URL]()) { current, file in
        current + [URL(fileURLWithPath: file.path)]
    }
}
