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
    /// The media's thumbnail image.
    @MainActor
    var image: UIImage? {
        image(.thumbnail)
    }

    /// The placeholder image shown when the media cannot be loaded.
    var placeholderImage: UIImage {
        .missing
    }

    /// The size of the media's image.
    @MainActor
    var size: CGSize {
        image?.size ?? .zero
    }

    /// The media's local file URL.
    var url: URL? {
        localPathURL
    }
}

extension MediaFile {
    // MARK: - Types

    /// The quality levels at which a media file's image can be loaded.
    enum ImageQuality {
        /// The full-resolution image.
        case full

        /// The thumbnail image.
        case thumbnail
    }

    // MARK: - Properties

    /// The filename suffix appended to a media file's thumbnail image.
    static var thumbnailImageNameSuffix: String {
        "-thumbnail.\(MediaFileExtension.image(.jpeg).rawValue)"
    }

    // MARK: - Methods

    /// Returns the file's image at the given quality, caching it in memory.
    ///
    /// - Parameter quality: The quality at which to load the image.
    ///
    /// - Returns: The file's image, or `nil` if it cannot be loaded.
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
