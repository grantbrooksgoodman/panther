//
//  ConversationCellViewData.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import Redux

public struct ConversationCellViewData: Equatable {
    // MARK: - Properties

    // String
    public let dateLabelText: String
    public let subtitleLabelText: String
    public let titleLabelText: String

    // Other
    public let contactImage: UIImage?
    public let isShowingUnreadIndicator: Bool
    public let otherUser: User?

    // MARK: - Computed Properties

    public static var empty: ConversationCellViewData {
        .init(
            titleLabelText: "",
            subtitleLabelText: "",
            dateLabelText: "",
            contactImage: nil,
            isShowingUnreadIndicator: false,
            otherUser: nil
        )
    }

    // MARK: - Init

    public init(
        titleLabelText: String,
        subtitleLabelText: String,
        dateLabelText: String,
        contactImage: UIImage?,
        isShowingUnreadIndicator: Bool,
        otherUser: User?
    ) {
        self.titleLabelText = titleLabelText
        self.subtitleLabelText = subtitleLabelText
        self.dateLabelText = dateLabelText
        self.contactImage = contactImage
        self.isShowingUnreadIndicator = isShowingUnreadIndicator
        self.otherUser = otherUser
    }

    public init?(_ conversation: Conversation) {
        @Dependency(\.commonServices.contact.contactPairArchive) var contactPairArchive: ContactPairArchiveService

        guard let users = conversation.users,
              let lastUser = users.last else { return nil }

        var titleLabelText: String
        var subtitleLabelText = ""
        var dateLabelText = ""
        var contactImage: UIImage?
        var isShowingUnreadIndicator = false
        var otherUser: User?

        // Set title label text
        if !conversation.metadata.name.isBangQualifiedEmpty {
            titleLabelText = conversation.metadata.name
        } else if let contactPair = users
            .compactMap({ contactPairArchive.getValue(userNumberHash: $0.phoneNumber.nationalNumberString.digits.encodedHash) })
            .sorted(by: { $0.contact.fullName < $1.contact.fullName })
            .first {
            titleLabelText = contactPair.contact.fullName
            if let imageData = contactPair.contact.imageData {
                contactImage = UIImage(data: imageData)
            }
        } else {
            titleLabelText = lastUser.phoneNumber.formattedString(useFailsafe: false)
        }

        // TODO: If >1 other user, set avatar image to number of users.
        if conversation.metadata.name.isBangQualifiedEmpty {
            if users.count > 1 {
                titleLabelText += " + \(users.count - 1)"
            } else if let firstUser = users.first {
                otherUser = firstUser
            }
        }

        // Set date & subtitle label text
        if let lastMessage = conversation.messages?.last {
            dateLabelText = lastMessage.sentDate.formattedShortString

            if lastMessage.audioComponent == nil {
                let isLastMessageFromCurrentUser = lastMessage.isFromCurrentUser
                subtitleLabelText = isLastMessageFromCurrentUser ? lastMessage.translation.input.value() : lastMessage.translation.output
            } else {
                subtitleLabelText = "🔊 \(Localized(.audioMessage).wrappedValue)"
            }
        }

        // Set unread indicator status
        if let lastMessageFromOtherUsers = conversation.messages?.filter({ !$0.isFromCurrentUser }).last {
            isShowingUnreadIndicator = lastMessageFromOtherUsers.readDate == nil
        }

        self.init(
            titleLabelText: titleLabelText,
            subtitleLabelText: subtitleLabelText,
            dateLabelText: dateLabelText,
            contactImage: contactImage,
            isShowingUnreadIndicator: isShowingUnreadIndicator,
            otherUser: otherUser
        )
    }
}
