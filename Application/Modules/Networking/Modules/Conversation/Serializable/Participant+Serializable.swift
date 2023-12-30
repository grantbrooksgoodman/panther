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
        guard let decoded: Participant = .init(data) else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        return .success(decoded)
    }
}
