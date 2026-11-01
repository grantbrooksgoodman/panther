//
//  Conversation+PenPalsSharingExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/10/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

extension Conversation {
    // MARK: - Type Aliases

    private typealias MetadataKey = ConversationMetadata.SerializableKey

    // MARK: - Properties

    /// The PenPals sharing records in effect for the conversation,
    /// or `nil` when the conversation is not a PenPals conversation.
    var activePenPalsSharingData: [PenPalsSharingData]? {
        guard metadata.isPenPalsConversation else { return nil }
        return metadata.penPalsSharingData
    }

    // MARK: - Methods

    /// Atomically adds the given user's consent acknowledgement and
    /// PenPals sharing records to the conversation's metadata.
    ///
    /// The update runs inside a database transaction against the
    /// metadata node, so concurrent sharing updates from other
    /// participants are never overwritten. The added user's sharing
    /// record shares with no one, and their consent record is
    /// acknowledged unless the conversation requires consent from an
    /// initiator. Pass `true` for `sharingCurrentUserData` to also
    /// share the current user's data with the added user.
    ///
    /// - Parameters:
    ///   - userID: The identifier of the user to add.
    ///   - sharingCurrentUserData: A Boolean value that indicates
    ///     whether the current user shares their PenPals data with
    ///     the added user.
    ///
    /// - Returns: The updated conversation.
    ///
    /// - Throws: An `Exception` if the current user ID has not been
    ///   set, or if the write fails.
    func addParticipantMetadata(
        forUserID userID: String,
        sharingCurrentUserData: Bool
    ) async throws(Exception) -> Conversation {
        guard let currentUserID = User.currentUserID else {
            throw Exception(
                "Current user ID has not been set.",
                metadata: .init(sender: self)
            )
        }

        return try await update(
            \.metadata,
            applyingRaw: { currentValue in
                guard var metadata = currentValue as? [String: Any],
                      let encodedConsentData = metadata[
                          MetadataKey.messageRecipientConsentAcknowledgementData.rawValue
                      ] as? [String],
                      let encodedSharingData = metadata[
                          MetadataKey.penPalsSharingData.rawValue
                      ] as? [String] else { return currentValue }

                let requiresConsent = (
                    metadata[MetadataKey.requiresConsentFromInitiator.rawValue] as? String
                ).map { !$0.isBangQualifiedEmpty } ?? false

                var sharesByUserID = Self.parseSharingData(encodedSharingData)
                sharesByUserID[userID] = []

                if sharingCurrentUserData,
                   sharesByUserID[currentUserID] != nil {
                    sharesByUserID[currentUserID]?.insert(userID)
                }

                metadata[MetadataKey.messageRecipientConsentAcknowledgementData.rawValue] = (
                    encodedConsentData.filter { !$0.hasPrefix("\(userID): ") } + [
                        MessageRecipientConsentAcknowledgementData(
                            userID: userID,
                            consentAcknowledged: !requiresConsent
                        ).encoded,
                    ]
                ).sorted()

                metadata[MetadataKey.penPalsSharingData.rawValue] = Self.encodeSharingData(sharesByUserID)
                return metadata
            }
        )
    }

    /// Atomically removes the given user's consent acknowledgement
    /// and PenPals sharing records from the conversation's metadata,
    /// and strips their identifier from the remaining sharing
    /// records.
    ///
    /// The update runs inside a database transaction against the
    /// metadata node, so concurrent sharing updates from other
    /// participants are never overwritten. When two participants
    /// remain, the conversation's name and image are cleared; if the
    /// removed user is the initiator whose message-receipt consent
    /// the conversation requires, that requirement is cleared. When
    /// the removal results in every remaining participant sharing
    /// with every other, the conversation is converted to a standard
    /// conversation in the same transaction.
    ///
    /// - Parameter userID: The identifier of the user to remove.
    ///
    /// - Returns: The updated conversation.
    ///
    /// - Throws: An `Exception` if the write fails.
    func removeParticipantMetadata(
        forUserID userID: String
    ) async throws(Exception) -> Conversation {
        let remainingUserIDs = participants.map(\.userID).filter { $0 != userID }
        return try await update(
            \.metadata,
            applyingRaw: { currentValue in
                guard var metadata = currentValue as? [String: Any],
                      let encodedConsentData = metadata[
                          MetadataKey.messageRecipientConsentAcknowledgementData.rawValue
                      ] as? [String],
                      let encodedSharingData = metadata[
                          MetadataKey.penPalsSharingData.rawValue
                      ] as? [String] else { return currentValue }

                var sharesByUserID = Self.parseSharingData(encodedSharingData)
                sharesByUserID[userID] = nil

                for sharingUserID in sharesByUserID.keys {
                    sharesByUserID[sharingUserID]?.remove(userID)
                }

                if metadata[MetadataKey.isPenPalsConversation.rawValue] as? Bool == true {
                    sharesByUserID = Self.convertingToStandardConversationIfNeeded(
                        &metadata,
                        sharesByUserID: sharesByUserID,
                        participantUserIDs: remainingUserIDs
                    )
                }

                metadata[MetadataKey.messageRecipientConsentAcknowledgementData.rawValue] = encodedConsentData
                    .filter { !$0.hasPrefix("\(userID): ") }
                metadata[MetadataKey.penPalsSharingData.rawValue] = Self.encodeSharingData(sharesByUserID)

                if remainingUserIDs.count == 2 {
                    metadata[MetadataKey.imageData.rawValue] = String.bangQualifiedEmpty
                    metadata[MetadataKey.name.rawValue] = String.bangQualifiedEmpty
                    metadata.removeValue(forKey: MetadataKey.imageHash.rawValue)
                }

                if metadata[MetadataKey.requiresConsentFromInitiator.rawValue] as? String == userID {
                    metadata[MetadataKey.requiresConsentFromInitiator.rawValue] = String.bangQualifiedEmpty
                }

                return metadata
            }
        )
    }

    /// Returns the given raw conversation metadata with the given
    /// user IDs merged into the current user's PenPals sharing
    /// record.
    ///
    /// Consent acknowledgement and sharing records for users who are
    /// no longer participants are pruned, and each sharing record is
    /// limited to the other participants. User IDs outside the
    /// participant set are ignored; if none remain, or the current
    /// user has no sharing record, the metadata is returned
    /// unchanged. When the merge results in every participant
    /// sharing with every other, the conversation is converted to a
    /// standard conversation.
    ///
    /// Use this method as the transform of a metadata transaction;
    /// it has no side effects.
    ///
    /// - Parameters:
    ///   - currentValue: The raw metadata currently stored on the
    ///     server.
    ///   - currentUserID: The identifier of the current user.
    ///   - participantUserIDs: The identifiers of the conversation's
    ///     participants.
    ///   - userIDs: The identifiers of the users to share the current
    ///     user's data with.
    ///
    /// - Returns: The raw metadata to commit.
    static func mergingPenPalsSharingData(
        into currentValue: Any?,
        currentUserID: String,
        participantUserIDs: [String],
        userIDs: [String]
    ) -> Any? {
        guard var metadata = currentValue as? [String: Any],
              let encodedConsentData = metadata[
                  MetadataKey.messageRecipientConsentAcknowledgementData.rawValue
              ] as? [String],
              let encodedSharingData = metadata[
                  MetadataKey.penPalsSharingData.rawValue
              ] as? [String] else { return currentValue }

        let participantUserIDSet = Set(participantUserIDs)

        var sharesByUserID = [String: Set<String>]()
        for (userID, sharedUserIDs) in parseSharingData(encodedSharingData) where participantUserIDSet.contains(userID) {
            sharesByUserID[userID] = sharedUserIDs
                .intersection(participantUserIDSet)
                .subtracting([userID])
        }

        let userIDsToShare = Set(userIDs)
            .intersection(participantUserIDSet)
            .subtracting([currentUserID])

        guard !userIDsToShare.isEmpty,
              var currentUserSharedUserIDs = sharesByUserID[currentUserID] else { return currentValue }

        currentUserSharedUserIDs.formUnion(userIDsToShare)
        sharesByUserID[currentUserID] = currentUserSharedUserIDs

        sharesByUserID = convertingToStandardConversationIfNeeded(
            &metadata,
            sharesByUserID: sharesByUserID,
            participantUserIDs: participantUserIDs
        )

        metadata[MetadataKey.messageRecipientConsentAcknowledgementData.rawValue] = encodedConsentData
            .filter { entry in
                participantUserIDSet.contains { entry.hasPrefix("\($0): ") }
            }

        metadata[MetadataKey.penPalsSharingData.rawValue] = encodeSharingData(sharesByUserID)
        return metadata
    }
}

private extension Conversation {
    private static func convertingToStandardConversationIfNeeded(
        _ metadata: inout [String: Any],
        sharesByUserID: [String: Set<String>],
        participantUserIDs: [String]
    ) -> [String: Set<String>] {
        let participantUserIDSet = Set(participantUserIDs)
        guard participantUserIDSet.allSatisfy({
            sharesByUserID[$0] == participantUserIDSet.subtracting([$0])
        }) else { return sharesByUserID }

        metadata[MetadataKey.isPenPalsConversation.rawValue] = false
        return participantUserIDSet.reduce(
            into: [String: Set<String>]()
        ) { $0[$1] = [] }
    }

    private static func encodeSharingData(
        _ sharesByUserID: [String: Set<String>]
    ) -> [String] {
        sharesByUserID
            .map { userID, sharedUserIDs in
                PenPalsSharingData(
                    userID: userID,
                    sharesDataWithUserIDs: sharedUserIDs.isEmpty ? nil : sharedUserIDs.sorted()
                ).encoded
            }
            .sorted()
    }

    private static func parseSharingData(
        _ encodedSharingData: [String]
    ) -> [String: Set<String>] {
        var sharesByUserID = [String: Set<String>]()

        for entry in encodedSharingData {
            let components = entry.components(separatedBy: ": ")
            guard components.count == 2 else { continue }
            sharesByUserID[components[0]] = Set(
                components[1]
                    .components(separatedBy: ", ")
                    .filter { !$0.isBlank && !$0.isBangQualifiedEmpty }
            )
        }

        return sharesByUserID
    }
}
