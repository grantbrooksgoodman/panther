//
//  CacheDomains.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 18/08/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture
import Translator

public extension CoreKit.Utilities {
    // MARK: - Types

    enum CacheDomain: CaseIterable {
        case chatInfoPageViewService
        case commonPropertyLists
        case contactImage
        case contactPairArchive
        case contactService
        case conversationArchive
        case database
        case encodedHash
        case localization
        case localTranslationArchive
        case mediaMessagePreviewService
        case regionDetailService
        case settingsPageViewService
        case storage
        case userService
    }

    // MARK: - Clear Caches

    func clearCaches(domains: [CacheDomain] = CacheDomain.allCases) {
        @Dependency(\.chatInfoPageViewService) var chatInfoPageViewService: ChatInfoPageViewService
        @Dependency(\.commonServices) var commonServices: CommonServices
        @Dependency(\.localTranslationArchiver) var localTranslationArchiver: LocalTranslationArchiverDelegate
        @Dependency(\.chatPageViewService.mediaMessagePreview) var mediaMessagePreviewService: MediaMessagePreviewService?
        @Dependency(\.networking) var networking: Networking
        @Dependency(\.settingsPageViewService) var settingsPageViewService: SettingsPageViewService

        if domains.contains(.chatInfoPageViewService) { chatInfoPageViewService.clearCache() }
        if domains.contains(.commonPropertyLists) { commonServices.propertyLists.clearCache() }
        if domains.contains(.contactImage) { ContactImageCache.clearCache() }
        if domains.contains(.contactPairArchive) { commonServices.contact.contactPairArchive.clearArchive() }
        if domains.contains(.contactService) { commonServices.contact.clearCache() }
        if domains.contains(.conversationArchive) { networking.services.conversation.archive.clearArchive() }
        if domains.contains(.database) { networking.database.clearCache() }
        if domains.contains(.encodedHash) { EncodedHashCache.clearCache() }
        if domains.contains(.localTranslationArchive) { localTranslationArchiver.clearArchive() }
        if domains.contains(.localization) { Localization.clearCache() }
        if domains.contains(.mediaMessagePreviewService) { mediaMessagePreviewService?.clearCache() }
        if domains.contains(.regionDetailService) { commonServices.regionDetail.clearCache() }
        if domains.contains(.settingsPageViewService) { settingsPageViewService.clearCache() }
        if domains.contains(.storage) { networking.storage.clearCache() }
        if domains.contains(.userService) { networking.services.user.clearCache() }
    }
}
