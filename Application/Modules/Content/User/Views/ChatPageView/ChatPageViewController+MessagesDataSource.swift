//
//  ChatPageViewController+MessagesDataSource.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

extension ChatPageViewController: MessagesDataSource {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageView.MessagesDataSource
    private typealias Floats = AppConstants.CGFloats.ChatPageView.MessagesDataSource
    private typealias Strings = AppConstants.Strings.ChatPageView.MessagesDataSource

    // MARK: - Properties

    public var currentSender: MessageKit.SenderType {
        @Persistent(.currentUserID) var currentUserID: String?
        // swiftformat:disable acronyms
        return Message.Sender(displayName: "", senderId: currentUserID ?? "")
        // swiftformat:enable acronyms
    }

    // MARK: - Audio Tint Color

    public func audioTintColor(
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) -> UIColor {
        guard let message = message as? Message,
              message.isFromCurrentUser else { return .accent }
        return UIColor(Colors.currentUserAudioTintColor)
    }

    // MARK: - Cell Bottom Label Attributed Text

    public func cellBottomLabelAttributedText(
        for message: MessageType,
        at indexPath: IndexPath
    ) -> NSAttributedString? {
        @Persistent(.isReactionsEnabled) var isReactionsEnabled: Bool?
        let reactionsEnabled = isReactionsEnabled ?? false
        var randomBool: Bool { Int.random(in: 1 ... 1_000_000) % 2 == 0 }

        guard reactionsEnabled,
              randomBool, randomBool else {
            guard let currentConversation,
                  currentConversation.participants.count == 2,
                  let messages = currentConversation.messages,
                  let message = message as? Message,
                  indexPath.section == messages.count - 1,
                  message.isFromCurrentUser,
                  !message.isMock else { return nil }

            let boldAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: Floats.cellBottomLabelAttributedTextBoldAttributesSystemFontSize),
                .foregroundColor: UIColor(Colors.cellBottomLabelAttributedTextBoldAttributesForeground),
            ]

            guard let readDate = message.readDate else {
                return .init(
                    string: Localized(.delivered).wrappedValue,
                    attributes: boldAttributes
                )
            }

            let readString = "\(Localized(.read).wrappedValue) \(readDate.formattedShortString)"
            return readString.attributed(
                mainAttributes: [
                    .font: UIFont.systemFont(ofSize: Floats.cellBottomLabelAttributedTextStandardAttributesSystemFontSize),
                    .foregroundColor: UIColor(Colors.cellBottomLabelAttributedTextStandardAttributesForeground),
                ],
                alternateAttributes: boldAttributes,
                alternateAttributeRange: [Localized(.read).wrappedValue]
            )
        }

        // FIXME: Test/scaffolding code.

        guard let currentConversation,
              let messages = currentConversation.messages,
              let message = message as? Message,
              !message.isMock else { return nil }

        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: Floats.cellBottomLabelAttributedTextBoldAttributesSystemFontSize),
            .foregroundColor: UIColor(Colors.cellBottomLabelAttributedTextBoldAttributesForeground),
        ]

        var reactions = [
            "👍",
            "❤️",
            "😂",
            "😮",
            "😢",
            "👎",
        ]

        if currentConversation.participants.count > 2 {
            reactions.append(contentsOf: [
                "👍❤️",
                "❤️😂",
                "❤️😂😂",
                "👍❤️😂😮😢👎",
                "👍👍👍👍❤️❤️😂😮😢👎",
                .init(repeating: "👍", count: Int.random(in: 1 ... currentConversation.participants.count)),
                .init(repeating: "❤️", count: Int.random(in: 1 ... currentConversation.participants.count)),
            ])
        }

        if currentConversation.participants.count == 2,
           indexPath.section == messages.count - 1,
           message.isFromCurrentUser {
            var lastMessageFromCurrentUserReactions = [
                Localized(.delivered).wrappedValue,
                "👍 | \(Localized(.delivered).wrappedValue)",
                "❤️ | \(Localized(.delivered).wrappedValue)",
                "😂 | \(Localized(.delivered).wrappedValue)",
                "😮 | \(Localized(.delivered).wrappedValue)",
            ]

            if let readDate = message.readDate {
                lastMessageFromCurrentUserReactions = [
                    "\(Localized(.read).wrappedValue) \(readDate.formattedShortString)",
                    "👍 | \(Localized(.read).wrappedValue) \(readDate.formattedShortString)",
                    "❤️ | \(Localized(.read).wrappedValue) \(readDate.formattedShortString)",
                    "😂 | \(Localized(.read).wrappedValue) \(readDate.formattedShortString)",
                    "😮 | \(Localized(.read).wrappedValue) \(readDate.formattedShortString)",
                ]
            }

            reactions = lastMessageFromCurrentUserReactions
        }

        guard let randomReaction = reactions.randomElement() else { return nil }
        return randomReaction.attributed(
            mainAttributes: [
                .font: UIFont.systemFont(ofSize: Floats.cellBottomLabelAttributedTextStandardAttributesSystemFontSize),
                .foregroundColor: UIColor(Colors.cellBottomLabelAttributedTextStandardAttributesForeground),
            ],
            alternateAttributes: boldAttributes,
            alternateAttributeRange: [Localized(.delivered).wrappedValue, Localized(.read).wrappedValue]
        )
    }

    // MARK: - Cell Top Label Attributed Text

    public func cellTopLabelAttributedText(
        for message: MessageType,
        at indexPath: IndexPath
    ) -> NSAttributedString? {
        currentConversation?
            .messages?
            .itemAt(indexPath.section)?
            .sentDate
            .chatPageMessageSeparatorAttributedDateString
    }

    // MARK: - Message Bottom Label Attributed Text

    public func messageBottomLabelAttributedText(
        for message: MessageType,
        at indexPath: IndexPath
    ) -> NSAttributedString? {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        return .init(
            string: dateFormatter.string(from: message.sentDate),
            attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2)]
        )
    }

    // MARK: - Message for Item

    public func messageForItem(
        at indexPath: IndexPath,
        in messagesCollectionView: MessageKit.MessagesCollectionView
    ) -> MessageKit.MessageType {
        guard !isSectionReservedForTypingIndicator(indexPath.section) else { return Message.empty }
        return currentConversation?.messages?.itemAt(indexPath.section) ?? Message.empty
    }

    // MARK: - Message Timestamp Label Attributed Text

    public func messageTimestampLabelAttributedText(
        for message: MessageType,
        at indexPath: IndexPath
    ) -> NSAttributedString? {
        guard let sentDate = currentConversation?.messages?.itemAt(indexPath.section)?.sentDate else { return nil }
        return .init(
            string: DateFormatter.localizedString(from: sentDate, dateStyle: .none, timeStyle: .short),
            attributes: [
                .font: UIFont.systemFont(ofSize: Floats.messageTimestampLabelAttributedTextAttributesSystemFontSize),
                .foregroundColor: UIColor(Colors.messageTimestampLabelAttributedTextAttributesForeground),
            ]
        )
    }

    // MARK: - Message Top Label Attributed Text

    public func messageTopLabelAttributedText(
        for message: MessageType,
        at indexPath: IndexPath
    ) -> NSAttributedString? {
        @Dependency(\.commonServices.contact.contactPairArchive) var contactPairArchive: ContactPairArchiveService

        guard let currentConversation,
              currentConversation.participants.count > 2,
              let messages = currentConversation.messages,
              let message = message as? Message,
              !message.isFromCurrentUser else { return nil }

        if messages.itemAt(indexPath.section - 1)?.fromAccountID == message.fromAccountID {
            return nil
        }

        guard let users = currentConversation.users,
              let matchingUser = users.first(where: { $0.id == message.fromAccountID }) else { return nil }

        let font: UIFont = .init(
            name: Strings.messageTopLabelAttributedTextAttributesFontName,
            size: Floats.messageTopLabelAttributedTextAttributesFontSize
        ) ?? .systemFont(ofSize: Floats.messageTopLabelAttributedTextAttributesFontSize)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(Colors.messageTopLabelAttributedTextAttributesForeground),
        ]

        let isAppDefaultTheme = ThemeService.isAppDefaultThemeApplied

        guard let contactPair = contactPairArchive.getValue(phoneNumber: matchingUser.phoneNumber) else {
            return .init(string: "\(isAppDefaultTheme ? "   " : "")\(matchingUser.phoneNumber.formattedString())", attributes: attributes)
        }

        return .init(string: "\(isAppDefaultTheme ? "   " : "")\(contactPair.contact.fullName)", attributes: attributes)
    }

    // MARK: - Number of Sections

    public func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
        (currentConversation?.messages ?? []).count
    }
}
