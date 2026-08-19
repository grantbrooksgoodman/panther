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

    /// The content type's complete wire-format string.
    ///
    /// For text and audio content, this value equals ``rawValue``. For media content, it is the
    /// MIME type, file identifier, and file extension joined by `" – "` (a space, an en dash, and
    /// a space): `"<mime> – <id> – <ext>"`. Encode media content types through this property
    /// rather than assembling the wire string by hand.
    var hostedValue: String {
        switch self {
        case let .media(id, fileExtension): "\(fileExtension.contentTypeString) – \(id) – \(fileExtension.rawValue)"
        default: rawValue
        }
    }

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

    /// The content type's raw string.
    ///
    /// For text content, this value is `"text"`; for audio and media content, it is the MIME
    /// type. To encode a content type for the wire, use ``hostedValue`` instead, which for media
    /// content also includes the file identifier and extension.
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
        switch components.count {
        case 1:
            guard let audioFileExtension = AudioFileExtension
                .allCases
                .first(where: { $0.contentTypeString == hostedValue }) else { return nil }

            self = .audio(audioFileExtension)

        case 3:
            let id = components[1]
            let fileExtensionString = components[2]
            guard !id.isBangQualifiedEmpty,
                  !fileExtensionString.isBangQualifiedEmpty,
                  let fileExtension = MediaFileExtension(fileExtensionString),
                  !fileExtension.isAudio,
                  components[0] == fileExtension.contentTypeString else { return nil }

            self = .media(id: id, extension: fileExtension)

        default: return nil
        }
    }
}
