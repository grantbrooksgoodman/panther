//
//  MessageRecipientConsentAcknowledgementData.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

// swiftlint:disable:next type_name
struct MessageRecipientConsentAcknowledgementData: Codable, Equatable {
    // MARK: - Properties

    let consentAcknowledged: Bool
    let userID: String

    // MARK: - Init

    init(userID: String, consentAcknowledged: Bool) {
        self.userID = userID
        self.consentAcknowledged = consentAcknowledged
    }

    // MARK: - Default Values

    static func empty(userIDs: [String]) -> [MessageRecipientConsentAcknowledgementData] {
        userIDs.reduce(into: [MessageRecipientConsentAcknowledgementData]()) { partialResult, userID in
            partialResult.append(.init(userID: userID, consentAcknowledged: true))
        }
    }

    static func prepopulated(userIDs: [String]) -> [MessageRecipientConsentAcknowledgementData] {
        @Dependency(\.clientSession.user.currentUser?.messageRecipientConsentRequired) var messageRecipientConsentRequired: Bool?
        let initialConsentAcknowledgedValue = !(messageRecipientConsentRequired ?? false)
        return userIDs.reduce(into: [MessageRecipientConsentAcknowledgementData]()) { partialResult, userID in
            partialResult.append(.init(userID: userID, consentAcknowledged: initialConsentAcknowledgedValue))
        }
    }
}
