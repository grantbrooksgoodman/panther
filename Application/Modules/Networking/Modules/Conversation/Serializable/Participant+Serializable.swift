//
//  Participant+Serializable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension Participant: Serializable {
    // MARK: - Type Aliases

    public typealias T = Participant

    // MARK: - Properties

    public var encoded: String { "\(userID) | \(hasDeletedConversation) | \(isTyping)" }

    // MARK: - Methods

    public static func decode(from data: String) async -> Callback<Participant, Exception> {
        let components = data.components(separatedBy: " | ")
        guard components.count == 3,
              components[1] == "true" || components[1] == "false",
              components[2] == "true" || components[2] == "false" else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        let userID = components[0]
        let hasDeletedConversation = components[1] == "true" ? true : false
        let isTyping = components[2] == "true" ? true : false

        let decoded: Participant = .init(
            userID: userID,
            hasDeletedConversation: hasDeletedConversation,
            isTyping: isTyping
        )

        return .success(decoded)
    }
}
