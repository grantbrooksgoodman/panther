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
enum MediaFileExtension: Codable, Equatable {
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
    /// A string that does not match a known audio, image, video, or PDF extension but is
    /// non-empty and strictly alphanumeric is treated as a plain-text document extension
    /// (``DocumentFileExtension/plainText(_:)``). This determination does not consult the
    /// Uniform Type Identifier database, so callers that ingest arbitrary user files must first
    /// validate the file's conformance to `UTType.plainText` themselves.
    ///
    /// - Parameter string: The extension's string value, without a leading period.
    ///
    /// - Returns: A media file extension, or `nil` if the string is empty or not strictly
    ///   alphanumeric.
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
        } else if !rawValue.isEmpty,
                  rawValue.allSatisfy({ $0.isLetter || $0.isNumber }) {
            self = .document(.plainText(rawValue))
        } else {
            return nil
        }
    }
}

// MARK: - Audio File Extension

/// The supported audio file extensions.
enum AudioFileExtension: String, CaseIterable, Codable, Equatable {
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

/// A document file's extension.
///
/// ``DocumentFileExtension`` distinguishes PDF documents from plain-text documents, carrying
/// an arbitrary plain-text extension as an associated value.
enum DocumentFileExtension: Codable, Equatable {
    /* MARK: Cases */

    /// A PDF file.
    case pdf

    /// A plain-text file with the given extension, lowercased and without a leading period.
    case plainText(String)

    /* MARK: Properties */

    /// The MIME content type for this extension.
    var contentTypeString: String {
        switch self {
        case .pdf: "application/pdf"
        case .plainText: "text/plain"
        }
    }

    /// The extension's string value, without a leading period.
    var rawValue: String {
        switch self {
        case .pdf: "pdf"
        case let .plainText(fileExtension): fileExtension
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
