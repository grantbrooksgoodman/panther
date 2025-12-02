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

/* Proprietary */
import AppSubsystem

struct ConversationCellViewData: Equatable {
    // MARK: - Properties

    static let empty: ConversationCellViewData = .init(
        titleLabelText: "",
        subtitleLabelText: "",
        dateLabelText: "",
        isShowingUnreadIndicator: false,
        otherUser: nil,
        thumbnailImage: nil
    )

    let dateLabelText: String
    let isShowingUnreadIndicator: Bool
    let otherUser: User?
    let subtitleLabelText: String
    let thumbnailImage: UIImage?
    let titleLabelText: String

    // MARK: - Init

    init(
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

    init(user: User) {
        titleLabelText = ConversationCellViewData.empty.titleLabelText
        subtitleLabelText = ConversationCellViewData.empty.subtitleLabelText
        dateLabelText = ConversationCellViewData.empty.dateLabelText
        isShowingUnreadIndicator = ConversationCellViewData.empty.isShowingUnreadIndicator
        otherUser = user
        thumbnailImage = ConversationCellViewData.empty.thumbnailImage
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    init?(
        _ conversation: Conversation,
        searchQuery: String? = nil
    ) {
        let cacheQuery = (searchQuery == nil || searchQuery?.isBlank == true) ? String.bangQualifiedEmpty : searchQuery!
        if !conversation.isMock,
           let cachedValue = _ConversationCellViewDataCache
           .cachedDataByConversationIDForSearchQueries?[cacheQuery]?[conversation.id] {
            self = cachedValue
            return
        }

        let conversation = conversation.withMessagesSortedByAscendingSentDate
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
            .compactMap(\.contactPair)
            .sorted(by: { $0.contact.fullName < $1.contact.fullName })
            .first {
            titleLabelText = contactPair.contact.fullName
            if let image = contactPair.contact.image,
               users.count == 1 {
                thumbnailImage = image
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

        // Set thumbnail image

        if users.count > 1 {
            thumbnailImage = conversation.metadata.image ?? thumbnailImage
        }

        if conversation.metadata.isPenPalsConversation {
            let penPalsName = otherUser?.penPalsName ?? "PenPal\((conversation.users?.count ?? 0) > 1 ? "s" : "")"
            titleLabelText = conversation.metadata.penPalsSharingData.allShareWithCurrentUser ? titleLabelText : penPalsName
            thumbnailImage = SquareIconView.image(
                .penPalsIcon(
                    backgroundColor: otherUser?.penPalsIconColor.swiftUIColor ?? .purple
                )
            ) ?? thumbnailImage
        }

        // Set date & subtitle label text

        let messages = conversation
            .withMessagesOffsetFromCurrentUserAdditionDate
            .messages?
            .filteringSystemMessages

        var lastMessage = messages?.filteringSystemMessages.last
        if let searchQuery,
           !searchQuery.isBlank {
            lastMessage = messages?
                .filteringSystemMessages
                .last(where: { $0.textContains(searchQuery) }) ?? lastMessage
        }

        if let lastMessage {
            dateLabelText = lastMessage.sentDate.formattedShortString

            if lastMessage.audioComponent != nil {
                subtitleLabelText = "🔊 \(Localized(.audioMessage).wrappedValue)"
            } else if lastMessage.documentComponent != nil {
                subtitleLabelText = "📄 \(Localized(.document).wrappedValue)"
            } else if lastMessage.imageComponent != nil {
                subtitleLabelText = "🏞️ \(Localized(.image).wrappedValue)"
            } else if lastMessage.videoComponent != nil {
                subtitleLabelText = "🎥 \(Localized(.video).wrappedValue)"
            } else if lastMessage.richContent?.mediaComponent != nil {
                subtitleLabelText = "📎 \(Localized(.attachment).wrappedValue)"
            } else if let translation = lastMessage.translation {
                let consentAcknowledgementMessage = Localized(.messageRecipientConsentAcknowledgementMessage).wrappedValue
                let consentRequestMessage = Localized(.messageRecipientConsentRequestMessage).wrappedValue
                let isLastMessageFromCurrentUser = lastMessage.isFromCurrentUser

                let resolvedText = lastMessage.isConsentMessage ? (
                    lastMessage.isConsentAcknowledgementMessage ? consentAcknowledgementMessage : consentRequestMessage
                ).sanitized.trimmingBorderedWhitespace : (isLastMessageFromCurrentUser ? translation.input.value.sanitized : translation.output)

                subtitleLabelText = resolvedText
            }
        } else if let activity = conversation.activities?.last {
            dateLabelText = activity.date.formattedShortString
            subtitleLabelText = activity.description.sanitized
        } else {
            dateLabelText = Date(timeIntervalSince1970: 0).formattedShortString
            subtitleLabelText = Localized(.cannotDisplayMessage).wrappedValue
        }

        // Set unread indicator status

        if let lastMessageFromOtherUsers = messages?
            .filter({ !$0.isFromCurrentUser })
            .last {
            isShowingUnreadIndicator = lastMessageFromOtherUsers.currentUserReadReceipt == nil
        }

        self.init(
            titleLabelText: titleLabelText,
            subtitleLabelText: subtitleLabelText,
            dateLabelText: dateLabelText,
            isShowingUnreadIndicator: isShowingUnreadIndicator,
            otherUser: otherUser,
            thumbnailImage: thumbnailImage
        )

        // swiftlint:disable:next identifier_name
        var cachedDataByConversationIDForSearchQueries = _ConversationCellViewDataCache.cachedDataByConversationIDForSearchQueries ?? [:]

        if cachedDataByConversationIDForSearchQueries[cacheQuery] != nil {
            cachedDataByConversationIDForSearchQueries[cacheQuery]?[conversation.id] = self
        } else {
            cachedDataByConversationIDForSearchQueries[cacheQuery] = [conversation.id: self]
        }

        _ConversationCellViewDataCache.cachedDataByConversationIDForSearchQueries = cachedDataByConversationIDForSearchQueries
    }
}

enum ConversationCellViewDataCache {
    static func clearCache() {
        _ConversationCellViewDataCache.clearCache()
    }
}

private enum _ConversationCellViewDataCache {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case dataByConversationIDForSearchQueries
    }

    // MARK: - Properties

    // swiftlint:disable:next identifier_name line_length
    @Cached(CacheKey.dataByConversationIDForSearchQueries) fileprivate static var cachedDataByConversationIDForSearchQueries: [String: [ConversationID: ConversationCellViewData]]?

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedDataByConversationIDForSearchQueries = nil
    }
}
