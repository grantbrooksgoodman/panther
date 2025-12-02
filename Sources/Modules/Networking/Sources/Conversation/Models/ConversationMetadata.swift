//
//  ConversationMetadata.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

struct ConversationMetadata: Codable, Equatable {
    // MARK: - Properties

    let imageData: Data?
    let isPenPalsConversation: Bool
    let lastModifiedDate: Date // swiftlint:disable:next identifier_name
    let messageRecipientConsentAcknowledgementData: [MessageRecipientConsentAcknowledgementData]
    let name: String
    let penPalsSharingData: [PenPalsSharingData]
    let requiresConsentFromInitiator: String?

    // MARK: - Computed Properties

    var image: UIImage? {
        guard let imageData else { return nil }
        return .init(data: imageData)
    }

    // MARK: - Init

    init(
        name: String,
        imageData: Data?,
        isPenPalsConversation: Bool,
        lastModifiedDate: Date, // swiftlint:disable:next identifier_name
        messageRecipientConsentAcknowledgementData: [MessageRecipientConsentAcknowledgementData],
        penPalsSharingData: [PenPalsSharingData],
        requiresConsentFromInitiator: String?
    ) {
        self.name = name
        self.imageData = imageData
        self.isPenPalsConversation = isPenPalsConversation
        self.lastModifiedDate = lastModifiedDate
        self.penPalsSharingData = penPalsSharingData
        self.messageRecipientConsentAcknowledgementData = messageRecipientConsentAcknowledgementData
        self.requiresConsentFromInitiator = requiresConsentFromInitiator
    }

    // MARK: - Default Value

    static func empty(
        userIDs: [String],
        isPenPalsConversation: Bool = false
    ) -> ConversationMetadata {
        @Dependency(\.clientSession.user.currentUser) var currentUser: User?

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
}
