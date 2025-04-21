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
        @Dependency(\.chatPageViewService.alternateMessage) var alternateMessageService: AlternateMessageService?
        guard let currentConversation,
              let messages = currentConversation.messages,
              let message = message as? Message,
              !message.isMock else { return nil }

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
            reactionsString += reactions.map(\.style).sorted(by: { $0.orderValue < $1.orderValue }).map(\.emojiValue).joined()
        }

        let fromLanguageExonym = message.translation?.languagePair.from.languageExonym ?? .bangQualifiedEmpty
        let toLanguageExonym = message.translation?.languagePair.to.languageExonym ?? .bangQualifiedEmpty
        let attributedStringConfig: AttributedStringConfig = .init(
            standardAttributes,
            secondaryAttributes: [
                .init(
                    boldAttributes,
                    stringRanges: [
                        fromLanguageExonym,
                        toLanguageExonym,
                        Localized(.delivered).wrappedValue,
                        Localized(.read).wrappedValue,
                    ]
                ),
                .init(emojiAttributes, stringRanges: [reactionsString]),
            ]
        )

        if let alternateMessageService,
           alternateMessageService.isDisplayingAlternateText(for: message),
           !fromLanguageExonym.isBangQualifiedEmpty,
           !toLanguageExonym.isBangQualifiedEmpty {
            let originalString = Localized(.originalInLanguage).wrappedValue.replacingOccurrences(of: "⌘", with: fromLanguageExonym)
            let translationString = Localized(.translationInLanguage).wrappedValue.replacingOccurrences(of: "⌘", with: toLanguageExonym)
            let alternateMessageString = message.isFromCurrentUser ? translationString : originalString
            reactionsString = "\(reactionsString.isBlank ? "" : "\(reactionsString) | ")\(alternateMessageString)"
        }

        guard currentConversation.participants.count == 2,
              indexPath.section == messages.count - 1,
              message.isFromCurrentUser,
              !reactionsString.contains("|") else {
            guard reactionsString.contains(where: { $0.isLetter }) else { return reactionsString.attributed(.init(emojiAttributes)) }
            return reactionsString.attributed(attributedStringConfig)
        }

        @Persistent(.currentUserID) var currentUserID: String?
        let prefix = reactionsString.isBangQualifiedEmpty ? "" : "\(reactionsString) |"
        guard let readDate = message.readReceipts?.first(where: { $0.userID != currentUserID })?.readDate else {
            return "\(prefix) \(Localized(.delivered).wrappedValue)".attributed(attributedStringConfig)
        }

        return "\(prefix) \(Localized(.read).wrappedValue) \(readDate.formattedShortString)".attributed(attributedStringConfig)
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
        @Dependency(\.commonServices) var services: CommonServices

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

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(Colors.messageTopLabelAttributedTextAttributesForeground),
        ]

        if Application.isInPrevaricationMode {
            attributes[.baselineOffset] = Floats.messageTopLabelAttributedTextAttributesBaselineOffset
        }

        let prefix = "\((!Application.isInPrevaricationMode && ThemeService.isAppDefaultThemeApplied) ? "   " : "")"
        guard currentConversation.userSharesPenPalsDataWithCurrentUser(matchingUser) ||
            services.penPals.isKnownToCurrentUser(matchingUser.id) else {
            return .init(string: "\(prefix)\(matchingUser.penPalsName)", attributes: attributes)
        }

        let contactName = services
            .contact
            .contactPairArchive
            .getValue(phoneNumber: matchingUser.phoneNumber)?
            .contact
            .fullName ?? matchingUser.phoneNumber.formattedString()

        return .init(string: "\(prefix)\(contactName)", attributes: attributes)
    }

    // MARK: - Number of Sections

    public func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
        currentConversation?.messages?.count ?? 0
    }
}
