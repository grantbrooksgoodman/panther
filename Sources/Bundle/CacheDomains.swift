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

/// Use this extension to register application-specific cache domains.
///
/// Add ``CacheDomain`` values to the ``List/appCacheDomains`` array
/// so they are included alongside the subsystem's built-in domains.
/// Registered domains are cleared during memory-pressure cleanup.
///
/// ```swift
/// extension CacheDomain {
///     static let avatars: CacheDomain = .init("avatars") {
///         AvatarCache.shared.clear()
///     }
/// }
/// ```
///
/// Then add the new domain to ``List/appCacheDomains``:
///
/// ```swift
/// let appCacheDomains: [CacheDomain] = [.avatars]
/// ```
extension CacheDomain {
    // MARK: - Types

    /// The delegate that supplies the app's cache domains to the
    /// subsystem.
    ///
    /// The subsystem merges these domains with its own built-in
    /// domains automatically.
    struct List: AppSubsystem.Delegates.CacheDomainListDelegate {
        /// The cache domains defined by this app.
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
                .readReceipt,
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
    static let readReceipt: CacheDomain = .init("readReceipt") { clearReadReceiptCache() }
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
        Task { @MainActor in
            @Dependency(\.chatInfoPageViewService) var chatInfoPageViewService: ChatInfoPageViewService
            chatInfoPageViewService.clearCache()
        }
    }

    private static func clearCommonPropertyListsCache() {
        @Dependency(\.commonServices.propertyLists) var commonPropertyLists: CommonPropertyLists
        commonPropertyLists.clearCache()
    }

    private static func clearContactImageCache() {
        ContactImageCache.clearCache()
    }

    private static func clearContactInitialsImageCache() {
        Task { @MainActor in
            ContactInitialsImageCache.clearCache()
        }
    }

    private static func clearContactPairArchiveCache() {
        Task { @MainActor in
            @Dependency(\.commonServices.contact.contactPairArchive) var contactPairArchive: ContactPairArchiveService
            contactPairArchive.clearArchive()
        }
    }

    private static func clearContactServiceCache() {
        Task { @MainActor in
            @Dependency(\.commonServices.contact) var contactService: ContactService
            contactService.clearCache()
        }
    }

    private static func clearConversationArchiveCache() {
        @Dependency(\.networking.conversationService.archive) var conversationArchive: ConversationArchiveService
        conversationArchive.clearArchive()
    }

    private static func clearConversationCellViewDataCache() {
        Task { @MainActor in
            ConversationCellViewDataCache.clearCache()
        }
    }

    private static func clearMediaMessagePreviewServiceCache() {
        Task { @MainActor in
            @Dependency(\.chatPageViewService.mediaMessagePreview) var mediaMessagePreviewService: MediaMessagePreviewService?
            mediaMessagePreviewService?.clearCache()
        }
    }

    private static func clearQueriedContactPairsCache() {
        Task { @MainActor in
            QueriedContactPairCache.clearCache()
        }
    }

    private static func clearQueriedConversationCache() {
        Task { @MainActor in
            QueriedConversationCache.clearCache()
        }
    }

    private static func clearReadReceiptCache() {
        ReadReceiptCache.clearCache()
    }

    private static func clearRegionDetailServiceCache() {
        @Dependency(\.commonServices.regionDetail) var regionDetailService: RegionDetailService
        regionDetailService.clearCache()
    }

    private static func clearSettingsPageViewServiceCache() {
        Task { @MainActor in
            @Dependency(\.settingsPageViewService) var settingsPageViewService: SettingsPageViewService
            settingsPageViewService.clearCache()
        }
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
        Task { @MainActor in
            UserCache.clearCache()
        }
    }

    private static func clearUserDisplayNameCache() {
        UserDisplayNameCache.clearCache()
    }

    private static func clearUserServiceCache() {
        @Dependency(\.networking.userService) var userService: UserService
        userService.clearCache()
    }
}
