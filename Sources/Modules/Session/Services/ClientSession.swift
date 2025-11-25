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

public final class ClientSession {
    // MARK: - Properties

    public let activity: ActivitySessionService
    public let conversation: ConversationSessionService
    public let message: MessageSessionService
    public let moderation: ModerationSessionService
    public let reaction: ReactionSessionService
    public let user: UserSessionService

    public private(set) var deliveryProgressIndicator: DeliveryProgressIndicator?

    // MARK: - Init

    public init(
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

    public func registerDeliveryProgressIndicator(_ deliveryProgressIndicator: DeliveryProgressIndicator) {
        self.deliveryProgressIndicator = deliveryProgressIndicator
    }
}
