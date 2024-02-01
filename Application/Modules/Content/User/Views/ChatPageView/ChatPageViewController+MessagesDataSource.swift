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

/* 3rd-party */
import MessageKit
import Redux

extension ChatPageViewController: MessagesDataSource {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageView
    private typealias Floats = AppConstants.CGFloats.ChatPageView
    private typealias Strings = AppConstants.Strings.ChatPageView

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
        return UIColor(Colors.dataSourceCurrentUserAudioTintColor)
    }

    // MARK: - Cell Bottom Label Attributed Text

    public func cellBottomLabelAttributedText(
        for message: MessageType,
        at indexPath: IndexPath
    ) -> NSAttributedString? {
        guard let conversation,
              let messages = conversation.messages,
              let message = message as? Message,
              indexPath.section == messages.count - 1,
              message.isFromCurrentUser,
              !message.isMock else { return nil }

        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: Floats.dataSourceCellBottomLabelAttributedTextBoldAttributesSystemFontSize),
            .foregroundColor: UIColor(Colors.dataSourceCellBottomLabelAttributedTextBoldAttributesForeground),
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
                .font: UIFont.systemFont(ofSize: Floats.dataSourceCellBottomLabelAttributedTextStandardAttributesSystemFontSize),
                .foregroundColor: UIColor(Colors.dataSourceCellBottomLabelAttributedTextStandardAttributesForeground),
            ],
            alternateAttributes: boldAttributes,
            alternateAttributeRange: [Localized(.read).wrappedValue]
        )
    }

    // MARK: - Cell Top Label Attributed Text

    public func cellTopLabelAttributedText(
        for message: MessageType,
        at indexPath: IndexPath
    ) -> NSAttributedString? {
        guard let messages = conversation?.messages,
              indexPath.section < messages.count else { return nil }
        return messages[indexPath.section].sentDate.chatPageMessageSeparatorAttributedDateString
    }

    // MARK: - Configure Audio Cell

    public func configureAudioCell(_ cell: AudioMessageCell, message: MessageType) {
        guard let message = message as? Message else { return }
        cell.playButton.isEnabled = !message.isMock // TODO: Audit this.

        guard message.isFromCurrentUser else {
            cell.durationLabel.textColor = .accent
            cell.playButton.tintColor = .accent
            cell.progressView.progressTintColor = .accent
            cell.progressView.trackTintColor = nil
            return
        }

        guard ThemeService.isDefaultThemeApplied else { return }
        cell.progressView.trackTintColor = message
            .backgroundColor
            .darker(by: Floats.dataSourceAudioCellProgressViewDefaultThemeTrackTintColorDarkeningPercentage)?
            .withAlphaComponent(Floats.dataSourceAudioCellProgressViewDefaultThemeTrackTintColorAlphaComponent)
    }

    // MARK: - Message Bottom Label Attributed Text

    public func messageBottomLabelAttributedText(
        for message: MessageType,
        at indexPath: IndexPath
    ) -> NSAttributedString? {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter
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
        guard let messages = conversation?.messages,
              !messages.isEmpty else { return Message.empty }
        guard indexPath.section < messages.count else { return messages.last! }
        return messages[indexPath.section]
    }

    // MARK: - Message Top Label Attributed Text

    public func messageTopLabelAttributedText(
        for message: MessageType,
        at indexPath: IndexPath
    ) -> NSAttributedString? {
        @Dependency(\.commonServices.contact.contactPairArchive) var contactPairArchive: ContactPairArchiveService

        guard let conversation,
              conversation.participants.count > 2,
              let messages = conversation.messages,
              let message = message as? Message,
              !message.isFromCurrentUser,
              messages.count > indexPath.section else { return nil }

        if indexPath.section - 1 > -1,
           messages[indexPath.section - 1].fromAccountID == message.fromAccountID {
            return nil
        }

        guard let users = conversation.users,
              let matchingUser = users.first(where: { $0.id == message.fromAccountID }) else { return nil }

        let font: UIFont = .init(
            name: Strings.dataSourceMessageTopLabelAttributedTextAttributesFontName,
            size: Floats.dataSourceMessageTopLabelAttributedTextAttributesFontSize
        ) ?? .systemFont(ofSize: Floats.dataSourceMessageTopLabelAttributedTextAttributesFontSize)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(Colors.dataSourceMessageTopLabelAttributedTextAttributesForeground),
        ]

        let isDefaultTheme = ThemeService.isDefaultThemeApplied

        guard let contactPair = contactPairArchive.getValue(userNumberHash: matchingUser.phoneNumber.nationalNumberString.digits.compressedHash) else {
            return .init(string: "\(isDefaultTheme ? "   " : "")\(matchingUser.phoneNumber.formattedString())", attributes: attributes)
        }

        return .init(string: "\(isDefaultTheme ? "   " : "")\(contactPair.contact.fullName)", attributes: attributes)
    }

    // MARK: - Number of Sections

    public func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
        (conversation?.messages ?? []).count
    }
}
