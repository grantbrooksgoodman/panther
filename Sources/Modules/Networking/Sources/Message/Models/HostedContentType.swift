//
//  HostedContentType.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum HostedContentType: Codable, Equatable {
    // MARK: - Cases

    case media(MediaFileExtension)
    case text

    // MARK: - Properties

    // Bool
    public var isAudio: Bool {
        switch self {
        case .media(.audio): return true
        default: return false
        }
    }

    public var isMediaOtherThanAudio: Bool { !isAudio && self != .text }

    // String
    public var rawValue: String {
        switch self {
        case let .media(fileExtension): return fileExtension.contentTypeString
        case .text: return "text"
        }
    }

    // MARK: - Init

    public init?(rawValue: String) {
        if rawValue == HostedContentType.text.rawValue {
            self = .text
            return
        }

        guard let mediaFileExtension = MediaFileExtension
            .hostedCases
            .first(where: { $0.contentTypeString == rawValue }) else { return nil }

        self = .media(mediaFileExtension)
    }
}
