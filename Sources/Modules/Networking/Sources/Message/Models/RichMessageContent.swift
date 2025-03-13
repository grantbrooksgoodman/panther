//
//  RichMessageContent.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum RichMessageContent: Codable, Equatable {
    // MARK: - Cases

    case audio([AudioMessageReference])
    case media(MediaFile)

    // MARK: - Properties

    public var audioComponents: [AudioMessageReference]? {
        switch self {
        case let .audio(audioComponents): return audioComponents
        default: return nil
        }
    }

    public var documentComponent: MediaFile? {
        switch self {
        case let .media(mediaComponent):
            guard mediaComponent.fileExtension.isDocument else { return nil }
            return mediaComponent

        default:
            return nil
        }
    }

    public var imageComponent: MediaFile? {
        switch self {
        case let .media(mediaComponent):
            guard mediaComponent.fileExtension.isImage else { return nil }
            return mediaComponent

        default:
            return nil
        }
    }

    public var mediaComponent: MediaFile? {
        switch self {
        case let .media(mediaComponent): return mediaComponent
        default: return nil
        }
    }

    public var videoComponent: MediaFile? {
        switch self {
        case let .media(mediaComponent):
            guard mediaComponent.fileExtension.isVideo else { return nil }
            return mediaComponent

        default:
            return nil
        }
    }
}
