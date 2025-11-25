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

    public var description: String {
        switch action {
        case let .addedToConversation(userID: userID):
            var otherUserDisplayName = displayName(for: userID)
            if otherUserDisplayName.isSomeoneOrYou {
                otherUserDisplayName = otherUserDisplayName.lowercased()
            }

            return Localized(.addedToConversation)
                .wrappedValue
                .replacingOccurrences(of: "⌘", with: "⌘\(displayName(for: self.userID))⌘")
                .replacingOccurrences(of: "⁂", with: "⌘\(otherUserDisplayName)⌘")

        case .leftConversation:
            return Localized(.leftConversation)
                .wrappedValue
                .replacingOccurrences(of: "⌘", with: "⌘\(displayName(for: userID))⌘")

        case let .removedFromConversation(userID: userID):
            var otherUserDisplayName = displayName(for: userID)
            if otherUserDisplayName.isSomeoneOrYou {
                otherUserDisplayName = otherUserDisplayName.lowercased()
            }

            return Localized(.removedFromConversation)
                .wrappedValue
                .replacingOccurrences(of: "⌘", with: "⌘\(displayName(for: self.userID))⌘")
                .replacingOccurrences(of: "⁂", with: "⌘\(otherUserDisplayName)⌘")
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

    public init?(_ action: Action) {
        guard let currentUserID = User.currentUserID else { return nil }
        self.init(
            action,
            date: .now,
            userID: currentUserID
        )
    }

    // MARK: - Auxiliary

    private func displayName(for userID: String) -> String {
        @Dependency(\.clientSession) var clientSession: ClientSession

        @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
        @Persistent(.conversationArchive) var conversationArchive: [Conversation]?
        guard userID != User.currentUserID else { return Localized(.you).wrappedValue }

        let conversationUsers = clientSession
            .conversation
            .fullConversation?
            .users ?? clientSession
            .conversation
            .currentConversation?
            .users ?? []

        let usersFromCurrentUserConversations = clientSession
            .user
            .currentUser?
            .conversations?
            .compactMap(\.users)
            .reduce([], +) ?? []

        let usersFromContactPairArchive = contactPairArchive?
            .map(\.users)
            .reduce([], +) ?? []

        let usersFromConversationArchive = conversationArchive?
            .compactMap(\.users)
            .reduce([], +) ?? []

        return (conversationUsers +
            usersFromCurrentUserConversations +
            usersFromContactPairArchive +
            usersFromConversationArchive)
            .unique
            .first(where: { $0.id == userID })?
            .displayName ?? Localized(.someone).wrappedValue
    }
}

private extension String {
    var isSomeoneOrYou: Bool {
        self == Localized(.someone).wrappedValue || self == Localized(.you).wrappedValue
    }
}
