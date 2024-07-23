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
import CoreArchitecture
import MessageKit

extension ChatPageViewController: MessagesDisplayDelegate {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageView.MessagesDisplayDelegate
    private typealias Floats = AppConstants.CGFloats.ChatPageView.MessagesDisplayDelegate
    private typealias Strings = AppConstants.Strings.ChatPageView.MessagesDisplayDelegate

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

    // MARK: - Configure Audio Cell

    public func configureAudioCell(_ cell: AudioMessageCell, message: MessageType) {
        guard let message = message as? Message else { return }

        cell.playButton.setImage(.play.withRenderingMode(.alwaysTemplate), for: .normal)
        cell.playButton.setImage(.stop.withRenderingMode(.alwaysTemplate), for: .selected)

        func setPlayingCellIfNeeded() {
            @Dependency(\.chatPageViewService.audioMessagePlayback) var audioMessagePlaybackService: AudioMessagePlaybackService?
            guard message.isPlayingMessage else { return }
            audioMessagePlaybackService?.setPlayingCell(cell)
            cell.playButton.isSelected = true
        }

        defer { setPlayingCellIfNeeded() }

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
            .darker(by: Floats.audioCellProgressViewDefaultThemeTrackTintColorDarkeningPercentage)?
            .withAlphaComponent(Floats.audioCellProgressViewDefaultThemeTrackTintColorAlphaComponent)
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
            avatarView.backgroundColor = UIColor(Colors.genericAvatarViewBackground)
            avatarView.image = .init(systemName: Strings.avatarViewImageSystemName)
            avatarView.tintColor = UIColor(Colors.genericAvatarViewTint)
        }

        guard let users = currentConversation?.users,
              let matchingUser = users.first(where: { $0.id == message.fromAccountID }), // TODO: Cache the below value.
              let contactPair = contactPairArchive.getValue(phoneNumber: matchingUser.phoneNumber) else {
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

        let primaryColor = UIColor(Colors.detectorAttributesPrimaryForeground)
        let alternateColor = UIColor(Colors.detectorAttributesAlternateForeground)
        let colorToUse = message.isFromCurrentUser ? primaryColor : (ThemeService.isDarkModeActive ? primaryColor : alternateColor)

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
            return .custom { $0.layer.cornerRadius = Floats.messageStyleCustomLayerCornerRadius }
        }

        guard message.documentComponent == nil else { return .bubbleOutline(.gray) }

        return message.isFromCurrentUser ? .bubbleTail(.bottomRight, .curved) : .bubbleTail(.bottomLeft, .curved)
    }
}
