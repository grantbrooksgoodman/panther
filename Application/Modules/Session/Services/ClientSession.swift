//
//  ClientSession.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public final class ClientSession {
    // MARK: - Properties

    public let conversation: ConversationSessionService
    public let message: MessageSessionService
    public let user: UserSessionService

    public private(set) var deliveryProgressIndicator: DeliveryProgressIndicator?

    // MARK: - Init

    public init(
        conversation: ConversationSessionService,
        message: MessageSessionService,
        user: UserSessionService
    ) {
        self.conversation = conversation
        self.message = message
        self.user = user
    }

    // MARK: - Register Delivery Progress Indicator

    public func registerDeliveryProgressIndicator(_ deliveryProgressIndicator: DeliveryProgressIndicator) {
        self.deliveryProgressIndicator = deliveryProgressIndicator
    }
}
