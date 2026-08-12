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

extension ChatPageViewController: @MainActor MessagesDataSource {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageView.MessagesDataSource
    private typealias Floats = AppConstants.CGFloats.ChatPageView.MessagesDataSource
    private typealias Strings = AppConstants.Strings.ChatPageView.MessagesDataSource

    // MARK: - Properties

    /// The sender representing the current user.
    var currentSender: MessageKit.SenderType {
        // swiftformat:disable acronyms
        Message.Sender(displayName: "", senderId: User.currentUserID ?? "")
        // swiftformat:enable acronyms
    }

    // MARK: - Audio Tint Color

    /// Returns the tint color for the given message's audio cell.
    func audioTintColor(
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) -> UIColor {
        guard let message = message as? Message,
              message.isFromCurrentUser else { return .accent }
        return UIColor(Colors.currentUserAudioTintColor)
    }

    // MARK: - Cell Bottom Label Attributed Text

    // swiftlint:disable function_body_length
    /// Returns the attributed text for the cell's bottom label, such as the message's delivery
    /// status, read receipt, reactions, or translation details.
    func cellBottomLabelAttributedText(
        for message: MessageType,
        at indexPath: IndexPath
    ) -> NSAttributedString? { // TODO: Refactor this method.
        @Dependency(\.chatPageViewService.alternateMessage) var alternateMessageService: AlternateMessageService?
        guard let currentConversation,
              let message = message as? Message,
              !message.isMock,
              !message.isOutboxMessage || message.isFailedOutboxMessage else { return nil }

        if message.isFailedOutboxMessage {
            return Localized(.notDelivered)
                .wrappedValue
                .attributed(.init([
                    .font: UIFont.boldSystemFont(ofSize: Floats.cellBottomLabelAttributedTextBoldAttributesSystemFontSize),
                    .foregroundColor: UIColor.systemRed,
                ]))
        }

        let messages = displayedMessages

        var boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: Floats.cellBottomLabelAttributedTextBoldAttributesSystemFontSize),
            .foregroundColor: UIColor(Colors.cellBottomLabelAttributedTextBoldAttributesForeground),
        ]

        var emojiAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: Floats.cellBottomLabelAttributedTextEmojiAttributesSystemFontSize),
        ]

        var standardAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: Floats.cellBottomLabelAttributedTextStandardAttributesSystemFontSize),
            .foregroundColor: UIColor(Colors.cellBottomLabelAttributedTextStandardAttributesForeground),
        ]

        if Application.isInPrevaricationMode {
            boldAttributes[.baselineOffset] = -1
            emojiAttributes[.baselineOffset] = -1
            standardAttributes[.baselineOffset] = -1
        }

        var reactionsString = ""
        if let reactions = message.reactions {
            reactionsString += reactions
                .map(\.style)
                .sorted(by: { $0.orderValue < $1.orderValue })
                .map(\.emojiValue)
                .joined()
        }

        let fromLanguageExonym = message.translation?.languagePair.from.languageExonym ?? .bangQualifiedEmpty
        let toLanguageExonym = message.translation?.languagePair.to.languageExonym ?? .bangQualifiedEmpty
        let aiEnhancedString = "✨\(Localized(.aiEnhanced).wrappedValue)"

        let attributedStringConfig: AttributedStringConfig = .init(
            standardAttributes,
            secondaryAttributes: [
                .init(
                    boldAttributes,
                    stringRanges: [
                        aiEnhancedString,
                        fromLanguageExonym,
                        toLanguageExonym,
                        Localized(.delivered).wrappedValue,
                        Localized(.read).wrappedValue,
                    ]
                ),
                .init(
                    emojiAttributes,
                    stringRanges: [
                        "✨",
                        reactionsString,
                    ]
                ),
            ]
        )

        if let alternateMessageService,
           alternateMessageService.isDisplayingAlternateText(for: message),
           !fromLanguageExonym.isBangQualifiedEmpty,
           !toLanguageExonym.isBangQualifiedEmpty {
            let originalString = Localized(.originalInLanguage)
                .wrappedValue
                .replacingOccurrences(of: "⌘", with: fromLanguageExonym)
            let translationString = Localized(.translationInLanguage)
                .wrappedValue
                .replacingOccurrences(of: "⌘", with: toLanguageExonym)
            let alternateMessageString = message.isFromCurrentUser ? translationString : originalString
            reactionsString = "\(reactionsString.isBlank ? "" : "\(reactionsString) | ")\(alternateMessageString)"
        }

        if alternateMessageService == nil ||
            alternateMessageService?.isDisplayingAlternateText(for: message) == false,
            indexPath.section < messages.count - 1 || !message.isFromCurrentUser,
            message.translation?.isAIEnhanced == true {
            return "\(reactionsString.isBlank ? "" : "\(reactionsString) | ")\(aiEnhancedString)"
                .attributed(attributedStringConfig)
        }

        let lastConfirmedOwnIndex = messages.lastIndex(where: {
            $0.isFromCurrentUser && !$0.isOutboxMessage
        })

        guard currentConversation.participants.count == 2,
              indexPath.section == lastConfirmedOwnIndex,
              message.isFromCurrentUser,
              !reactionsString.contains("|") else {
            guard reactionsString.contains(where: \.isLetter) else {
                return reactionsString.attributed(.init(emojiAttributes))
            }

            return reactionsString.attributed(attributedStringConfig)
        }

        var prefix = reactionsString.isBangQualifiedEmpty ? "" : "\(reactionsString) |"
        if prefix.isBlank,
           message.translation?.isAIEnhanced == true {
            prefix = "\(aiEnhancedString) |"
        }

        guard let readDate = message
            .readReceipts?
            .first(where: { $0.userID != User.currentUserID })?
            .readDate else {
            return "\(prefix) \(Localized(.delivered).wrappedValue)".attributed(attributedStringConfig)
        }

        return "\(prefix) \(Localized(.read).wrappedValue) \(readDate.formattedShortString)".attributed(attributedStringConfig)
    } // swiftlint:enable function_body_length

    // MARK: - Cell Top Label Attributed Text

    /// Returns the attributed text for the cell's top label, showing the message's date
    /// separator.
    func cellTopLabelAttributedText(
        for message: MessageType,
        at indexPath: IndexPath
    ) -> NSAttributedString? {
        displayedMessages
            .itemAt(indexPath.section)?
            .sentDate
            .chatPageMessageSeparatorAttributedDateString
    }

    // MARK: - Message Bottom Label Attributed Text

    /// Returns the attributed text for the message's bottom label, showing its sent time.
    func messageBottomLabelAttributedText(
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

    /// Returns the message to display at the given index path.
    func messageForItem(
        at indexPath: IndexPath,
        in messagesCollectionView: MessageKit.MessagesCollectionView
    ) -> MessageKit.MessageType {
        guard !isSectionReservedForTypingIndicator(indexPath.section),
              let message = displayedMessages.itemAt(indexPath.section) else { return Message.empty }
        return message.systemLocalized
    }

    // MARK: - Message Timestamp Label Attributed Text

    /// Returns the attributed text for the message's timestamp label, shown when the user swipes.
    func messageTimestampLabelAttributedText(
        for message: MessageType,
        at indexPath: IndexPath
    ) -> NSAttributedString? {
        guard let sentDate = displayedMessages.itemAt(indexPath.section)?.sentDate else { return nil }
        return .init(
            string: DateFormatter.localizedString(from: sentDate, dateStyle: .none, timeStyle: .short),
            attributes: [
                .font: UIFont.systemFont(ofSize: Floats.messageTimestampLabelAttributedTextAttributesSystemFontSize),
                .foregroundColor: UIColor(Colors.messageTimestampLabelAttributedTextAttributesForeground),
            ]
        )
    }

    // MARK: - Message Top Label Attributed Text

    /// Returns the attributed text for the message's top label, showing the sender's name in
    /// group conversations.
    func messageTopLabelAttributedText(
        for message: MessageType,
        at indexPath: IndexPath
    ) -> NSAttributedString? {
        @Dependency(\.commonServices.penPals) var penPalsService: PenPalsService
        @Dependency(\.clientSession.store) var sessionStore: SessionStore

        guard let currentConversation,
              currentConversation.participants.count > 2,
              let message = message as? Message,
              !message.isFromCurrentUser else { return nil }
        let messages = displayedMessages

        if messages.itemAt(indexPath.section - 1)?.fromAccountID == message.fromAccountID {
            return nil
        }

        guard let matchingUser = currentConversation
            .users?
            .first(where: {
                $0.id == message.fromAccountID
            }) ?? sessionStore.users[message.fromAccountID] else { return nil }

        let font: UIFont = .init(
            name: Strings.messageTopLabelAttributedTextAttributesFontName,
            size: Floats.messageTopLabelAttributedTextAttributesFontSize
        ) ?? .systemFont(ofSize: Floats.messageTopLabelAttributedTextAttributesFontSize)

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(Colors.messageTopLabelAttributedTextAttributesForeground),
        ]

        if Application.isInPrevaricationMode {
            attributes[.baselineOffset] = Floats.messageTopLabelAttributedTextAttributesBaselineOffset
        }

        let prefix = "\((!Application.isInPrevaricationMode && ThemeService.isAppDefaultThemeApplied) ? "   " : "")"
        guard currentConversation.userSharesPenPalsDataWithCurrentUser(matchingUser) ||
            penPalsService.isKnownToCurrentUser(matchingUser.id) else {
            return .init(string: "\(prefix)\(matchingUser.penPalsName)", attributes: attributes)
        }

        let contactName = matchingUser
            .contactPair?
            .contact
            .fullName ?? matchingUser.phoneNumber.formattedString()

        return .init(string: "\(prefix)\(contactName)", attributes: attributes)
    }

    // MARK: - Number of Sections

    /// Returns the number of message sections.
    func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
        displayedMessages.count
    }
}
