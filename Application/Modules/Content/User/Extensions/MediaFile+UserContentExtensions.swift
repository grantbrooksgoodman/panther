//
//  MediaFile+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/06/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import CoreArchitecture
import MessageKit

extension MediaFile: MediaItem {
    public var image: UIImage? {
        @Dependency(\.fileManager) var fileManager: FileManager
        @Dependency(\.networking.config.paths.media) var mediaPath: String
        let path = "\(mediaPath)/\(name).\(fileExtension.rawValue)"
        return .init(contentsOfFile: fileManager.pathToFileInDocuments(named: path))
    }

    public var placeholderImage: UIImage { .init() }
    public var size: CGSize { image?.size ?? .zero }
    public var url: URL? { urlPath }
}
