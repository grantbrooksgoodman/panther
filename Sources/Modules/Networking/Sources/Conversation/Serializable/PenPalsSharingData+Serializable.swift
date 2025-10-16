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

    public var encoded: String {
        let sharesDataWithUserIDsString = sharesDataWithUserIDs?.reduce(into: String()) { partialResult, userID in
            if partialResult.isBlank { partialResult = userID } else { partialResult += ", \(userID)" }
        } ?? .bangQualifiedEmpty

        return "\(userID): \(sharesDataWithUserIDsString)"
    }

    // MARK: - Methods

    public static func canDecode(from data: String) -> Bool {
        let components = data.components(separatedBy: ": ")
        guard components.count == 2,
              components.allSatisfy({ !$0.isBlank }) else { return false }
        return true
    }

    public static func decode(from data: String) async -> Callback<PenPalsSharingData, Exception> {
        guard canDecode(from: data) else {
            return .failure(.Networking.decodingFailed(data: data, .init(sender: self)))
        }

        let components = data.components(separatedBy: ": ")
        let userID = components[0]
        let sharesDataWithUserIDs = components[1].components(separatedBy: ", ")

        let decoded: PenPalsSharingData = .init(
            userID: userID,
            sharesDataWithUserIDs: sharesDataWithUserIDs.isBangQualifiedEmpty ? nil : sharesDataWithUserIDs
        )

        return .success(decoded)
    }
}
