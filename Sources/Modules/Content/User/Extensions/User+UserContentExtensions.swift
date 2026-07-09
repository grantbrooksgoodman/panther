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

    /// Resolves the current user's conversations and messages if they have not
    /// yet been loaded into memory.
    ///
    /// Under normal operation the splash screen resolves all conversation data
    /// before navigation occurs, so this method early-returns without performing
    /// work. It exists as a defensive guard for call sites that cannot
    /// structurally guarantee prior resolution — for example, code paths
    /// reachable after an interrupted startup or a mid-session state reset.
    ///
    /// The guard prevents an unconditional network fetch that
    /// `resolveCurrentUser(and:)` would otherwise perform.
    ///
    /// - NOTE: Since the SSoT refactor, the effective part of this method
    /// should never execute during normal use.
    static func resolveCurrentUserConversationsIfNeeded(
        includingMessages: Bool = false
    ) async throws(Exception) {
        @Dependency(\.clientSession.user) var userSession: UserSessionService
        guard let currentUser = userSession.currentUser else {
            throw Exception(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        guard currentUser.conversationIDs?.isEmpty == false,
              currentUser.conversations == nil ||
              currentUser.conversations?.isEmpty == true else { return }

        Logger.log(
            .init(
                "\(#function.components(separatedBy: "(")[0])() was called.",
                isReportable: false,
                metadata: .init(sender: self)
            ),
            domain: .bugPrevention,
            with: .toastInPrerelease(style: .warning),
            showRuntimeWarning: true
        )

        try await userSession.resolveCurrentUser(
            and: includingMessages ? [
                .conversations,
                .messages,
            ] : [.conversations]
        )
    }

    /// - Note: Will set the current user to the result returned by `update`.
    func removeCurrentPushToken() async throws(Exception) {
        @Dependency(\.commonServices.pushToken.currentToken) var currentPushToken: String?
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        guard let currentPushToken else { return }

        var filteredPushTokens = (pushTokens ?? []).filter { $0 != currentPushToken }
        if filteredPushTokens.isBangQualifiedEmpty {
            filteredPushTokens = .bangQualifiedEmpty
        }

        try await userSession.setCurrentUser(
            update(
                \.pushTokens,
                to: filteredPushTokens
            )
        )
    }

    /// - Note: Will set the current user to the result returned by `update`.
    func updateLastSignedInDate(
        to date: Date = .now
    ) async throws(Exception) {
        @Dependency(\.clientSession.user) var userSession: UserSessionService
        RuntimeStorage.store(date, as: .lastSignInDate)
        try await userSession.setCurrentUser(
            update(
                \.lastSignedIn,
                to: date
            )
        )
    }
}

enum UserDisplayNameCache {
    static func clearCache() {
        _UserDisplayNameCache.clearCache()
    }

    static func removeValues(forUserIDs ids: Set<String>) {
        _UserDisplayNameCache.removeValues(forUserIDs: ids)
    }
}

private enum _UserDisplayNameCache {
    // MARK: - Properties

    private static let _cachedDisplayNamesForUserIDs = LockIsolated<[String: String]?>(nil)

    // MARK: - Computed Properties

    fileprivate static var cachedDisplayNamesForUserIDs: [String: String]? {
        get { _cachedDisplayNamesForUserIDs.wrappedValue }
        set { _cachedDisplayNamesForUserIDs.wrappedValue = newValue }
    }

    // MARK: - Methods

    fileprivate static func clearCache() {
        cachedDisplayNamesForUserIDs = nil
    }

    fileprivate static func removeValues(forUserIDs ids: Set<String>) {
        guard var cache = cachedDisplayNamesForUserIDs else { return }
        for id in ids {
            cache[id] = nil
        }

        cachedDisplayNamesForUserIDs = cache
    }
}
