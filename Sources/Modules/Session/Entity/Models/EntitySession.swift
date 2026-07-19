//
//  EntitySession.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct EntitySession {
    let activity: ActivitySessionService
    let conversation: ConversationSessionService
    let message: MessageSessionService
    let moderation: ModerationSessionService
    let reaction: ReactionSessionService
    let user: UserSessionService
}
