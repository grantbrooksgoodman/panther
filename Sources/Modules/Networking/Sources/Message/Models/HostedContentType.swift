//
//  HostedContentType.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// The type of a message's hosted content.
enum HostedContentType: Codable, Equatable {
    // MARK: - Cases

    /// Audio content with the given file extension.
    case audio(AudioFileExtension)

    /// Media content – an image, video, or document – with the given identifier and file
    /// extension.
    case media(id: String, extension: MediaFileExtension)

    /// Text content.
    case text

    // MARK: - Properties

    /// A Boolean value that indicates whether the content is audio.
    var isAudio: Bool {
        switch self {
        case .audio: true
        default: false
        }
    }

    /// A Boolean value that indicates whether the content is media.
    var isMedia: Bool {
        switch self {
        case .media: true
        default: false
        }
    }

    /// The media content's identifier, or `nil` if the content is not media.
    var mediaFileID: String? {
        switch self {
        case let .media(id: id, extension: _): id
        default: nil
        }
    }

    /// The media content's file path, or `nil` if the content is not media.
    var mediaFilePath: String? {
        guard let mediaFileExtension,
              let mediaFileID else { return nil }
        return "\(mediaFileID).\(mediaFileExtension.rawValue)"
    }

    /// The content type's wire-format string.
    var rawValue: String {
        switch self {
        case let .audio(fileExtension): fileExtension.contentTypeString
        case let .media(_, fileExtension): fileExtension.contentTypeString
        case .text: "text"
        }
    }

    private var mediaFileExtension: MediaFileExtension? {
        switch self {
        case let .media(id: _, extension: fileExtension): fileExtension
        default: nil
        }
    }

    // MARK: - Init

    /// Creates a content type from its wire-format string.
    ///
    /// - Parameter hostedValue: The wire-format content type string.
    ///
    /// - Returns: The content type, or `nil` if the string is not a valid content type.
    init?(hostedValue: String) {
        if hostedValue == HostedContentType.text.rawValue {
            self = .text
            return
        }

        let components = hostedValue.components(separatedBy: " – ")
        guard (components.itemAt(1) ?? hostedValue).isBangQualifiedEmpty == false,
              let fileExtension = MediaFileExtension
              .hostedCases
              .first(where: {
                  $0.contentTypeString == components.first ?? hostedValue
              }) else { return nil }

        switch components.count {
        case 1:
            switch fileExtension {
            case let .audio(audioFileExtension): self = .audio(audioFileExtension)
            default: return nil
            }

        case 2:
            switch fileExtension {
            case .audio: return nil
            default: self = .media(id: components[1], extension: fileExtension)
            }

        default: return nil
        }
    }
}
