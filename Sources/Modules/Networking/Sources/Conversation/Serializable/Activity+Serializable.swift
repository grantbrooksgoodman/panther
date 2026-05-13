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

    enum SerializableKey: String {
        case action
        case date
        case userID
    }

    // MARK: - Properties

    var encoded: [String: Any] {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        return [
            Keys.action.rawValue: action.rawValue,
            Keys.date.rawValue: dateFormatter.string(from: date),
            Keys.userID.rawValue: userID,
        ]
    }

    // MARK: - Init

    init(
        from data: [String: Any] // swiftformat:disable all
    ) async throws(Exception) { // swiftformat:enable all
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
