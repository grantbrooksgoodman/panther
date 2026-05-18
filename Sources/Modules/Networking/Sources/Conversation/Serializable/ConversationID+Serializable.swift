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
    // MARK: - Properties

    var encoded: String {
        "\(key) | \(hash)"
    }

    // MARK: - Init

    init(
        from data: String
    ) async throws(Exception) {
        let components = data.components(separatedBy: " | ")
        guard components.count == 2 else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        self = .init(
            key: components[0],
            hash: components[1]
        )
    }

    // MARK: - Methods

    static func canDecode(
        from data: String
    ) -> Bool {
        data.components(separatedBy: " | ").count == 2
    }
}
