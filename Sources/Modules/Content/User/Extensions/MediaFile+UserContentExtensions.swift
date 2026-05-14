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

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

extension MediaFile: @MainActor MediaItem {
    @MainActor
    var image: UIImage? {
        image(.thumbnail)
    }

    var placeholderImage: UIImage {
        .missing
    }

    @MainActor
    var size: CGSize {
        image?.size ?? .zero
    }

    var url: URL? {
        localPathURL
    }
}

extension MediaFile {
    // MARK: - Types

    enum ImageQuality {
        case full
        case thumbnail
    }

    // MARK: - Properties

    static var thumbnailImageNameSuffix: String {
        "-thumbnail.\(MediaFileExtension.image(.jpeg).rawValue)"
    }

    // MARK: - Methods

    @MainActor
    func image(_ quality: ImageQuality) -> UIImage? {
        @Dependency(\.fileManager) var fileManager: FileManager
        @Dependency(\.chatPageViewService.mediaMessagePreview) var mediaMessagePreviewService: MediaMessagePreviewService?

        var cachedFullQualityImage: UIImage? {
            mediaMessagePreviewService?.cachedImages?[localPathURL]
        }
        var fullQualityImage: UIImage? {
            if let cachedFullQualityImage {
                return cachedFullQualityImage
            }

            guard let image = UIImage(contentsOfFile: localPathURL.path()) else { return .missing }
            if var cachedImages = mediaMessagePreviewService?.cachedImages {
                cachedImages[localPathURL] = image
                mediaMessagePreviewService?.cachedImages = cachedImages
            }

            return image
        }

        guard quality == .thumbnail else { return fullQualityImage }

        if let cachedThumbnails = mediaMessagePreviewService?.cachedThumbnails,
           let thumbnailPath = localPathURL.thumbnailPath,
           let cachedThumbnail = cachedThumbnails[thumbnailPath] {
            return cachedThumbnail
        } else if let cachedFullQualityImage {
            return cachedFullQualityImage
        }

        guard let thumbnailPath = localPathURL.thumbnailPath,
              fileManager.fileExists(atPath: thumbnailPath.path()) else { return fullQualityImage }

        guard let image = UIImage(contentsOfFile: thumbnailPath.path()) else { return nil }
        if var cachedThumbnails = mediaMessagePreviewService?.cachedThumbnails {
            cachedThumbnails[thumbnailPath] = image
            mediaMessagePreviewService?.cachedThumbnails = cachedThumbnails
        }

        return image
    }
}
