//
//  Reaction+Serializable.swift
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

extension Reaction: Serializable {
    // MARK: - Type Aliases

    public typealias T = Reaction
    private typealias Keys = SerializationKeys

    // MARK: - Types

    private enum SerializationKeys: String {
        case style
        case userID
    }

    // MARK: - Properties

    public var encoded: [String: Any] {
        [
            Keys.style.rawValue: style.encodedValue,
            Keys.userID.rawValue: userID,
        ]
    }

    // MARK: - Methods

    public static func canDecode(from data: [String: Any]) -> Bool {
        guard let encodedStyle = data[Keys.style.rawValue] as? String,
              Reaction.Style(encodedValue: encodedStyle) != nil,
              data[Keys.userID.rawValue] as? String != nil else { return false }

        return true
    }

    public static func decode(from data: [String: Any]) async -> Callback<Reaction, Exception> {
        guard let encodedStyle = data[Keys.style.rawValue] as? String,
              let style = Reaction.Style(encodedValue: encodedStyle),
              let userID = data[Keys.userID.rawValue] as? String else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        let decoded: Reaction = .init(style, userID: userID)
        return .success(decoded)
    }
}
