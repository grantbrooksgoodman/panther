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
import Redux

public struct ClientSession {
    // MARK: - Properties

    public let conversation: ConversationSessionService
    public let message: MessageSessionService
    public let user: UserSessionService

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
}
