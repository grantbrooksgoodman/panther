//
//  ModerationType.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A kind of user moderation action.
enum ModerationType: String {
    // MARK: - Cases

    /// The action that blocks a user.
    case block

    /// The action that reports a user.
    case report

    /// The action that unblocks a user.
    case unblock

    // MARK: - Properties

    /// The confirmation message shown before applying the action to all users in a conversation.
    var allUsersConfirmationMessage: String {
        switch self { // swiftlint:disable:next line_length
        case .block: "Are you sure you'd like to block all users in this conversation?\n\nYou will no longer receive messages from any chat in which you and any of these users are participants. This can be changed later in Settings.\n\nThe other users will not know you have blocked them."
        case .report: "Are you sure you'd like to report all users in this conversation for improper conduct?"
        case .unblock: ""
        }
    }

    /// The confirmation message shown before applying the action to a single user.
    var singleUserConfirmationMessage: String {
        switch self { // swiftlint:disable:next line_length
        case .block: "Are you sure you'd like to block this user?\n\nYou will no longer receive messages from any chat in which you and this user are participants. This can be changed later in Settings.\n\nThe other user will not know you have blocked them."
        case .report: "Are you sure you'd like to report this user for improper conduct?"
        case .unblock: ""
        }
    }
}
