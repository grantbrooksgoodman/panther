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

    /// The contact pair matching this user in the contact pair archive, if one exists.
    var contactPair: ContactPair? {
        @Dependency(\.commonServices.contact.contactPairArchive) var contactPairArchive: ContactPairArchiveService
        return contactPairArchive.getValue(phoneNumber: phoneNumber)
    }

    /// The user's display name.
    ///
    /// Resolves to the user's obfuscated PenPals name while their identity is obfuscated, their
    /// contact's full name when known, or their formatted phone number otherwise. Results are
    /// cached in memory per user.
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

    /// The identifier of the signed-in user, from the current session or persisted storage, or
    /// `nil` if no user is signed in.
    static var currentUserID: String? {
        @Persistent(.currentUserID) var persistedValue: String?
        @Dependency(\.clientSession.entity.user.currentUser?.id) var sessionValue: String?
        return sessionValue ?? persistedValue
    }

    /// The color of the user's PenPals icon, derived from their language or region flag, or `nil`
    /// if one cannot be determined.
    var penPalsIconColor: UIColor? {
        (
            UIImage(
                named: "\(languageCode.lowercased()).png"
            ) ?? .init(
                named: "\(phoneNumber.regionCode.lowercased()).png"
            )
        )?.averageColor
    }

    /// The user's obfuscated PenPals display name, based on the region of their phone number.
    var penPalsName: String {
        @Dependency(\.commonServices.regionDetail) var regionDetailService: RegionDetailService
        let localizedRegionName = regionDetailService.localizedRegionName(regionCode: phoneNumber.regionCode)
        return RuntimeStorage.languageCode == "en" ? "PenPal from \(localizedRegionName)" : "PenPal (\(localizedRegionName))"
    }

    // MARK: - Methods

    /// Removes the device's current push token from the user's push tokens.
    ///
    /// This method has no effect when no current push token is available.
    ///
    /// - Throws: An `Exception` if updating the user fails.
    func removeCurrentPushToken() async throws(Exception) {
        @Dependency(\.commonServices.pushToken.currentToken) var currentPushToken: String?

        guard let currentPushToken else { return }

        var filteredPushTokens = (pushTokens ?? []).filter { $0 != currentPushToken }
        if filteredPushTokens.isBangQualifiedEmpty {
            filteredPushTokens = .bangQualifiedEmpty
        }

        _ = try await update(
            \.pushTokens,
            to: filteredPushTokens
        )
    }

    /// Updates the user's device identifier to the current device's, if it differs.
    ///
    /// - Throws: An `Exception` if updating the user fails.
    func updateDeviceIDIfNeeded() async throws(Exception) {
        if deviceID != DeviceID.current {
            _ = try await update(
                \.deviceID,
                to: DeviceID.current
            )
        }
    }
}

/// A namespace for managing the in-memory user display name cache.
enum UserDisplayNameCache {
    /// Removes every cached user display name.
    static func clearCache() {
        _UserDisplayNameCache.clearCache()
    }

    /// Removes the cached display names for the given user identifiers.
    ///
    /// - Parameter ids: The identifiers of the users whose cached display names to remove.
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
