//
//  UserID+Serializable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension UserID: Serializable {
    // MARK: - Type Aliases

    public typealias T = UserID

    // MARK: - Properties

    public var encoded: String { "\(key) | \(hash)" }

    // MARK: - Methods

    public static func decode(from data: String) async -> Callback<UserID, Exception> {
        let components = data.components(separatedBy: " | ")
        guard components.count == 2 else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        let decoded: UserID = .init(key: components[0], hash: components[1])
        return .success(decoded)
    }
}
