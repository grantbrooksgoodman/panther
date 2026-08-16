//
//  EntitySession.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// The container for the session's entity services.
struct EntitySession {
    /// The service that adds and removes conversation participants, recording each change as an
    /// activity.
    let activity: ActivitySessionService

    /// The service that manages the current conversation and its displayed messages.
    let conversation: ConversationSessionService

    /// The service that sends text, audio, and media messages.
    let message: MessageSessionService

    /// The service that blocks, unblocks, and reports users.
    let moderation: ModerationSessionService

    /// The service that applies and removes message reactions.
    let reaction: ReactionSessionService

    /// The service that manages the current user and resolves their session data.
    let user: UserSessionService
}
