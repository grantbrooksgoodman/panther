//
//  ConversationMetadata.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import CryptoKit
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/// The metadata that describes a conversation.
struct ConversationMetadata: Codable, Equatable {
    // MARK: - Properties

    /// The conversation's image data, or `nil` if it has none.
    let imageData: Data?

    /// The hash of the conversation's image data, or `nil` if it has no image.
    let imageHash: String?

    /// A Boolean value that indicates whether the conversation is a PenPals conversation.
    let isPenPalsConversation: Bool

    /// The date the conversation was last modified.
    let lastModifiedDate: Date

    // swiftlint:disable identifier_name
    /// The consent acknowledgement records for the conversation's participants.
    let messageRecipientConsentAcknowledgementData: [MessageRecipientConsentAcknowledgementData]
    // swiftlint:enable identifier_name

    /// The conversation's name.
    let name: String

    /// The PenPals sharing records for the conversation's participants.
    let penPalsSharingData: [PenPalsSharingData]

    /// The identifier of the participant whose message-receipt consent the conversation requires,
    /// or `nil` if it requires none.
    let requiresConsentFromInitiator: String?

    // MARK: - Computed Properties

    /// The conversation's image, or `nil` if it has none.
    var image: UIImage? {
        guard let imageData else { return nil }
        return .init(data: imageData)
    }

    // MARK: - Init

    /// Creates conversation metadata with the given properties.
    ///
    /// - Parameters:
    ///   - name: The conversation's name.
    ///   - imageData: The conversation's image data, or `nil` if it has none.
    ///   - imageHash: The hash of the conversation's image data, or `nil` to compute it from
    ///     `imageData`.
    ///   - isPenPalsConversation: A Boolean value that indicates whether the conversation is a
    ///     PenPals conversation.
    ///   - lastModifiedDate: The date the conversation was last modified.
    ///   - messageRecipientConsentAcknowledgementData: The consent acknowledgement records for the
    ///     conversation's participants.
    ///   - penPalsSharingData: The PenPals sharing records for the conversation's participants.
    ///   - requiresConsentFromInitiator: The identifier of the participant whose message-receipt
    ///     consent the conversation requires, or `nil` if it requires none.
    init(
        name: String,
        imageData: Data?,
        imageHash: String? = nil,
        isPenPalsConversation: Bool,
        lastModifiedDate: Date, // swiftlint:disable:next identifier_name
        messageRecipientConsentAcknowledgementData: [MessageRecipientConsentAcknowledgementData],
        penPalsSharingData: [PenPalsSharingData],
        requiresConsentFromInitiator: String?
    ) {
        self.name = name
        self.imageData = imageData
        self.imageHash = imageHash ?? imageData.map(Self.computeImageHash)
        self.isPenPalsConversation = isPenPalsConversation
        self.lastModifiedDate = lastModifiedDate
        self.penPalsSharingData = penPalsSharingData
        self.messageRecipientConsentAcknowledgementData = messageRecipientConsentAcknowledgementData
        self.requiresConsentFromInitiator = requiresConsentFromInitiator
    }

    // MARK: - Default Value

    /// Returns default metadata for a conversation with the given participants.
    ///
    /// - Parameters:
    ///   - userIDs: The identifiers of the conversation's participants.
    ///   - isPenPalsConversation: A Boolean value that indicates whether the conversation is a
    ///     PenPals conversation.
    ///
    /// - Returns: The default metadata.
    static func empty(
        userIDs: [String],
        isPenPalsConversation: Bool = false
    ) -> ConversationMetadata {
        @Dependency(\.clientSession.entity.user.currentUser) var currentUser: User?

        var requiresConsentFromInitiatorString: String?
        if let currentUser,
           currentUser.messageRecipientConsentRequired {
            requiresConsentFromInitiatorString = currentUser.id
        }

        return .init(
            name: .bangQualifiedEmpty,
            imageData: nil,
            isPenPalsConversation: isPenPalsConversation,
            lastModifiedDate: .init(timeIntervalSince1970: 0),
            messageRecipientConsentAcknowledgementData: MessageRecipientConsentAcknowledgementData.prepopulated(userIDs: userIDs),
            penPalsSharingData: isPenPalsConversation ? PenPalsSharingData.prepopulated(userIDs: userIDs) : PenPalsSharingData.empty(userIDs: userIDs),
            requiresConsentFromInitiator: requiresConsentFromInitiatorString
        )
    }

    // MARK: - Mutation

    /// Returns a copy of the metadata with the given properties replaced.
    ///
    /// Only the properties you provide are changed; the rest are copied unchanged. To clear the
    /// image data or the required-consent value rather than leave it unchanged, pass `nilImageData`
    /// or `nilRequiresConsentFromInitiator`.
    ///
    /// - Parameters:
    ///   - name: The new name, or `nil` to keep the current name.
    ///   - imageData: The new image data, or an empty value to keep the current image data.
    ///   - isPenPalsConversation: The new value, or `nil` to keep the current value.
    ///   - lastModifiedDate: The new last-modified date, or `nil` to keep the current date.
    ///   - messageRecipientConsentAcknowledgementData: The new consent acknowledgement records, or
    ///     `nil` to keep the current records.
    ///   - penPalsSharingData: The new PenPals sharing records, or `nil` to keep the current
    ///     records.
    ///   - requiresConsentFromInitiator: The new value, or an empty string to keep the current
    ///     value.
    ///   - nilImageData: A Boolean value that, when `true`, clears the image data.
    ///   - nilRequiresConsentFromInitiator: A Boolean value that, when `true`, clears the
    ///     required-consent value.
    ///
    /// - Returns: The updated metadata.
    func copyWith(
        name: String? = nil,
        imageData: Data = .init(),
        isPenPalsConversation: Bool? = nil,
        lastModifiedDate: Date? = nil, // swiftlint:disable:next identifier_name
        messageRecipientConsentAcknowledgementData: [MessageRecipientConsentAcknowledgementData]? = nil,
        penPalsSharingData: [PenPalsSharingData]? = nil,
        requiresConsentFromInitiator: String = "",
        nilImageData: Bool = false,
        nilRequiresConsentFromInitiator: Bool = false
    ) -> ConversationMetadata {
        if name == nil,
           imageData.isEmpty,
           isPenPalsConversation == nil,
           lastModifiedDate == nil,
           messageRecipientConsentAcknowledgementData == nil,
           penPalsSharingData == nil,
           requiresConsentFromInitiator.isEmpty,
           !nilImageData,
           !nilRequiresConsentFromInitiator {
            Logger.log(.init(
                "No arguments passed to mutator method.",
                metadata: .init(sender: self)
            ))

            return self
        }

        let imageData = nilImageData ? nil : (imageData.isEmpty ? self.imageData : imageData)
        let requiresConsentFromInitiator = nilRequiresConsentFromInitiator ? nil : (
            requiresConsentFromInitiator.isEmpty ? self.requiresConsentFromInitiator : requiresConsentFromInitiator
        )

        return .init(
            name: name ?? self.name,
            imageData: imageData,
            isPenPalsConversation: isPenPalsConversation ?? self.isPenPalsConversation,
            lastModifiedDate: lastModifiedDate ?? self.lastModifiedDate,
            messageRecipientConsentAcknowledgementData: messageRecipientConsentAcknowledgementData ?? self.messageRecipientConsentAcknowledgementData,
            penPalsSharingData: penPalsSharingData ?? self.penPalsSharingData,
            requiresConsentFromInitiator: requiresConsentFromInitiator
        )
    }

    // MARK: - Auxiliary

    /// Returns the hash of the given image data.
    ///
    /// - Parameter data: The image data to hash.
    ///
    /// - Returns: The hash of the image data.
    static func computeImageHash(_ data: Data) -> String {
        SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}
