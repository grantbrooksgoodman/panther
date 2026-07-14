//
//  ClientSession.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

final class ClientSession: @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.networking.database) private var database: DatabaseDelegate

    // MARK: - Properties

    let activity: ActivitySessionService
    let conversation: ConversationSessionService
    let conversationObserver: ConversationObserverService
    let message: MessageSessionService
    let moderation: ModerationSessionService
    let reaction: ReactionSessionService
    let storage: StorageSessionService
    let store: SessionStore
    let user: UserSessionService

    private let _deliveryProgressIndicator = LockIsolated<DeliveryProgressIndicator?>(nil)

    // MARK: - Computed Properties

    var deliveryProgressIndicator: DeliveryProgressIndicator? {
        get { _deliveryProgressIndicator.wrappedValue }
        set { _deliveryProgressIndicator.wrappedValue = newValue }
    }

    // MARK: - Init

    init(
        activity: ActivitySessionService,
        conversation: ConversationSessionService,
        conversationObserver: ConversationObserverService,
        message: MessageSessionService,
        moderation: ModerationSessionService,
        reaction: ReactionSessionService,
        storage: StorageSessionService,
        store: SessionStore,
        user: UserSessionService
    ) {
        self.activity = activity
        self.conversation = conversation
        self.conversationObserver = conversationObserver
        self.message = message
        self.moderation = moderation
        self.reaction = reaction
        self.storage = storage
        self.store = store
        self.user = user
    }

    // MARK: - Register Delivery Progress Indicator

    func registerDeliveryProgressIndicator(
        _ deliveryProgressIndicator: DeliveryProgressIndicator
    ) {
        self.deliveryProgressIndicator = deliveryProgressIndicator
    }

    // MARK: - Resolve and Set Language Code

    func resolveAndSetLanguageCode() async throws(Exception) {
        @Persistent(.currentUserID) var currentUserID: String?
        guard let currentUserID else {
            throw Exception(
                "Current user ID has not been set.",
                metadata: .init(sender: self)
            )
        }

        let languageCode: String = try await database.getValues(
            at: [
                NetworkPath.users.rawValue,
                currentUserID,
                User.SerializableKey.languageCode.rawValue,
            ].joined(separator: "/")
        )

        Logger.log(
            "Setting language code to \(languageCode.englishLanguageName ?? languageCode.uppercased()).",
            domain: .clientSession,
            sender: self
        )

        coreUtilities.setLanguageCode(languageCode)
    }
}
