//
//  CacheDomains.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 18/08/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking
import Translator

public extension CacheDomain {
    // MARK: - Types

    struct List: AppSubsystem.Delegates.CacheDomainListDelegate {
        public var allCacheDomains: [CacheDomain] {
            [
                .chatInfoPageViewService,
                .commonPropertyLists,
                .contactImage,
                .contactPairArchive,
                .contactService,
                .conversationArchive,
                .database,
                .encodedHash,
                .localization,
                .localTranslationArchive,
                .mediaMessagePreviewService,
                .queriedContactPairs,
                .regionDetailService,
                .settingsPageViewService,
                .storage,
                .userService,
            ]
        }
    }

    // MARK: - Properties

    static let chatInfoPageViewService: CacheDomain = .init("chatInfoPageViewService")
    static let commonPropertyLists: CacheDomain = .init("commonPropertyLists")
    static let contactImage: CacheDomain = .init("contactImage")
    static let contactPairArchive: CacheDomain = .init("contactPairArchive")
    static let contactService: CacheDomain = .init("contactService")
    static let conversationArchive: CacheDomain = .init("conversationArchive")
    static let database: CacheDomain = .init("database") // TODO: NEEDS TO BE IN NETWORKING
    static let localization: CacheDomain = .init("localization")
    static let mediaMessagePreviewService: CacheDomain = .init("mediaMessagePreviewService")
    static let queriedContactPairs: CacheDomain = .init("queriedContactPairs")
    static let regionDetailService: CacheDomain = .init("regionDetailService")
    static let settingsPageViewService: CacheDomain = .init("settingsPageViewService")
    static let storage: CacheDomain = .init("storage")
    static let userService: CacheDomain = .init("userService")
}

public extension CoreKit.Utilities {
    func clearCaches(_ domains: [CacheDomain] = CacheDomain.allCases) {
        @Dependency(\.chatInfoPageViewService) var chatInfoPageViewService: ChatInfoPageViewService
        @Dependency(\.commonServices) var commonServices: CommonServices
        @Dependency(\.chatPageViewService.mediaMessagePreview) var mediaMessagePreviewService: MediaMessagePreviewService?
        @Dependency(\.networking) var networking: NetworkServices
        @Dependency(\.settingsPageViewService) var settingsPageViewService: SettingsPageViewService

        let appDomains = clearCaches(domains: domains)

        if appDomains.contains(.chatInfoPageViewService) { chatInfoPageViewService.clearCache() }
        if appDomains.contains(.commonPropertyLists) { commonServices.propertyLists.clearCache() }
        if appDomains.contains(.contactImage) { ContactImageCache.clearCache() }
        if appDomains.contains(.contactPairArchive) { commonServices.contact.contactPairArchive.clearArchive() }
        if appDomains.contains(.contactService) { commonServices.contact.clearCache() }
        if appDomains.contains(.conversationArchive) { networking.conversationService.archive.clearArchive() }
        if appDomains.contains(.database) { CoreDatabaseCache.clear() }
        if appDomains.contains(.localization) { Localization.clearCache() }
        if appDomains.contains(.mediaMessagePreviewService) { mediaMessagePreviewService?.clearCache() }
        if appDomains.contains(.queriedContactPairs) { QueriedContactPairCache.clearCache() }
        if appDomains.contains(.regionDetailService) { commonServices.regionDetail.clearCache() }
        if appDomains.contains(.settingsPageViewService) { settingsPageViewService.clearCache() }
        if appDomains.contains(.storage) { networking.storage.clearCache() }
        if appDomains.contains(.userService) { networking.userService.clearCache() }
    }
}
