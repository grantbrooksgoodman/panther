//
//  MediaFileExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

// MARK: - Media File Extension

/// A media file's type and extension.
///
/// ``MediaFileExtension`` categorizes a file extension by media kind – audio, document, image,
/// or video – carrying the specific extension as an associated value.
enum MediaFileExtension: Codable, Equatable, CaseIterable {
    /* MARK: Cases */

    /// An audio file with the given extension.
    case audio(AudioFileExtension)

    /// A document file with the given extension.
    case document(DocumentFileExtension)

    /// An image file with the given extension.
    case image(ImageFileExtension)

    /// A video file with the given extension.
    case video(VideoFileExtension)

    /* MARK: Properties */

    /// The canonical extension for each media kind when content is hosted remotely.
    static let hostedCases: [MediaFileExtension] = [
        .audio(.m4a),
        .document(.pdf),
        .image(.jpeg),
        .video(.mp4),
    ]

    /// Every supported media file extension.
    static let allCases: [MediaFileExtension] = [
        .audio(.caf),
        .audio(.m4a),
        .document(.pdf),
        .image(.jpeg),
        .image(.jpg),
        .image(.png),
        .video(.mp4),
    ]

    /* MARK: Computed Properties */

    /// The MIME content type for this extension.
    var contentTypeString: String {
        switch self {
        case let .audio(fileExtension): fileExtension.contentTypeString
        case let .document(fileExtension): fileExtension.contentTypeString
        case let .image(fileExtension): fileExtension.contentTypeString
        case let .video(fileExtension): fileExtension.contentTypeString
        }
    }

    /// A Boolean value that indicates whether this is an audio extension.
    var isAudio: Bool {
        switch self {
        case .audio: true
        default: false
        }
    }

    /// A Boolean value that indicates whether this is a document extension.
    var isDocument: Bool {
        switch self {
        case .document: true
        default: false
        }
    }

    /// A Boolean value that indicates whether this is an image extension.
    var isImage: Bool {
        switch self {
        case .image: true
        default: false
        }
    }

    /// A Boolean value that indicates whether this is a video extension.
    var isVideo: Bool {
        switch self {
        case .video: true
        default: false
        }
    }

    /// The extension's string value, without a leading period.
    var rawValue: String {
        switch self {
        case let .audio(fileExtension): fileExtension.rawValue
        case let .document(fileExtension): fileExtension.rawValue
        case let .image(fileExtension): fileExtension.rawValue
        case let .video(fileExtension): fileExtension.rawValue
        }
    }

    /* MARK: Init */

    /// Creates a media file extension from the given string, ignoring case and surrounding
    /// whitespace.
    ///
    /// - Parameter string: The extension's string value, without a leading period.
    ///
    /// - Returns: A media file extension, or `nil` if the string is not a supported extension.
    init?(_ string: String) {
        let rawValue = string.lowercasedTrimmingWhitespaceAndNewlines
        if rawValue == AudioFileExtension.caf.rawValue {
            self = .audio(.caf)
        } else if rawValue == AudioFileExtension.m4a.rawValue {
            self = .audio(.m4a)
        } else if rawValue == DocumentFileExtension.pdf.rawValue {
            self = .document(.pdf)
        } else if rawValue == ImageFileExtension.jpeg.rawValue {
            self = .image(.jpeg)
        } else if rawValue == ImageFileExtension.jpg.rawValue {
            self = .image(.jpg)
        } else if rawValue == ImageFileExtension.png.rawValue {
            self = .image(.png)
        } else if rawValue == VideoFileExtension.mp4.rawValue {
            self = .video(.mp4)
        } else {
            return nil
        }
    }
}

// MARK: - Audio File Extension

/// The supported audio file extensions.
enum AudioFileExtension: String, Codable, Equatable {
    /* MARK: Cases */

    case caf
    case m4a

    /* MARK: Properties */

    /// The MIME content type for this extension.
    var contentTypeString: String {
        switch self {
        case .caf: "audio/x-caf"
        case .m4a: "audio/m4a"
        }
    }
}

// MARK: - Document File Extension

/// The supported document file extensions.
enum DocumentFileExtension: String, Codable, Equatable {
    /* MARK: Cases */

    case pdf

    /* MARK: Properties */

    /// The MIME content type for this extension.
    var contentTypeString: String {
        switch self {
        case .pdf: "application/pdf"
        }
    }
}

// MARK: - Image File Extension

/// The supported image file extensions.
enum ImageFileExtension: String, Codable, Equatable {
    /* MARK: Cases */

    case jpeg
    case jpg
    case png

    /* MARK: Properties */

    /// The MIME content type for this extension.
    var contentTypeString: String {
        switch self {
        case .jpeg,
             .jpg: "image/jpeg"
        case .png: "image/png"
        }
    }
}

// MARK: - Video File Extension

/// The supported video file extensions.
enum VideoFileExtension: String, Codable, Equatable {
    /* MARK: Cases */

    case mp4

    /* MARK: Properties */

    /// The MIME content type for this extension.
    var contentTypeString: String {
        switch self {
        case .mp4: "video/mp4"
        }
    }
}
