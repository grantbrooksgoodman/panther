//
//  PenPalsSharingData+Serializable.swift
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

extension PenPalsSharingData: Serializable {
    // MARK: - Type Aliases

    public typealias T = PenPalsSharingData

    // MARK: - Properties

    public var encoded: String { "\(userID) | \(isSharingPenPalsData)" }

    // MARK: - Methods

    public static func canDecode(from data: String) -> Bool {
        let components = data.components(separatedBy: " | ")
        guard components.count == 2,
              components[1] == "true" || components[1] == "false" else { return false }
        return true
    }

    public static func decode(from data: String) async -> Callback<PenPalsSharingData, Exception> {
        let components = data.components(separatedBy: " | ")
        guard components.count == 2,
              components[1] == "true" || components[1] == "false" else {
            return .failure(.Networking.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        let userID = components[0]
        let isSharingPenPalsData = components[1] == "true" ? true : false

        let decoded: PenPalsSharingData = .init(
            userID: userID,
            isSharingPenPalsData: isSharingPenPalsData
        )

        return .success(decoded)
    }
}
