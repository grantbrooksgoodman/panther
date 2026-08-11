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
    let isAwaitingMessageHydration: Bool
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
        thumbnailImage: UIImage?,
        isAwaitingMessageHydration: Bool = false
    ) {
        self.titleLabelText = titleLabelText
        self.subtitleLabelText = subtitleLabelText
        self.dateLabelText = dateLabelText
        self.isShowingUnreadIndicator = isShowingUnreadIndicator
        self.otherUser = otherUser
        self.thumbnailImage = thumbnailImage
        self.isAwaitingMessageHydration = isAwaitingMessageHydration
    }

    init(user: User) {
        titleLabelText = ConversationCellViewData.empty.titleLabelText
        subtitleLabelText = ConversationCellViewData.empty.subtitleLabelText
        dateLabelText = ConversationCellViewData.empty.dateLabelText
        isShowingUnreadIndicator = ConversationCellViewData.empty.isShowingUnreadIndicator
        otherUser = user
        thumbnailImage = ConversationCellViewData.empty.thumbnailImage
        isAwaitingMessageHydration = ConversationCellViewData.empty.isAwaitingMessageHydration
    }

    @MainActor // swiftlint:disable:next cyclomatic_complexity function_body_length
    init?(
        _ conversation: Conversation,
        searchQuery: String? = nil,
        useCachedValue: Bool = true
    ) {
        @Dependency(\.currentCalendar) var calendar: Calendar
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        @Dependency(\.stagingModeDateFormatter) var stagingModeDateFormatter: DateFormatter

        let cacheQuery = (searchQuery == nil || searchQuery?.isBlank == true) ? String.bangQualifiedEmpty : searchQuery!
        if useCachedValue,
           !conversation.isMock,
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

        // Distinguishes "no messages exist" from "messages not yet
        // hydrated into the session store".
        let hasUnresolvedMessages = conversation
            .messageIDs
            .filter { $0.hasPrefix("-") }
            .contains { sessionStore.messages[$0] == nil }

        var messageMatchingSearchQuery: Message?
        if let searchQuery,
           !searchQuery.isBlank {
            messageMatchingSearchQuery = messages?.last(where: {
                $0.textContains(searchQuery)
            })
        }

        let lastMessage = messageMatchingSearchQuery ?? messages?.last
        let latestActivity = conversation
            .activities?
            .filter { $0 != .empty }
            .max(by: { $0.date < $1.date })

        if let latestActivity,
           messageMatchingSearchQuery == nil,
           latestActivity.date > (lastMessage?.sentDate ?? .distantPast),
           lastMessage != nil || !hasUnresolvedMessages {
            // Activities are the canonical source for system messages, whose
            // sent dates count equally toward the latest message resolution.
            if Application.isInStagingMode,
               calendar.isDateInToday(latestActivity.date) {
                dateLabelText = stagingModeDateFormatter.string(from: latestActivity.date)
            } else {
                dateLabelText = latestActivity.date.formattedShortString
            }

            subtitleLabelText = latestActivity.description.sanitized
        } else if let lastMessage {
            if Application.isInStagingMode,
               calendar.isDateInToday(lastMessage.sentDate) {
                dateLabelText = stagingModeDateFormatter.string(from: lastMessage.sentDate)
            } else {
                dateLabelText = lastMessage.sentDate.formattedShortString
            }

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
                ).sanitized.trimmingBorderedWhitespace : (isLastMessageFromCurrentUser ? translation.input.value.sanitized : translation.output.sanitized)

                subtitleLabelText = resolvedText
            }
        } else if !hasUnresolvedMessages {
            // The fallback applies only to fully hydrated conversations;
            // provisional builds keep placeholder values instead.
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
            thumbnailImage: thumbnailImage,
            isAwaitingMessageHydration: hasUnresolvedMessages
        )

        // Never cache provisional data; the next build must re-derive
        // it from the hydrated conversation.
        guard !hasUnresolvedMessages else { return }

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

@MainActor
enum ConversationCellViewDataCache {
    static func clearCache() {
        _ConversationCellViewDataCache.clearCache()
    }

    static func removeValues(forConversationIDKey idKey: String) {
        _ConversationCellViewDataCache.removeValues(forConversationIDKey: idKey)
    }
}

@MainActor
private enum _ConversationCellViewDataCache {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case dataByConversationIDForSearchQueries
    }

    // MARK: - Properties

    // swiftlint:disable:next identifier_name line_length
    @Cached(CacheKey.dataByConversationIDForSearchQueries) fileprivate static var cachedDataByConversationIDForSearchQueries: [String: [ConversationID: ConversationCellViewData]]?

    // MARK: - Methods

    fileprivate static func clearCache() {
        cachedDataByConversationIDForSearchQueries = nil
    }

    fileprivate static func removeValues(forConversationIDKey idKey: String) {
        guard var cache = cachedDataByConversationIDForSearchQueries else { return }

        for searchQuery in cache.keys {
            cache[searchQuery] = cache[searchQuery]?.filter { conversationID, _ in
                conversationID.key != idKey
            }
        }

        cachedDataByConversationIDForSearchQueries = cache
    }
}
