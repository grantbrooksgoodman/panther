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

final class ClientSession: @unchecked Sendable {
    // MARK: - Properties

    let activity: ActivitySessionService
    let conversation: ConversationSessionService
    let message: MessageSessionService
    let moderation: ModerationSessionService
    let reaction: ReactionSessionService
    let storage: StorageSessionService
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
        message: MessageSessionService,
        moderation: ModerationSessionService,
        reaction: ReactionSessionService,
        storage: StorageSessionService,
        user: UserSessionService
    ) {
        self.activity = activity
        self.conversation = conversation
        self.message = message
        self.moderation = moderation
        self.reaction = reaction
        self.storage = storage
        self.user = user
    }

    // MARK: - Register Delivery Progress Indicator

    func registerDeliveryProgressIndicator(_ deliveryProgressIndicator: DeliveryProgressIndicator) {
        self.deliveryProgressIndicator = deliveryProgressIndicator
    }
}
