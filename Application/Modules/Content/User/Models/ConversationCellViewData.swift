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
import CoreArchitecture

public struct ConversationCellViewData: Equatable {
    // MARK: - Properties

    // String
    public let dateLabelText: String
    public let subtitleLabelText: String
    public let titleLabelText: String

    // Other
    public let isShowingUnreadIndicator: Bool
    public let otherUser: User?
    public let thumbnailImage: UIImage?

    // MARK: - Computed Properties

    public static var empty: ConversationCellViewData {
        .init(
            titleLabelText: "",
            subtitleLabelText: "",
            dateLabelText: "",
            isShowingUnreadIndicator: false,
            otherUser: nil,
            thumbnailImage: nil
        )
    }

    // MARK: - Init

    public init(
        titleLabelText: String,
        subtitleLabelText: String,
        dateLabelText: String,
        isShowingUnreadIndicator: Bool,
        otherUser: User?,
        thumbnailImage: UIImage?
    ) {
        self.titleLabelText = titleLabelText
        self.subtitleLabelText = subtitleLabelText
        self.dateLabelText = dateLabelText
        self.isShowingUnreadIndicator = isShowingUnreadIndicator
        self.otherUser = otherUser
        self.thumbnailImage = thumbnailImage
    }

    public init?(_ conversation: Conversation) {
        @Dependency(\.commonServices.contact.contactPairArchive) var contactPairArchive: ContactPairArchiveService

        guard let users = conversation.users,
              let lastUser = users.last else { return nil }

        var titleLabelText: String
        var subtitleLabelText = ""
        var dateLabelText = ""
        var thumbnailImage: UIImage?
        var isShowingUnreadIndicator = false
        var otherUser: User?

        // Set title label text
        if !conversation.metadata.name.isBangQualifiedEmpty {
            titleLabelText = conversation.metadata.name
        } else if let contactPair = users
            .compactMap({ contactPairArchive.getValue(phoneNumber: $0.phoneNumber) })
            .sorted(by: { $0.contact.fullName < $1.contact.fullName })
            .first {
            titleLabelText = contactPair.contact.fullName
            if let imageData = contactPair.contact.imageData,
               users.count == 1 {
                thumbnailImage = UIImage(data: imageData)
            }
        } else {
            titleLabelText = lastUser.phoneNumber.formattedString(useFailsafe: false)
        }

        if conversation.metadata.name.isBangQualifiedEmpty {
            if users.count > 1 {
                titleLabelText += " + \(users.count - 1)"
            } else if let firstUser = users.first {
                otherUser = firstUser
            }
        }

        if users.count > 1 {
            thumbnailImage = conversation.metadata.image ?? thumbnailImage
        }

        // Set date & subtitle label text
        if let lastMessage = conversation.messages?.last {
            dateLabelText = lastMessage.sentDate.formattedShortString

            if lastMessage.audioComponent != nil {
                subtitleLabelText = "🔊 \(Localized(.audioMessage).wrappedValue)"
            } else if lastMessage.image != nil {
                subtitleLabelText = "🏞️ \(Localized(.image).wrappedValue)"
            } else {
                let isLastMessageFromCurrentUser = lastMessage.isFromCurrentUser
                subtitleLabelText = isLastMessageFromCurrentUser ? lastMessage.translation.input.value().sanitized : lastMessage.translation.output
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
            isShowingUnreadIndicator: isShowingUnreadIndicator,
            otherUser: otherUser,
            thumbnailImage: thumbnailImage
        )
    }
}
