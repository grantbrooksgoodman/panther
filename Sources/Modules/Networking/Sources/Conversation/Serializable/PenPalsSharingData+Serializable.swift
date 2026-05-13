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
    // MARK: - Properties

    var encoded: String {
        let sharesDataWithUserIDsString = sharesDataWithUserIDs?.reduce(into: String()) { partialResult, userID in
            if partialResult.isBlank {
                partialResult = userID
            } else {
                partialResult += ", \(userID)"
            }
        } ?? .bangQualifiedEmpty

        return "\(userID): \(sharesDataWithUserIDsString)"
    }

    // MARK: - Init

    init(
        from data: String // swiftformat:disable all
    ) async throws(Exception) { // swiftformat:enable all
        guard Self.canDecode(from: data) else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        let components = data.components(separatedBy: ": ")
        let userID = components[0]
        let sharesDataWithUserIDs = components[1].components(separatedBy: ", ")

        self = .init(
            userID: userID,
            sharesDataWithUserIDs: sharesDataWithUserIDs.isBangQualifiedEmpty ? nil : sharesDataWithUserIDs
        )
    }

    // MARK: - Methods

    static func canDecode(
        from data: String
    ) -> Bool {
        let components = data.components(separatedBy: ": ")
        guard components.count == 2,
              components.allSatisfy({ !$0.isBlank }) else { return false }
        return true
    }
}
