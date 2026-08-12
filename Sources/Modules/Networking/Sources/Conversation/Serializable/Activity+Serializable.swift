//
//  Activity+Serializable.swift
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

extension Activity: Serializable {
    // MARK: - Type Aliases

    private typealias Keys = SerializableKey

    // MARK: - Types

    /// The serializable keys for encoding and decoding an activity.
    enum SerializableKey: String {
        case action
        case date
        case userID
    }

    // MARK: - Properties

    /// The serialized representation of the activity.
    var encoded: [String: Any] {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        return [
            Keys.action.rawValue: action.rawValue,
            Keys.date.rawValue: dateFormatter.string(from: date),
            Keys.userID.rawValue: userID,
        ]
    }

    // MARK: - Init

    /// Creates an activity by decoding the given serialized data.
    ///
    /// - Parameter data: The serialized activity data.
    ///
    /// - Throws: An `Exception` if the data cannot be decoded.
    init(
        from data: [String: Any]
    ) async throws(Exception) {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        guard let actionString = data[Keys.action.rawValue] as? String,
              let action: Action = .init(rawValue: actionString),
              let dateString = data[Keys.date.rawValue] as? String,
              let date = dateFormatter.date(from: dateString),
              let userID = data[Keys.userID.rawValue] as? String else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        self = .init(
            action,
            date: date,
            userID: userID
        )
    }

    // MARK: - Methods

    /// Returns a Boolean value that indicates whether an activity can be decoded from the given
    /// data.
    ///
    /// - Parameter data: The serialized activity data.
    ///
    /// - Returns: `true` if an activity can be decoded; otherwise, `false`.
    static func canDecode(
        from data: [String: Any]
    ) -> Bool {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        guard let actionString = data[Keys.action.rawValue] as? String,
              Action(rawValue: actionString) != nil,
              let dateString = data[Keys.date.rawValue] as? String,
              dateFormatter.date(from: dateString) != nil,
              let userID = data[Keys.userID.rawValue] as? String,
              !userID.isBlank else { return false }

        return true
    }
}
