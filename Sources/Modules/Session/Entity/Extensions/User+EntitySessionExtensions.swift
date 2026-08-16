//
//  User+EntitySessionExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension User {
    /// A category of session data associated with a user.
    enum DataType: CaseIterable {
        /// The user's conversations.
        case conversations

        /// The messages in the user's conversations.
        case messages

        /// The other participants in the user's conversations.
        case users
    }
}
