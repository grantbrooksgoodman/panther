//
//  ConversationID+Serializable.swift
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

extension ConversationID: Serializable {
    // MARK: - Type Aliases

    typealias T = ConversationID

    // MARK: - Properties

    var encoded: String { "\(key) | \(hash)" }

    // MARK: - Methods

    static func canDecode(from data: String) -> Bool {
        data.components(separatedBy: " | ").count == 2
    }

    static func decode(from data: String) async -> Callback<ConversationID, Exception> {
        let components = data.components(separatedBy: " | ")
        guard components.count == 2 else {
            return .failure(.Networking.decodingFailed(data: data, .init(sender: self)))
        }

        let decoded: ConversationID = .init(key: components[0], hash: components[1])
        return .success(decoded)
    }
}
