//
//  AudioFileExtension.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum AudioFileExtension: String, Codable, Equatable {
    // MARK: - Cases

    case caf
    case m4a

    // MARK: - Properties

    public var contentTypeString: String {
        switch self {
        case .caf:
            return "audio/x-caf"

        case .m4a:
            return "audio/m4a"
        }
    }
}
