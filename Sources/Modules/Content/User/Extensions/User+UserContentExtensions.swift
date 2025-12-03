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

        let displayName = contactPair?.contact.fullName ?? phoneNumber.formattedString()
        cache(displayName)
        return displayName
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
