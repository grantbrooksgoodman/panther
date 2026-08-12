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

/// A recorded change to a conversation, such as a participant joining, leaving, or renaming it.
struct Activity: Codable, EncodedHashable, Equatable {
    // MARK: - Properties

    /// An empty activity placeholder.
    static let empty: Activity = .init(
        .leftConversation,
        date: .init(timeIntervalSince1970: 0),
        userID: .bangQualifiedEmpty
    )

    /// The kind of change the activity records.
    let action: Action

    /// The date the change occurred.
    let date: Date

    /// The identifier of the user responsible for the change.
    let userID: String

    // MARK: - Computed Properties

    /// A localized description of the activity, suitable for display.
    ///
    /// The description is resolved once per activity version and cached in memory.
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
                .replacingOccurrences(of: "⌘", with: "⌘\(displayName(phoneNumberString: userID))⌘")

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

    /// The strings that collectively define this instance's identity for hashing purposes, sorted
    /// alphabetically.
    var hashFactors: [String] {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        return [
            action.rawValue,
            dateFormatter.string(from: date),
            userID,
        ].sorted()
    }

    /// A system message that represents the activity in a conversation.
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

    /// Creates an activity with the given properties.
    ///
    /// - Parameters:
    ///   - action: The kind of change the activity records.
    ///   - date: The date the change occurred.
    ///   - userID: The identifier of the user responsible for the change.
    init(
        _ action: Action,
        date: Date,
        userID: String
    ) {
        self.action = action
        self.date = date
        self.userID = userID
    }

    /// Creates an activity for the given action, attributed to the current user and dated now.
    ///
    /// Returns `nil` if the current user is unavailable.
    ///
    /// - Parameter action: The kind of change the activity records.
    init?(_ action: Action) {
        guard let currentUserID = User.currentUserID else { return nil }
        switch action {
        case .leftConversation:
            @Dependency(\.clientSession.entity.user.currentUser) var currentUser: User?
            guard let currentUser else { return nil }
            self.init(
                action,
                date: .now,
                userID: currentUser.phoneNumber.compiledNumberString
            )

        default:
            self.init(
                action,
                date: .now,
                userID: currentUserID
            )
        }
    }

    // MARK: - Auxiliary

    @MainActor
    private func displayName(for userID: String) -> String {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        guard userID != User.currentUserID else { return Localized(.you).wrappedValue }
        return sessionStore.users[userID]?.displayName ?? Localized(.someone).wrappedValue
    }

    @MainActor
    private func displayName(phoneNumberString: String) -> String {
        @Dependency(\.clientSession) var clientSession: ClientSession

        // NIT: Backward compatibility. Remove in a future update.
        guard phoneNumberString.filter(\.isLetter).isEmpty else {
            return displayName(for: phoneNumberString)
        }

        let currentUser = clientSession.entity.user.currentUser
        guard phoneNumberString != currentUser?
            .phoneNumber
            .compiledNumberString else { return Localized(.you).wrappedValue }

        return clientSession
            .store
            .users
            .values
            .first(where: {
                $0.phoneNumber.compiledNumberString == phoneNumberString
            })?
            .displayName ?? PhoneNumber(phoneNumberString).formattedString()
    }
}

/// A namespace for managing the in-memory activity description cache.
enum ActivityDescriptionCache {
    /// Removes every cached activity description.
    static func clearCache() {
        _ActivityDescriptionCache.clearCache()
    }
}

private enum _ActivityDescriptionCache {
    // MARK: - Properties

    private static let _cachedDescriptionsForEncodedHashes = LockIsolated<[String: String]?>(nil)

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
