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
    // MARK: - Type Aliases

    private typealias Keys = SerializableKey

    // MARK: - Types

    enum SerializableKey: String {
        case hasDeletedConversation
        case isTyping
        case userID
    }

    // MARK: - Properties

    var encoded: [String: Any] {
        [
            Keys.hasDeletedConversation.rawValue: hasDeletedConversation,
            Keys.isTyping.rawValue: isTyping,
            Keys.userID.rawValue: userID,
        ]
    }

    // MARK: - Init

    init(
        from data: [String: Any]
    ) async throws(Exception) {
        guard let hasDeletedConversation = data[
            Keys.hasDeletedConversation.rawValue
        ] as? Bool,
            let isTyping = data[
                Keys.isTyping.rawValue
            ] as? Bool,
            let userID = data[
                Keys.userID.rawValue
            ] as? String else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        self = .init(
            userID: userID,
            hasDeletedConversation: hasDeletedConversation,
            isTyping: isTyping
        )
    }

    // MARK: - Methods

    static func canDecode(
        from data: [String: Any]
    ) -> Bool {
        data[Keys.hasDeletedConversation.rawValue] is Bool &&
            data[Keys.isTyping.rawValue] is Bool &&
            data[Keys.userID.rawValue] is String
    }
}
