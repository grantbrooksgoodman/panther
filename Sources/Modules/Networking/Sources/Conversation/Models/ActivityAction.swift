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
    enum Action: Codable, Equatable {
        // MARK: - Cases

        case addedToConversation(userID: String)
        case changedGroupPhoto
        case leftConversation
        case removedFromConversation(userID: String)
        case removedGroupPhoto
        case removedName
        case renamedConversation(name: String)

        // MARK: - Properties

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
