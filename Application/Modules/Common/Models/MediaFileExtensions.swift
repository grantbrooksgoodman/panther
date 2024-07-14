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

public enum MediaFileExtension: Codable, Equatable {
    /* MARK: Cases */

    case audio(AudioFileExtension)
    case image(ImageFileExtension)
    case video(VideoFileExtension)

    /* MARK: Properties */

    // Boolean
    public var isAudio: Bool {
        switch self {
        case .audio: return true
        default: return false
        }
    }

    public var isImage: Bool {
        switch self {
        case .image: return true
        default: return false
        }
    }

    public var isVideo: Bool {
        switch self {
        case .video: return true
        default: return false
        }
    }

    // String
    public var contentTypeString: String {
        switch self {
        case let .audio(fileExtension): return fileExtension.contentTypeString
        case let .image(fileExtension): return fileExtension.contentTypeString
        case let .video(fileExtension): return fileExtension.contentTypeString
        }
    }

    public var rawValue: String {
        switch self {
        case let .audio(fileExtension): return fileExtension.rawValue
        case let .image(fileExtension): return fileExtension.rawValue
        case let .video(fileExtension): return fileExtension.rawValue
        }
    }

    /* MARK: Methods */

    public init?(_ string: String) {
        if string == AudioFileExtension.caf.rawValue {
            self = .audio(.caf)
        } else if string == AudioFileExtension.m4a.rawValue {
            self = .audio(.m4a)
        } else if string == ImageFileExtension.png.rawValue {
            self = .image(.png)
        } else if string == VideoFileExtension.mp4.rawValue {
            self = .video(.mp4)
        } else {
            return nil
        }
    }
}

// MARK: - Audio File Extension

public enum AudioFileExtension: String, Codable, Equatable {
    /* MARK: Cases */

    case caf
    case m4a

    /* MARK: Properties */

    public var contentTypeString: String {
        switch self {
        case .caf: return "audio/x-caf"
        case .m4a: return "audio/m4a"
        }
    }
}

// MARK: - Image File Extension

public enum ImageFileExtension: String, Codable, Equatable {
    /* MARK: Cases */

    case png

    /* MARK: Properties */

    public var contentTypeString: String {
        switch self {
        case .png:
            return "image/png"
        }
    }
}

// MARK: - Video File Extension

public enum VideoFileExtension: String, Codable, Equatable {
    /* MARK: Cases */

    case mp4

    /* MARK: Properties */

    public var contentTypeString: String {
        switch self {
        case .mp4:
            return "video/mp4"
        }
    }
}
