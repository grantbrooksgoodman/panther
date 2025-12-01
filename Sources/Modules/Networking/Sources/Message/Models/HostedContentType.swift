//
//  HostedContentType.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

enum HostedContentType: Codable, Equatable {
    // MARK: - Cases

    case audio(AudioFileExtension)
    case media(id: String, extension: MediaFileExtension)
    case text

    // MARK: - Properties

    var isAudio: Bool {
        switch self {
        case .audio: return true
        default: return false
        }
    }

    var isMedia: Bool {
        switch self {
        case .media: return true
        default: return false
        }
    }

    var mediaFileID: String? {
        switch self {
        case let .media(id: id, extension: _): return id
        default: return nil
        }
    }

    var mediaFilePath: String? {
        guard let mediaFileExtension,
              let mediaFileID else { return nil }
        return "\(mediaFileID).\(mediaFileExtension.rawValue)"
    }

    var rawValue: String {
        switch self {
        case let .audio(fileExtension): return fileExtension.contentTypeString
        case let .media(_, fileExtension): return fileExtension.contentTypeString
        case .text: return "text"
        }
    }

    private var mediaFileExtension: MediaFileExtension? {
        switch self {
        case let .media(id: _, extension: fileExtension): return fileExtension
        default: return nil
        }
    }

    // MARK: - Init

    init?(hostedValue: String) {
        if hostedValue == HostedContentType.text.rawValue {
            self = .text
            return
        }

        let components = hostedValue.components(separatedBy: " – ")
        guard (components.itemAt(1) ?? hostedValue).isBangQualifiedEmpty == false,
              let fileExtension = MediaFileExtension
              .hostedCases
              .first(where: { $0.contentTypeString == components.first ?? hostedValue }) else { return nil }

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
