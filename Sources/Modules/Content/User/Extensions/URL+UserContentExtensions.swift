//
//  URL+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 15/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension URL {
    var thumbnailPath: URL? {
        let components = absoluteString.components(separatedBy: "/")
        guard components.count > 1,
              let fileName = components.last?.components(separatedBy: ".").first else {
            return .init(string: "\(absoluteString.components(separatedBy: ".")[0])\(MediaFile.thumbnailImageNameSuffix)")
        }

        var path = components[0 ... components.count - 2].joined(separator: "/")
        while path.hasSuffix("/") { path = path.dropSuffix() }
        path = "\(path)/\(fileName)\(MediaFile.thumbnailImageNameSuffix)"
        return .init(string: path)
    }
}
