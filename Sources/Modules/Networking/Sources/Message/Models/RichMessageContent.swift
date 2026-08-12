//
//  RichMessageContent.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// The rich content of a message – audio or media.
enum RichMessageContent: Codable, Equatable {
    // MARK: - Cases

    /// Audio content, as one or more audio references.
    case audio([AudioMessageReference])

    /// Media content – an image, video, or document.
    case media(MediaFile)

    // MARK: - Properties

    /// The audio components, or `nil` if the content is not audio.
    var audioComponents: [AudioMessageReference]? {
        switch self {
        case let .audio(audioComponents): audioComponents
        default: nil
        }
    }

    /// The document, or `nil` if the content is not a document.
    var documentComponent: MediaFile? {
        switch self {
        case let .media(mediaComponent):
            guard mediaComponent.fileExtension.isDocument else { return nil }
            return mediaComponent

        default:
            return nil
        }
    }

    /// The image, or `nil` if the content is not an image.
    var imageComponent: MediaFile? {
        switch self {
        case let .media(mediaComponent):
            guard mediaComponent.fileExtension.isImage else { return nil }
            return mediaComponent

        default:
            return nil
        }
    }

    /// The media file, or `nil` if the content is not media.
    var mediaComponent: MediaFile? {
        switch self {
        case let .media(mediaComponent): mediaComponent
        default: nil
        }
    }

    /// The video, or `nil` if the content is not a video.
    var videoComponent: MediaFile? {
        switch self {
        case let .media(mediaComponent):
            guard mediaComponent.fileExtension.isVideo else { return nil }
            return mediaComponent

        default:
            return nil
        }
    }
}
