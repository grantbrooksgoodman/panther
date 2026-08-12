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

    /// The serializable keys for encoding and decoding a participant.
    enum SerializableKey: String {
        case hasDeletedConversation
        case isTyping
        case userID
    }

    // MARK: - Properties

    /// The serialized representation of the participant.
    var encoded: [String: Any] {
        [
            Keys.hasDeletedConversation.rawValue: hasDeletedConversation,
            Keys.isTyping.rawValue: isTyping,
            Keys.userID.rawValue: userID,
        ]
    }

    // MARK: - Init

    /// Creates a participant by decoding the given serialized data.
    ///
    /// - Parameter data: The serialized participant data.
    ///
    /// - Throws: An `Exception` if the data cannot be decoded.
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

    /// Returns a Boolean value that indicates whether a participant can be decoded from the given
    /// data.
    ///
    /// - Parameter data: The serialized participant data.
    ///
    /// - Returns: `true` if a participant can be decoded; otherwise, `false`.
    static func canDecode(
        from data: [String: Any]
    ) -> Bool {
        data[Keys.hasDeletedConversation.rawValue] is Bool &&
            data[Keys.isTyping.rawValue] is Bool &&
            data[Keys.userID.rawValue] is String
    }
}
