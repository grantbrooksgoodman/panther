//
//  MessageRecipientConsentAcknowledgementData.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable type_name

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// A record of whether a conversation participant has acknowledged the message-receipt consent
/// that the conversation requires.
struct MessageRecipientConsentAcknowledgementData: Codable, Equatable {
    // MARK: - Properties

    /// A Boolean value that indicates whether the participant has acknowledged the required
    /// consent.
    let consentAcknowledged: Bool

    /// The identifier of the participant's user.
    let userID: String

    // MARK: - Init

    /// Creates a consent acknowledgement record with the given properties.
    ///
    /// - Parameters:
    ///   - userID: The identifier of the participant's user.
    ///   - consentAcknowledged: A Boolean value that indicates whether the participant has
    ///     acknowledged the required consent.
    init(
        userID: String,
        consentAcknowledged: Bool
    ) {
        self.userID = userID
        self.consentAcknowledged = consentAcknowledged
    }

    // MARK: - Default Values

    /// Returns a consent acknowledgement record for each of the given users, each marked as
    /// acknowledged.
    ///
    /// - Parameter userIDs: The identifiers of the users to create records for.
    ///
    /// - Returns: The consent acknowledgement records.
    static func empty(userIDs: [String]) -> [MessageRecipientConsentAcknowledgementData] {
        userIDs.reduce(into: [MessageRecipientConsentAcknowledgementData]()) { partialResult, userID in
            partialResult.append(.init(userID: userID, consentAcknowledged: true))
        }
    }

    /// Returns a consent acknowledgement record for each of the given users, seeding each record's
    /// acknowledgement from the current user's consent requirement.
    ///
    /// Each record is marked as acknowledged unless the current user requires message-receipt
    /// consent, in which case each record is marked as not acknowledged.
    ///
    /// - Parameter userIDs: The identifiers of the users to create records for.
    ///
    /// - Returns: The consent acknowledgement records.
    static func prepopulated(userIDs: [String]) -> [MessageRecipientConsentAcknowledgementData] {
        @Dependency(\.clientSession.entity.user.currentUser?.messageRecipientConsentRequired) var messageRecipientConsentRequired: Bool?
        let initialConsentAcknowledgedValue = !(messageRecipientConsentRequired ?? false)
        return userIDs.reduce(into: [MessageRecipientConsentAcknowledgementData]()) { partialResult, userID in
            partialResult.append(.init(userID: userID, consentAcknowledged: initialConsentAcknowledgedValue))
        }
    }
}

// swiftlint:enable type_name
