//
//  Activity.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Translator

public struct Activity: Codable, EncodedHashable, Equatable {
    // MARK: - Properties

    public static let empty: Activity = .init(
        .leftConversation,
        date: .init(timeIntervalSince1970: 0),
        userID: .bangQualifiedEmpty
    )

    public let action: Action
    public let date: Date
    public let userID: String

    // MARK: - Computed Properties

    // TODO: Get localized strings for these.
    public var description: String {
        switch action {
        case let .addedToConversation(userID: userID):
            return "⌘\(displayName(for: self.userID))⌘ added ⌘\(displayName(for: userID))⌘ to the conversation."

        case .leftConversation:
            return "⌘\(displayName(for: userID))⌘ left the conversation."

        case let .removedFromConversation(userID: userID):
            return "⌘\(displayName(for: self.userID))⌘ removed ⌘\(displayName(for: userID))⌘ from the conversation."
        }
    }

    public var hashFactors: [String] {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        return [
            action.rawValue,
            dateFormatter.string(from: date),
            userID,
        ]
    }

    public var message: Message {
        .init(
            "\(CommonConstants.systemMessageID)_\(date.timeIntervalSince1970)",
            fromAccountID: CommonConstants.systemMessageID,
            contentType: .text,
            richContent: nil,
            translationReferences: [.init(
                languagePair: .system,
                type: .idempotent(
                    description.data(using: .utf8)?.base64EncodedString() ?? description
                )
            )],
            translations: [
                .init(
                    input: .init(action.rawValue),
                    output: action.rawValue,
                    languagePair: .system
                ),
            ],
            readReceipts: nil,
            sentDate: date
        )
    }

    // MARK: - Init

    public init(
        _ action: Action,
        date: Date,
        userID: String,
    ) {
        self.action = action
        self.date = date
        self.userID = userID
    }

    // MARK: - Auxiliary

    private func displayName(for userID: String) -> String {
        @Dependency(\.clientSession.conversation.fullConversation) var conversation: Conversation?
        guard userID != User.currentUserID else { return Localized(.you).wrappedValue }
        guard let user = conversation?.users?.first(where: { $0.id == userID }) else { return "Someone" }
        return user.displayName
    }
}
