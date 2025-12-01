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

final class ClientSession {
    // MARK: - Properties

    let activity: ActivitySessionService
    let conversation: ConversationSessionService
    let message: MessageSessionService
    let moderation: ModerationSessionService
    let reaction: ReactionSessionService
    let user: UserSessionService

    private(set) var deliveryProgressIndicator: DeliveryProgressIndicator?

    // MARK: - Init

    init(
        activity: ActivitySessionService,
        conversation: ConversationSessionService,
        message: MessageSessionService,
        moderation: ModerationSessionService,
        reaction: ReactionSessionService,
        user: UserSessionService
    ) {
        self.activity = activity
        self.conversation = conversation
        self.message = message
        self.moderation = moderation
        self.reaction = reaction
        self.user = user
    }

    // MARK: - Register Delivery Progress Indicator

    func registerDeliveryProgressIndicator(_ deliveryProgressIndicator: DeliveryProgressIndicator) {
        self.deliveryProgressIndicator = deliveryProgressIndicator
    }
}
