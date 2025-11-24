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

public extension Activity {
    enum Action: Codable, Equatable {
        // MARK: - Cases

        case addedToConversation(userID: String)
        case leftConversation
        case removedFromConversation(userID: String)

        // MARK: - Properties

        public var rawValue: String {
            switch self {
            case let .addedToConversation(userID: userID): "ADDED:\(userID)"
            case .leftConversation: "LEFT"
            case let .removedFromConversation(userID: userID): "REMOVED:\(userID)"
            }
        }

        // MARK: - Init

        public init?(rawValue: String) {
            guard rawValue != "LEFT" else {
                self = .leftConversation
                return
            }

            let components = rawValue.components(separatedBy: ":")
            guard let action = components.first,
                  let userID = components.last else { return nil }

            if action == "ADDED" {
                self = .addedToConversation(userID: userID)
                return
            } else if action == "REMOVED" {
                self = .removedFromConversation(userID: userID)
                return
            }

            return nil
        }
    }
}
