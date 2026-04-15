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

struct Activity: Codable, EncodedHashable, Equatable {
    // MARK: - Properties

    static let empty: Activity = .init(
        .leftConversation,
        date: .init(timeIntervalSince1970: 0),
        userID: .bangQualifiedEmpty
    )

    let action: Action
    let date: Date
    let userID: String

    // MARK: - Computed Properties

    @MainActor
    var description: String {
        if let cachedValue = _ActivityDescriptionCache.cachedDescriptionsForEncodedHashes?[encodedHash] {
            return cachedValue
        }

        var localizedString: String?

        switch action {
        case let .addedToConversation(userID: userID):
            var otherUserDisplayName = displayName(for: userID)
            if otherUserDisplayName.isSomeoneOrYou {
                otherUserDisplayName = otherUserDisplayName.lowercased()
            }

            localizedString = Localized(.addedToConversation)
                .wrappedValue
                .replacingOccurrences(of: "⌘", with: "⌘\(displayName(for: self.userID))⌘")
                .replacingOccurrences(of: "⁂", with: "⌘\(otherUserDisplayName)⌘")

        case .changedGroupPhoto:
            localizedString = Localized(.changedGroupPhoto)
                .wrappedValue
                .replacingOccurrences(of: "⌘", with: "⌘\(displayName(for: userID))⌘")

        case .leftConversation:
            localizedString = Localized(.leftConversation)
                .wrappedValue
                .replacingOccurrences(of: "⌘", with: "⌘\(displayName(for: userID))⌘")

        case let .removedFromConversation(userID: userID):
            var otherUserDisplayName = displayName(for: userID)
            if otherUserDisplayName.isSomeoneOrYou {
                otherUserDisplayName = otherUserDisplayName.lowercased()
            }

            localizedString = Localized(.removedFromConversation)
                .wrappedValue
                .replacingOccurrences(of: "⌘", with: "⌘\(displayName(for: self.userID))⌘")
                .replacingOccurrences(of: "⁂", with: "⌘\(otherUserDisplayName)⌘")

        case .removedGroupPhoto:
            localizedString = Localized(.removedGroupPhoto)
                .wrappedValue
                .replacingOccurrences(of: "⌘", with: "⌘\(displayName(for: userID))⌘")

        case .removedName:
            localizedString = Localized(.removedConversationName)
                .wrappedValue
                .replacingOccurrences(of: "⌘", with: "⌘\(displayName(for: userID))⌘")

        case let .renamedConversation(name: name):
            localizedString = Localized(.renamedConversation)
                .wrappedValue
                .replacingOccurrences(of: "⌘", with: "⌘\(displayName(for: userID))⌘")
                .replacingOccurrences(of: "⁂", with: "⌘“\(name)”⌘")
        }

        guard let localizedString else { return "�" }
        var cachedDescriptionsForEncodedHashes = _ActivityDescriptionCache.cachedDescriptionsForEncodedHashes ?? [:]
        cachedDescriptionsForEncodedHashes[encodedHash] = localizedString
        _ActivityDescriptionCache.cachedDescriptionsForEncodedHashes = cachedDescriptionsForEncodedHashes
        return localizedString
    }

    var hashFactors: [String] {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        return [
            action.rawValue,
            dateFormatter.string(from: date),
            userID,
        ].sorted()
    }

    var message: Message {
        .init(
            encodedHash,
            fromAccountID: CommonConstants.systemMessageID,
            contentType: .text,
            richContent: nil,
            translationReferences: [.init(
                languagePair: .system,
                type: .idempotent(encodedHash)
            )],
            translations: [
                .init(
                    input: .init(encodedHash),
                    output: encodedHash,
                    languagePair: .system
                ),
            ],
            readReceipts: nil,
            sentDate: date
        )
    }

    // MARK: - Init

    init(
        _ action: Action,
        date: Date,
        userID: String,
    ) {
        self.action = action
        self.date = date
        self.userID = userID
    }

    init?(_ action: Action) {
        guard let currentUserID = User.currentUserID else { return nil }
        self.init(
            action,
            date: .now,
            userID: currentUserID
        )
    }

    // MARK: - Auxiliary

    @MainActor
    private func displayName(for userID: String) -> String {
        guard userID != User.currentUserID else { return Localized(.you).wrappedValue }
        return UserCache
            .knownUsers
            .first(where: { $0.id == userID })?
            .displayName ?? Localized(.someone).wrappedValue
    }
}

enum ActivityDescriptionCache {
    static func clearCache() {
        _ActivityDescriptionCache.clearCache()
    }
}

private enum _ActivityDescriptionCache {
    // MARK: - Properties

    private static let _cachedDescriptionsForEncodedHashes = LockIsolated<[String: String]?>(wrappedValue: nil)

    // MARK: - Computed Properties

    fileprivate static var cachedDescriptionsForEncodedHashes: [String: String]? {
        get { _cachedDescriptionsForEncodedHashes.wrappedValue }
        set { _cachedDescriptionsForEncodedHashes.wrappedValue = newValue }
    }

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedDescriptionsForEncodedHashes = nil
    }
}

private extension String {
    var isSomeoneOrYou: Bool {
        self == Localized(.someone).wrappedValue || self == Localized(.you).wrappedValue
    }
}
