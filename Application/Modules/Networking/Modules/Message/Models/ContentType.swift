//
//  ContentType.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum ContentType: String, Codable, Equatable {
    // MARK: - Cases

    case audio
    case image
    case text

    // MARK: - Methods

    public init?(rawValue: String) {
        if rawValue == ContentType.audio.rawValue {
            self = .audio
        } else if rawValue == ContentType.image.rawValue {
            self = .image
        } else if rawValue == ContentType.text.rawValue {
            self = .text
        } else {
            return nil
        }
    }
}
