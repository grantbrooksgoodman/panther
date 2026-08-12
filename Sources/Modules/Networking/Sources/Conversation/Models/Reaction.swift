//
//  Reaction.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

/// A reaction applied to a message by a user.
struct Reaction: Codable, Hashable {
    // MARK: - Types

    /// The visual style of a reaction.
    enum Style: String, CaseIterable, Codable, Hashable {
        // MARK: - Cases

        /// The thumbs-down reaction style.
        case dislike

        /// The emphasis reaction style.
        case emphasis

        /// The laughing reaction style.
        case laugh

        /// The thumbs-up reaction style.
        case like

        /// The heart reaction style.
        case love

        /// The question reaction style.
        case question

        // MARK: - Properties

        /// The reaction styles, sorted by display order.
        static let orderedCases: [Style] = allCases.sorted(by: { $0.orderValue < $1.orderValue })

        private static let emojiCaseMap: [String: Style] = Dictionary(uniqueKeysWithValues: Style.allCases.map { ($0.emojiValue, $0) })

        // MARK: - Computed Properties

        /// The emoji that represents the style.
        var emojiValue: String {
            switch self {
            case .dislike: "👎"
            case .emphasis: "‼️"
            case .laugh: "😂"
            case .like: "👍"
            case .love: "❤️"
            case .question: "❓"
            }
        }

        /// The serialized representation of the style.
        var encodedValue: String {
            rawValue.uppercased()
        }

        /// The value that determines the style's position in display order.
        var orderValue: Int {
            switch self {
            case .dislike: 2
            case .emphasis: 4
            case .laugh: 3
            case .like: 1
            case .love: 0
            case .question: 5
            }
        }

        /// The background color for the style's square icon.
        var squareIconBackgroundColor: Color {
            switch self {
            case .dislike: .init(uiColor: .init(hex: 0xFF5252))
            case .emphasis: .init(uiColor: .init(hex: 0x0FB9B1))
            case .laugh: .init(uiColor: .init(hex: 0xC56CF0))
            case .like: .init(uiColor: .init(hex: 0x27AE60))
            case .love: .init(uiColor: .init(hex: 0x30AAF2))
            case .question: .init(uiColor: .init(hex: 0xFFB142))
            }
        }

        // MARK: - Init

        /// Creates a style from the given emoji.
        ///
        /// Returns `nil` if no style uses the emoji.
        ///
        /// - Parameter emojiValue: The emoji that represents the style.
        init?(emojiValue: String) {
            guard let matchingStyle = Style.emojiCaseMap[emojiValue] else { return nil }
            self = matchingStyle
        }

        /// Creates a style from its serialized representation.
        ///
        /// Returns `nil` if the value does not represent a known style.
        ///
        /// - Parameter encodedValue: The serialized representation of the style.
        init?(encodedValue: String) {
            guard let matchingCase = Style.allCases.first(where: {
                $0.encodedValue == encodedValue
            }) else { return nil }
            self = matchingCase
        }
    }

    // MARK: - Properties

    /// The reaction's style.
    let style: Style

    /// The identifier of the user who applied the reaction.
    let userID: String

    // MARK: - Init

    /// Creates a reaction with the given style and user identifier.
    ///
    /// - Parameters:
    ///   - style: The reaction's style.
    ///   - userID: The identifier of the user who applied the reaction.
    init(
        _ style: Style,
        userID: String
    ) {
        self.style = style
        self.userID = userID
    }

    /// Creates a reaction with the given style, applied by the current user.
    ///
    /// Returns `nil` if the current user identifier has not been set.
    ///
    /// - Parameter style: The reaction's style.
    init?(_ style: Style) {
        guard let currentUserID = User.currentUserID else { return nil }
        self = .init(style, userID: currentUserID)
    }
}
