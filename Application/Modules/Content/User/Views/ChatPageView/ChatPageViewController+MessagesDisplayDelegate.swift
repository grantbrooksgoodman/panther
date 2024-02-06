//
//  ChatPageViewController+MessagesDisplayDelegate.swift
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

extension ChatPageViewController: MessagesDisplayDelegate {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageView
    private typealias Floats = AppConstants.CGFloats.ChatPageView
    private typealias Strings = AppConstants.Strings.ChatPageView

    // MARK: - Background Color

    public func backgroundColor(
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) -> UIColor {
        guard let messages = currentConversation?.messages,
              indexPath.section < messages.count else { return .senderBubble }
        return messages[indexPath.section].backgroundColor
    }

    // MARK: - Configure Avatar View

    public func configureAvatarView(
        _ avatarView: AvatarView,
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) {
        @Dependency(\.commonServices.contact.contactPairArchive) var contactPairArchive: ContactPairArchiveService

        guard let message = message as? Message,
              !message.isFromCurrentUser else { return }

        func configureGenericAvatar() {
            avatarView.backgroundColor = UIColor(Colors.displayDelegateGenericAvatarViewBackground)
            avatarView.image = .init(named: Strings.displayDelegateGenericAvatarViewImageName)
            avatarView.tintColor = UIColor(Colors.displayDelegateGenericAvatarViewTint)
        }

        guard let users = currentConversation?.users,
              let matchingUser = users.first(where: { $0.id == message.fromAccountID }), // TODO: Cache the below value.
              let contactPair = contactPairArchive.getValue(userNumberHash: matchingUser.phoneNumber.nationalNumberString.digits.encodedHash) else {
            configureGenericAvatar()
            return
        }

        guard let imageData = contactPair.contact.imageData,
              let image = UIImage(data: imageData) else {
            avatarView.set(avatar: .init(initials: contactPair.contact.initials))
            return
        }

        avatarView.image = image
    }

    // MARK: - Detector Attributes

    public func detectorAttributes(
        for detector: DetectorType,
        and message: MessageType,
        at indexPath: IndexPath
    ) -> [NSAttributedString.Key: Any] {
        guard let message = message as? Message else { return .init() }

        let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
        let primaryColor = UIColor(Colors.displayDelegateDetectorAttributesPrimaryForeground)
        let alternateColor = UIColor(Colors.displayDelegateDetectorAttributesAlternateForeground)
        let colorToUse = message.isFromCurrentUser ? primaryColor : (isDarkMode ? primaryColor : alternateColor)

        var attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: colorToUse,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]

        guard let cell = messagesCollectionView.cellForItem(at: indexPath) as? TextMessageCell else { return attributes }
        attributes[.font] = cell.messageLabel.font
        return attributes
    }

    // MARK: - Enabled Detectors

    public func enabledDetectors(
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) -> [DetectorType] {
        [.date, .phoneNumber, .url]
    }

    // MARK: - Message Style

    public func messageStyle(
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) -> MessageStyle {
        guard let message = message as? Message else { return .none }

        guard ThemeService.isDefaultThemeApplied else {
            return .custom { $0.layer.cornerRadius = Floats.displayDelegateMessageStyleCustomLayerCornerRadius }
        }

        return message.isFromCurrentUser ? .bubbleTail(.bottomRight, .curved) : .bubbleTail(.bottomLeft, .curved)
    }
}
