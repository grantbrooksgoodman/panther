//
//  Reaction.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public struct Reaction: Codable, Hashable {
    // MARK: - Types

    public enum Style: String, CaseIterable, Codable, Hashable {
        // MARK: - Cases

        case dislike
        case laugh
        case like
        case love
        case sad
        case surprise

        // MARK: - Properties

        public var encodedValue: String { rawValue.uppercased() }

        // MARK: - Init

        public init?(encodedValue: String) {
            guard let matchingCase = Style.allCases.first(where: { $0.encodedValue == encodedValue }) else { return nil }
            self = matchingCase
        }
    }

    // MARK: - Properties

    public let style: Style
    public let userID: String

    // MARK: - Init

    public init(
        _ style: Style,
        userID: String
    ) {
        self.style = style
        self.userID = userID
    }
}
