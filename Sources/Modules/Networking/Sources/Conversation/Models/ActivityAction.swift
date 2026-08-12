//
//  ActivityAction.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension Activity {
    /// A kind of change to a conversation that an ``Activity`` records.
    enum Action: Codable, Equatable {
        // MARK: - Cases

        /// A user was added to the conversation, identified by the associated user identifier.
        case addedToConversation(userID: String)

        /// The conversation's group photo was changed.
        case changedGroupPhoto

        /// A user left the conversation.
        case leftConversation

        /// A user was removed from the conversation, identified by the associated user identifier.
        case removedFromConversation(userID: String)

        /// The conversation's group photo was removed.
        case removedGroupPhoto

        /// The conversation's name was removed.
        case removedName

        /// The conversation was renamed, carrying the associated new name.
        case renamedConversation(name: String)

        // MARK: - Properties

        /// The string representation of the action.
        var rawValue: String {
            switch self {
            case let .addedToConversation(userID: userID): "ADDED:\(userID)"
            case .changedGroupPhoto: "CHANGED_PHOTO"
            case .leftConversation: "LEFT"
            case let .removedFromConversation(userID: userID): "REMOVED:\(userID)"
            case .removedGroupPhoto: "REMOVED_PHOTO"
            case .removedName: "REMOVED_NAME"
            case let .renamedConversation(name: name): "RENAMED:\(name)"
            }
        }

        // MARK: - Init

        /// Creates an action from its string representation.
        ///
        /// Returns `nil` if the string does not represent a known action.
        ///
        /// - Parameter rawValue: The string representation of the action.
        init?(rawValue: String) {
            let components = rawValue.components(separatedBy: ":")

            guard components.count == 2,
                  let action = components.first,
                  let suffix = components.last else {
                switch rawValue {
                case "CHANGED_PHOTO": self = .changedGroupPhoto
                case "LEFT": self = .leftConversation
                case "REMOVED_NAME": self = .removedName
                case "REMOVED_PHOTO": self = .removedGroupPhoto
                default: return nil
                }
                return
            }

            if action == "ADDED" {
                self = .addedToConversation(userID: suffix)
                return
            } else if action == "REMOVED" {
                self = .removedFromConversation(userID: suffix)
                return
            } else if action == "RENAMED" {
                self = .renamedConversation(name: suffix)
                return
            }

            return nil
        }
    }
}
