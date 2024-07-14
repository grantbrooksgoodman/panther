//
//  Media.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum Media: Codable, Equatable {
    // MARK: - Cases

    case audio([AudioMessageReference])
    case image(ImageFile)
    case video(URL)

    // MARK: - Properties

    public var audioComponents: [AudioMessageReference]? {
        switch self {
        case let .audio(audioComponents): return audioComponents
        default: return nil
        }
    }

    public var imageComponent: ImageFile? {
        switch self {
        case let .image(imageComponent): return imageComponent
        default: return nil
        }
    }

    public var videoComponent: URL? {
        switch self {
        case let .video(videoComponent): return videoComponent
        default: return nil
        }
    }
}
