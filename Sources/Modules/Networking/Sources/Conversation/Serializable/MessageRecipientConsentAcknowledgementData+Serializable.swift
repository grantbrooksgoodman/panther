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

    var encoded: String { "\(userID): \(consentAcknowledged ? "!" : false.description)" }

    // MARK: - Init

    init(
        from data: String // swiftformat:disable all
    ) async throws(Exception) { // swiftformat:enable all
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
