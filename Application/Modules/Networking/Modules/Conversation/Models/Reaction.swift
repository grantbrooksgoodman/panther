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

        public static var orderedCases: [Style] = [.love, .like, .dislike, .laugh, .surprise, .sad]

        private static let emojiCaseMap: [String: Style] = Dictionary(uniqueKeysWithValues: Style.allCases.map { ($0.emojiValue, $0) })

        // MARK: - Computed Properties

        public var emojiValue: String {
            switch self {
            case .dislike: "👎"
            case .laugh: "😂"
            case .like: "👍"
            case .love: "❤️"
            case .sad: "😢"
            case .surprise: "😮"
            }
        }

        public var encodedValue: String { rawValue.uppercased() }

        public var orderValue: Int {
            switch self {
            case .dislike: 2
            case .laugh: 3
            case .like: 1
            case .love: 0
            case .sad: 5
            case .surprise: 4
            }
        }

        // MARK: - Init

        public init?(emojiValue: String) {
            guard let matchingStyle = Style.emojiCaseMap[emojiValue] else { return nil }
            self = matchingStyle
        }

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

    public init?(_ style: Style) {
        @Persistent(.currentUserID) var currentUserID: String?
        guard let currentUserID else { return nil }
        self = .init(style, userID: currentUserID)
    }
}
