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

extension CacheDomain {
    // MARK: - Types

    struct List: AppSubsystem.Delegates.CacheDomainListDelegate {
        var appCacheDomains: [CacheDomain] {
            [
                .activityDescription,
                .audioFileDuration,
                .chatInfoPageViewService,
                .commonPropertyLists,
                .contactImage,
                .contactInitialsImage,
                .contactPairArchive,
                .contactService,
                .conversationArchive,
                .conversationCellViewData,
                .mediaMessagePreviewService,
                .Networking.database,
                .Networking.gemini,
                .Networking.storage,
                .queriedContactPairs,
                .queriedConversations,
                .regionDetailService,
                .settingsPageViewService,
                .squareIconImage,
                .textToSpeechService,
                .transcriptionService,
                .user,
                .userDisplayName,
                .userService,
            ]
        }
    }

    // MARK: - Properties

    static let activityDescription: CacheDomain = .init("activityDescription") { clearActivityDescriptionCache() }
    static let audioFileDuration: CacheDomain = .init("audioFileDuration") { clearAudioFileDurationCache() }
    static let chatInfoPageViewService: CacheDomain = .init("chatInfoPageViewService") { clearChatInfoPageViewServiceCache() }
    static let commonPropertyLists: CacheDomain = .init("commonPropertyLists") { clearCommonPropertyListsCache() }
    static let contactImage: CacheDomain = .init("contactImage") { clearContactImageCache() }
    static let contactInitialsImage: CacheDomain = .init("contactInitialsImage") { clearContactInitialsImageCache() }
    static let contactPairArchive: CacheDomain = .init("contactPairArchive") { clearContactPairArchiveCache() }
    static let contactService: CacheDomain = .init("contactService") { clearContactServiceCache() }
    static let conversationArchive: CacheDomain = .init("conversationArchive") { clearConversationArchiveCache() }
    static let conversationCellViewData: CacheDomain = .init("conversationCellViewData") { clearConversationCellViewDataCache() }
    static let mediaMessagePreviewService: CacheDomain = .init("mediaMessagePreviewService") { clearMediaMessagePreviewServiceCache() }
    static let queriedContactPairs: CacheDomain = .init("queriedContactPairs") { clearQueriedContactPairsCache() }
    static let queriedConversations: CacheDomain = .init("queriedConversations") { clearQueriedConversationCache() }
    static let regionDetailService: CacheDomain = .init("regionDetailService") { clearRegionDetailServiceCache() }
    static let settingsPageViewService: CacheDomain = .init("settingsPageViewService") { clearSettingsPageViewServiceCache() }
    static let squareIconImage: CacheDomain = .init("squareIconImage") { clearSquareIconImageCache() }
    static let textToSpeechService: CacheDomain = .init("textToSpeechService") { clearTextToSpeechServiceCache() }
    static let transcriptionService: CacheDomain = .init("transcriptionService") { clearTranscriptionServiceCache() }
    static let user: CacheDomain = .init("user") { clearUserCache() }
    static let userDisplayName: CacheDomain = .init("userDisplayName") { clearUserDisplayNameCache() }
    static let userService: CacheDomain = .init("userService") { clearUserServiceCache() }

    // MARK: - Methods

    private static func clearActivityDescriptionCache() {
        ActivityDescriptionCache.clearCache()
    }

    private static func clearAudioFileDurationCache() {
        AudioFileDurationCache.clearCache()
    }

    private static func clearChatInfoPageViewServiceCache() {
        @Dependency(\.chatInfoPageViewService) var chatInfoPageViewService: ChatInfoPageViewService
        chatInfoPageViewService.clearCache()
    }

    private static func clearCommonPropertyListsCache() {
        @Dependency(\.commonServices.propertyLists) var commonPropertyLists: CommonPropertyLists
        commonPropertyLists.clearCache()
    }

    private static func clearContactImageCache() {
        ContactImageCache.clearCache()
    }

    private static func clearContactInitialsImageCache() {
        ContactInitialsImageCache.clearCache()
    }

    private static func clearContactPairArchiveCache() {
        @Dependency(\.commonServices.contact.contactPairArchive) var contactPairArchive: ContactPairArchiveService
        contactPairArchive.clearArchive()
    }

    private static func clearContactServiceCache() {
        @Dependency(\.commonServices.contact) var contactService: ContactService
        contactService.clearCache()
    }

    private static func clearConversationArchiveCache() {
        @Dependency(\.networking.conversationService.archive) var conversationArchive: ConversationArchiveService
        conversationArchive.clearArchive()
    }

    private static func clearConversationCellViewDataCache() {
        ConversationCellViewDataCache.clearCache()
    }

    private static func clearMediaMessagePreviewServiceCache() {
        @Dependency(\.chatPageViewService.mediaMessagePreview) var mediaMessagePreviewService: MediaMessagePreviewService?
        mediaMessagePreviewService?.clearCache()
    }

    private static func clearQueriedContactPairsCache() {
        QueriedContactPairCache.clearCache()
    }

    private static func clearQueriedConversationCache() {
        QueriedConversationCache.clearCache()
    }

    private static func clearRegionDetailServiceCache() {
        @Dependency(\.commonServices.regionDetail) var regionDetailService: RegionDetailService
        regionDetailService.clearCache()
    }

    private static func clearSettingsPageViewServiceCache() {
        @Dependency(\.settingsPageViewService) var settingsPageViewService: SettingsPageViewService
        settingsPageViewService.clearCache()
    }

    private static func clearSquareIconImageCache() {
        SquareIconImageCache.clearCache()
    }

    private static func clearTextToSpeechServiceCache() {
        TextToSpeechServiceCache.clearCache()
    }

    private static func clearTranscriptionServiceCache() {
        TranscriptionServiceCache.clearCache()
    }

    private static func clearUserCache() {
        UserCache.clearCache()
    }

    private static func clearUserDisplayNameCache() {
        UserDisplayNameCache.clearCache()
    }

    private static func clearUserServiceCache() {
        @Dependency(\.networking.userService) var userService: UserService
        userService.clearCache()
    }
}
