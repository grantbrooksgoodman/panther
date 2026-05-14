//
//  RichMessageContent.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

enum RichMessageContent: Codable, Equatable {
    // MARK: - Cases

    case audio([AudioMessageReference])
    case media(MediaFile)

    // MARK: - Properties

    var audioComponents: [AudioMessageReference]? {
        switch self {
        case let .audio(audioComponents): audioComponents
        default: nil
        }
    }

    var documentComponent: MediaFile? {
        switch self {
        case let .media(mediaComponent):
            guard mediaComponent.fileExtension.isDocument else { return nil }
            return mediaComponent

        default:
            return nil
        }
    }

    var imageComponent: MediaFile? {
        switch self {
        case let .media(mediaComponent):
            guard mediaComponent.fileExtension.isImage else { return nil }
            return mediaComponent

        default:
            return nil
        }
    }

    var mediaComponent: MediaFile? {
        switch self {
        case let .media(mediaComponent): mediaComponent
        default: nil
        }
    }

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
