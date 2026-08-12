//
//  MessageRecipientConsentAcknowledgementData+Serializable.swift
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

extension MessageRecipientConsentAcknowledgementData: Serializable {
    // MARK: - Properties

    /// The serialized representation of the consent acknowledgement record.
    var encoded: String {
        "\(userID): \(consentAcknowledged ? "!" : false.description)"
    }

    // MARK: - Init

    /// Creates a consent acknowledgement record by decoding the given serialized string.
    ///
    /// - Parameter data: The serialized consent acknowledgement record string.
    ///
    /// - Throws: An `Exception` if the string cannot be decoded.
    init(
        from data: String
    ) async throws(Exception) {
        let components = data.components(separatedBy: ": ")
        guard components.count == 2 else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        self = .init(
            userID: components[0],
            consentAcknowledged: components[1] == false.description ? false : true
        )
    }

    // MARK: - Methods

    /// Returns a Boolean value that indicates whether a consent acknowledgement record can be
    /// decoded from the given string.
    ///
    /// - Parameter data: The serialized consent acknowledgement record string.
    ///
    /// - Returns: `true` if a consent acknowledgement record can be decoded; otherwise, `false`.
    static func canDecode(
        from data: String
    ) -> Bool {
        let components = data.components(separatedBy: ": ")
        guard components.count == 2,
              let booleanString = components.itemAt(1),
              booleanString == "false" ||
              booleanString == "true" ||
              booleanString.isBangQualifiedEmpty else { return false }
        return true
    }
}
