//
//  StagedUsers.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A set of predefined users used to stage sample conversations during development.
struct StagedUsers {
    /// A predefined participant used to stage sample conversations.
    let erikaMustermann: User

    /// A predefined participant used to stage sample conversations.
    let jeanDupont: User

    /// A predefined participant used to stage sample conversations.
    let johnAppleseed: User

    /// A predefined participant used to stage sample conversations.
    let juanPerez: User

    /// The predefined user representing the current user in staged conversations.
    let mainUser: User

    /// The twin participant speaking the main user's language, or `nil` if a predefined
    /// participant already speaks it.
    let languageTwin: User?

    /// A predefined participant used to stage sample conversations.
    let marioRossi: User

    /// A predefined participant used to stage sample conversations.
    let peterIvanov: User

    /// A predefined participant used to stage sample conversations.
    let zhangShan: User
}
