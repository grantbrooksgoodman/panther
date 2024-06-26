//
//  ImageFileExtension.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum ImageFileExtension: String, Codable, Equatable {
    // MARK: - Cases

    case png

    // MARK: - Properties

    public var contentTypeString: String {
        switch self {
        case .png:
            return "image/png"
        }
    }
}
