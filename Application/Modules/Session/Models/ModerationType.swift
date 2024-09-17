//
//  ModerationType.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum ModerationType: String {
    // MARK: - Cases

    case block
    case report
    case unblock

    // MARK: - Properties

    public var allUsersConfirmationMessage: String {
        switch self { // swiftlint:disable:next line_length
        case .block: "Are you sure you'd like to block all users in this conversation?\n\nYou will no longer receive messages from any chat in which you and any of these users are participants. This can be changed later in Settings.\n\nThe other users will not know you have blocked them."
        case .report: "Are you sure you'd like to report all users in this conversation for improper conduct?"
        case .unblock: ""
        }
    }

    public var singleUserConfirmationMessage: String {
        switch self { // swiftlint:disable:next line_length
        case .block: "Are you sure you'd like to block this user?\n\nYou will no longer receive messages from any chat in which you and this user are participants. This can be changed later in Settings.\n\nThe other user will not know you have blocked them."
        case .report: "Are you sure you'd like to report this user for improper conduct?"
        case .unblock: ""
        }
    }
}
