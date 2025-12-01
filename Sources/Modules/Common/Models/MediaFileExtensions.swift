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

enum MediaFileExtension: Codable, Equatable, CaseIterable {
    /* MARK: Cases */

    case audio(AudioFileExtension)
    case document(DocumentFileExtension)
    case image(ImageFileExtension)
    case video(VideoFileExtension)

    /* MARK: Properties */

    static let hostedCases: [MediaFileExtension] = [
        .audio(.m4a),
        .document(.pdf),
        .image(.jpeg),
        .video(.mp4),
    ]

    static var allCases: [MediaFileExtension] = [
        .audio(.caf),
        .audio(.m4a),
        .document(.pdf),
        .image(.jpeg),
        .image(.jpg),
        .image(.png),
        .video(.mp4),
    ]

    /* MARK: Computed Properties */

    // Boolean
    var isAudio: Bool {
        switch self {
        case .audio: true
        default: false
        }
    }

    var isDocument: Bool {
        switch self {
        case .document: true
        default: false
        }
    }

    var isImage: Bool {
        switch self {
        case .image: true
        default: false
        }
    }

    var isVideo: Bool {
        switch self {
        case .video: true
        default: false
        }
    }

    // String
    var contentTypeString: String {
        switch self {
        case let .audio(fileExtension): fileExtension.contentTypeString
        case let .document(fileExtension): fileExtension.contentTypeString
        case let .image(fileExtension): fileExtension.contentTypeString
        case let .video(fileExtension): fileExtension.contentTypeString
        }
    }

    var rawValue: String {
        switch self {
        case let .audio(fileExtension): fileExtension.rawValue
        case let .document(fileExtension): fileExtension.rawValue
        case let .image(fileExtension): fileExtension.rawValue
        case let .video(fileExtension): fileExtension.rawValue
        }
    }

    /* MARK: Init */

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

enum AudioFileExtension: String, Codable, Equatable {
    /* MARK: Cases */

    case caf
    case m4a

    /* MARK: Properties */

    var contentTypeString: String {
        switch self {
        case .caf: "audio/x-caf"
        case .m4a: "audio/m4a"
        }
    }
}

// MARK: - Document File Extension

enum DocumentFileExtension: String, Codable, Equatable {
    /* MARK: Cases */

    case pdf

    /* MARK: Properties */

    var contentTypeString: String {
        switch self {
        case .pdf: "application/pdf"
        }
    }
}

// MARK: - Image File Extension

enum ImageFileExtension: String, Codable, Equatable {
    /* MARK: Cases */

    case jpeg
    case jpg
    case png

    /* MARK: Properties */

    var contentTypeString: String {
        switch self {
        case .jpeg,
             .jpg: "image/jpeg"
        case .png: "image/png"
        }
    }
}

// MARK: - Video File Extension

enum VideoFileExtension: String, Codable, Equatable {
    /* MARK: Cases */

    case mp4

    /* MARK: Properties */

    var contentTypeString: String {
        switch self {
        case .mp4: "video/mp4"
        }
    }
}
