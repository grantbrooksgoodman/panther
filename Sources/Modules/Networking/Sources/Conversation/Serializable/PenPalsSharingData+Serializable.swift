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

    /// The serialized representation of the sharing record.
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

    /// Creates a sharing record by decoding the given serialized string.
    ///
    /// - Parameter data: The serialized sharing record string.
    ///
    /// - Throws: An `Exception` if the string cannot be decoded.
    init(
        from data: String
    ) async throws(Exception) {
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

    /// Returns a Boolean value that indicates whether a sharing record can be decoded from the
    /// given string.
    ///
    /// - Parameter data: The serialized sharing record string.
    ///
    /// - Returns: `true` if a sharing record can be decoded; otherwise, `false`.
    static func canDecode(
        from data: String
    ) -> Bool {
        let components = data.components(separatedBy: ": ")
        guard components.count == 2,
              components.allSatisfy({ !$0.isBlank }) else { return false }
        return true
    }
}
