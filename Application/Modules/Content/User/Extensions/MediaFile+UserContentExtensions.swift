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
        @Dependency(\.chatPageViewService.mediaMessagePreview) var mediaMessagePreviewService: MediaMessagePreviewService?

        if let cacheValue = mediaMessagePreviewService?.cache.value(forKey: .mediaMessagePreviewService(.thumbnails)) as? [URL: UIImage],
           let thumbnailPath = urlPath.thumbnailPath,
           let cachedThumbnail = cacheValue[thumbnailPath] {
            return cachedThumbnail
        } else if let cacheValue = mediaMessagePreviewService?.cache.value(forKey: .mediaMessagePreviewService(.images)) as? [URL: UIImage],
                  let cachedImage = cacheValue[urlPath] {
            return cachedImage
        }

        guard let thumbnailPath = urlPath.thumbnailPath,
              fileManager.fileExists(atPath: thumbnailPath.path()) else {
            guard let image = UIImage(contentsOfFile: urlPath.path()) else { return nil }
            if var cacheValue = mediaMessagePreviewService?.cache.value(forKey: .mediaMessagePreviewService(.images)) as? [URL: UIImage] {
                cacheValue[urlPath] = image
                mediaMessagePreviewService?.cache.set(cacheValue, forKey: .mediaMessagePreviewService(.images))
            }
            return image
        }

        guard let image = UIImage(contentsOfFile: thumbnailPath.path()) else { return nil }
        if var cacheValue = mediaMessagePreviewService?.cache.value(forKey: .mediaMessagePreviewService(.thumbnails)) as? [URL: UIImage] {
            cacheValue[thumbnailPath] = image
            mediaMessagePreviewService?.cache.set(cacheValue, forKey: .mediaMessagePreviewService(.thumbnails))
        }
        return image
    }

    public var placeholderImage: UIImage { .init() }
    public var size: CGSize { image?.size ?? .zero }
    public var url: URL? { urlPath }
}

public extension MediaFile {
    static var thumbnailImageNameSuffix: String { "-thumbnail.\(MediaFileExtension.image(.png).rawValue)" }
}
