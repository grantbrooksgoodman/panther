//
//  Participant+Serializable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

extension Participant: Serializable {
    // MARK: - Properties

    var encoded: String { "\(userID) | \(hasDeletedConversation) | \(isTyping)" }

    // MARK: - Init

    init(
        from data: String // swiftformat:disable all
    ) async throws(Exception) { // swiftformat:enable all
        let components = data.components(separatedBy: " | ")
        guard components.count == 3,
              components[1] == "true" || components[1] == "false",
              components[2] == "true" || components[2] == "false" else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        let userID = components[0]
        let hasDeletedConversation = components[1] == "true" ? true : false
        let isTyping = components[2] == "true" ? true : false

        self = .init(
            userID: userID,
            hasDeletedConversation: hasDeletedConversation,
            isTyping: isTyping
        )
    }

    // MARK: - Methods

    static func canDecode(
        from data: String
    ) -> Bool {
        let components = data.components(separatedBy: " | ")
        guard components.count == 3,
              components[1] == "true" || components[1] == "false",
              components[2] == "true" || components[2] == "false" else { return false }
        return true
    }
}
