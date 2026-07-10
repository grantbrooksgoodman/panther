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
///     static let avatars = CacheDomain("avatars") {
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
                .messageArchive,
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
                .userArchive,
                .userDisplayName,
                .userService,
            ]
        }
    }

    // MARK: - Properties

    static let activityDescription = CacheDomain(
        "activityDescription"
    ) {
        ActivityDescriptionCache.clearCache()
    }

    static let audioFileDuration = CacheDomain(
        "audioFileDuration"
    ) {
        AudioFileDurationCache.clearCache()
    }

    static let chatInfoPageViewService = CacheDomain(
        "chatInfoPageViewService"
    ) {
        Task { @MainActor in
            @Dependency(\.chatInfoPageViewService) var chatInfoPageViewService: ChatInfoPageViewService
            chatInfoPageViewService.clearCache()
        }
    }

    static let commonPropertyLists = CacheDomain(
        "commonPropertyLists"
    ) {
        @Dependency(\.commonServices.propertyLists) var commonPropertyLists: CommonPropertyLists
        commonPropertyLists.clearCache()
    }

    static let contactImage = CacheDomain(
        "contactImage"
    ) {
        ContactImageCache.clearCache()
    }

    static let contactInitialsImage = CacheDomain(
        "contactInitialsImage"
    ) {
        Task { @MainActor in
            ContactInitialsImageCache.clearCache()
        }
    }

    static let contactPairArchive = CacheDomain(
        "contactPairArchive"
    ) {
        Task { @MainActor in
            @Dependency(\.commonServices.contact.contactPairArchive) var contactPairArchive: ContactPairArchiveService
            contactPairArchive.clearArchive()
        }
    }

    static let contactService = CacheDomain(
        "contactService"
    ) {
        Task { @MainActor in
            @Dependency(\.commonServices.contact) var contactService: ContactService
            contactService.clearCache()
        }
    }

    static let conversationArchive = CacheDomain(
        "conversationArchive"
    ) {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        sessionStore.clearConversationArchive()
    }

    static let conversationCellViewData = CacheDomain(
        "conversationCellViewData"
    ) {
        Task { @MainActor in
            ConversationCellViewDataCache.clearCache()
        }
    }

    static let mediaMessagePreviewService = CacheDomain(
        "mediaMessagePreviewService"
    ) {
        Task { @MainActor in
            @Dependency(\.chatPageViewService.mediaMessagePreview) var mediaMessagePreviewService: MediaMessagePreviewService?
            mediaMessagePreviewService?.clearCache()
        }
    }

    static let messageArchive = CacheDomain(
        "messageArchive"
    ) {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        sessionStore.clearMessageArchive()
    }

    static let queriedContactPairs = CacheDomain(
        "queriedContactPairs"
    ) {
        Task { @MainActor in
            QueriedContactPairCache.clearCache()
        }
    }

    static let queriedConversations = CacheDomain(
        "queriedConversations"
    ) {
        Task { @MainActor in
            QueriedConversationCache.clearCache()
        }
    }

    static let readReceipt = CacheDomain(
        "readReceipt"
    ) {
        ReadReceiptCache.clearCache()
    }

    static let regionDetailService = CacheDomain(
        "regionDetailService"
    ) {
        @Dependency(\.commonServices.regionDetail) var regionDetailService: RegionDetailService
        regionDetailService.clearCache()
    }

    static let settingsPageViewService = CacheDomain(
        "settingsPageViewService"
    ) {
        Task { @MainActor in
            @Dependency(\.settingsPageViewService) var settingsPageViewService: SettingsPageViewService
            settingsPageViewService.clearCache()
        }
    }

    static let squareIconImage = CacheDomain(
        "squareIconImage"
    ) {
        SquareIconImageCache.clearCache()
    }

    static let textToSpeechService = CacheDomain(
        "textToSpeechService"
    ) {
        TextToSpeechServiceCache.clearCache()
    }

    static let transcriptionService = CacheDomain(
        "transcriptionService"
    ) {
        TranscriptionServiceCache.clearCache()
    }

    static let userArchive = CacheDomain(
        "userArchive"
    ) {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        sessionStore.clearUserArchive()
    }

    static let userDisplayName = CacheDomain(
        "userDisplayName"
    ) {
        UserDisplayNameCache.clearCache()
    }

    static let userService = CacheDomain(
        "userService"
    ) {
        @Dependency(\.networking.userService) var userService: UserService
        userService.clearCache()
    }
}
