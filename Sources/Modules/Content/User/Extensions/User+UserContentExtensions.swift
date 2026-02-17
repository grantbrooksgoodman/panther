//
//  User+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 06/01/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

extension User {
    // MARK: - Properties

    var contactPair: ContactPair? {
        @Dependency(\.commonServices.contact.contactPairArchive) var contactPairArchive: ContactPairArchiveService
        return contactPairArchive.getValue(phoneNumber: phoneNumber)
    }

    var displayName: String {
        @Dependency(\.commonServices.penPals) var penPalsService: PenPalsService

        func cache(_ displayName: String) {
            var cachedDisplayNamesForUserIDs = _UserDisplayNameCache.cachedDisplayNamesForUserIDs ?? [:]
            cachedDisplayNamesForUserIDs[id] = displayName
            _UserDisplayNameCache.cachedDisplayNamesForUserIDs = cachedDisplayNamesForUserIDs
        }

        if let cachedValue = _UserDisplayNameCache.cachedDisplayNamesForUserIDs?[id] {
            return cachedValue
        }

        if penPalsService.isObfuscatedPenPalWithCurrentUser(self),
           !penPalsService.isKnownToCurrentUser(id) {
            let penPalsName = penPalsName
            cache(penPalsName)
            return penPalsName
        }

        if let contactPairName = contactPair?.contact.fullName,
           !contactPairName.isBlank {
            cache(contactPairName)
            return contactPairName
        }

        let formattedPhoneNumberString = phoneNumber.formattedString()
        cache(formattedPhoneNumberString)
        return formattedPhoneNumberString
    }

    static var currentUserID: String? {
        @Persistent(.currentUserID) var persistedValue: String?
        @Dependency(\.clientSession.user.currentUser?.id) var sessionValue: String?
        return sessionValue ?? persistedValue
    }

    var penPalsIconColor: UIColor? {
        (
            UIImage(
                named: "\(languageCode.lowercased()).png"
            ) ?? .init(
                named: "\(phoneNumber.regionCode.lowercased()).png"
            )
        )?.averageColor
    }

    var penPalsName: String {
        @Dependency(\.commonServices.regionDetail) var regionDetailService: RegionDetailService
        let localizedRegionName = regionDetailService.localizedRegionName(regionCode: phoneNumber.regionCode)
        return RuntimeStorage.languageCode == "en" ? "PenPal from \(localizedRegionName)" : "PenPal (\(localizedRegionName))"
    }

    // MARK: - Methods

    // NIT: I don't like the fact that this method is needed/useful. Seems like code smell.
    static func populateCurrentUserConversationsIfNeeded() async -> Exception? {
        func satisfiesConstraints(_ conversation: Conversation) -> Bool {
            let filteringSystemMessages = conversation.filteringSystemMessages
            if !filteringSystemMessages.messageIDs.isBangQualifiedEmpty,
               filteringSystemMessages.messages == nil ||
               filteringSystemMessages.messages?.isEmpty == true {
                return true
            } else if filteringSystemMessages.messageIDs.count != filteringSystemMessages.messages?.count {
                return true
            }

            return false
        }

        @Dependency(\.clientSession.user.currentUser) var currentUser: User?
        guard let currentUser else {
            return .init(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        guard currentUser.conversationIDs?.isEmpty == false,
              currentUser.conversations == nil ||
              currentUser.conversations?.isEmpty == true ||
              currentUser
              .conversations?
              .visibleForCurrentUser
              .contains(where: { satisfiesConstraints($0) }) == true else {
            return nil
        }

        if let exception = await currentUser.setConversations() {
            return exception
        }

        for conversation in (currentUser.conversations ?? [])
            .visibleForCurrentUser
            .filter({ satisfiesConstraints($0) }) {
            if let exception = await conversation.setMessages() {
                return exception
            }
        }

        return nil
    }

    /// - Note: Will set the current user to the result returned by `updateValue`.
    func removeCurrentPushToken() async -> Exception? {
        @Dependency(\.commonServices.pushToken.currentToken) var currentPushToken: String?
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        guard let currentPushToken else { return nil }

        var filteredPushTokens = (pushTokens ?? []).filter { $0 != currentPushToken }
        if filteredPushTokens.isBangQualifiedEmpty {
            filteredPushTokens = .bangQualifiedEmpty
        }

        let updateValueResult = await updateValue(
            filteredPushTokens,
            forKey: .pushTokens
        )

        switch updateValueResult {
        case let .success(user): return userSession.setCurrentUser(user)
        case let .failure(exception): return exception
        }
    }

    /// - Note: Will set the current user to the result returned by `updateValue`.
    func updateLastSignedInDate(
        to date: Date = .now
    ) async -> Exception? {
        @Dependency(\.clientSession.user) var userSession: UserSessionService
        let updateValueResult = await updateValue(
            date,
            forKey: .lastSignedIn
        )

        switch updateValueResult {
        case let .success(user): return userSession.setCurrentUser(user)
        case let .failure(exception): return exception
        }
    }
}

enum UserDisplayNameCache {
    static func clearCache() {
        _UserDisplayNameCache.clearCache()
    }
}

private enum _UserDisplayNameCache {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case displayNamesForUserIDs
    }

    // MARK: - Properties

    @Cached(CacheKey.displayNamesForUserIDs) fileprivate static var cachedDisplayNamesForUserIDs: [String: String]?

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedDisplayNamesForUserIDs = nil
    }
}
