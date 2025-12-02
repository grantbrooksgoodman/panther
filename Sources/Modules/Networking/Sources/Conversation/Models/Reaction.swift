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

struct Reaction: Codable, Hashable {
    // MARK: - Types

    enum Style: String, CaseIterable, Codable, Hashable {
        // MARK: - Cases

        case dislike
        case emphasis
        case laugh
        case like
        case love
        case question

        // MARK: - Properties

        static var orderedCases: [Style] = allCases.sorted(by: { $0.orderValue < $1.orderValue })

        private static let emojiCaseMap: [String: Style] = Dictionary(uniqueKeysWithValues: Style.allCases.map { ($0.emojiValue, $0) })

        // MARK: - Computed Properties

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

        var encodedValue: String { rawValue.uppercased() }

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

        init?(emojiValue: String) {
            guard let matchingStyle = Style.emojiCaseMap[emojiValue] else { return nil }
            self = matchingStyle
        }

        init?(encodedValue: String) {
            guard let matchingCase = Style.allCases.first(where: { $0.encodedValue == encodedValue }) else { return nil }
            self = matchingCase
        }
    }

    // MARK: - Properties

    let style: Style
    let userID: String

    // MARK: - Init

    init(
        _ style: Style,
        userID: String
    ) {
        self.style = style
        self.userID = userID
    }

    init?(_ style: Style) {
        guard let currentUserID = User.currentUserID else { return nil }
        self = .init(style, userID: currentUserID)
    }
}
