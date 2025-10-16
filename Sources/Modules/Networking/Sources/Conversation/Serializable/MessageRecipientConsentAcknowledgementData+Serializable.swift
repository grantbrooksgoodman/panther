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
    // MARK: - Type Aliases

    public typealias T = MessageRecipientConsentAcknowledgementData

    // MARK: - Properties

    public var encoded: String { "\(userID): \(consentAcknowledged ? "!" : false.description)" }

    // MARK: - Methods

    public static func canDecode(from data: String) -> Bool {
        data.components(separatedBy: ": ").count == 2
    }

    public static func decode(from data: String) async -> Callback<MessageRecipientConsentAcknowledgementData, Exception> {
        let components = data.components(separatedBy: ": ")
        guard components.count == 2 else {
            return .failure(.Networking.decodingFailed(data: data, .init(sender: self)))
        }

        let decoded: MessageRecipientConsentAcknowledgementData = .init(
            userID: components[0],
            consentAcknowledged: components[1] == false.description ? false : true
        )

        return .success(decoded)
    }
}
