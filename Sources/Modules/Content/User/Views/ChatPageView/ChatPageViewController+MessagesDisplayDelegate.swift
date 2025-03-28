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

/* Proprietary */
import AppSubsystem

/* 3rd-party */
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
        currentConversation?.messages?.itemAt(indexPath.section)?.backgroundColor ?? .senderBubble
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

        guard ThemeService.isAppDefaultThemeApplied else { return }
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
        @Dependency(\.clientSession) var clientSession: ClientSession
        @Dependency(\.commonServices) var services: CommonServices

        guard let message = message as? Message,
              Application.isInPrevaricationMode || !message.isFromCurrentUser else { return }

        func configureGenericAvatar() {
            avatarView.backgroundColor = UIColor(Colors.genericAvatarViewBackground)
            avatarView.image = .init(systemName: Strings.avatarViewImageSystemName)
            avatarView.tintColor = UIColor(Colors.genericAvatarViewTint)
        }

        func configurePenPalsAvatar() {
            avatarView.backgroundColor = UIColor(Colors.penPalsAvatarViewBackground)

            guard let penPalsIconColor = currentConversation?.users?.first(where: { $0.id == message.fromAccountID })?.penPalsIconColor else {
                avatarView.image = SquareIconView.image(.penPalsIcon())
                avatarView.tintColor = UIColor(Colors.penPalsAvatarViewTint)
                return
            }

            avatarView.image = SquareIconView.image(.penPalsIcon(backgroundColor: .init(uiColor: penPalsIconColor)))
            avatarView.tintColor = penPalsIconColor
        }

        guard let users = currentConversation?.users,
              let currentUser = clientSession.user.currentUser,
              let matchingUser = (users + [currentUser]).first(where: { $0.id == message.fromAccountID }) else {
            return configureGenericAvatar()
        }

        guard clientSession.conversation.currentConversation?.mutuallySharedPenPalsDataBetweenCurrentUserAnd(matchingUser) == true ||
            services.penPals.isKnownToCurrentUser(matchingUser.id) else {
            return configurePenPalsAvatar()
        }

        guard let contactPair = services.contact.contactPairArchive.getValue(phoneNumber: matchingUser.phoneNumber) else {
            return configureGenericAvatar()
        }

        guard let image = contactPair.contact.image else {
            if let cachedInitialsImage = _ContactInitialsImageCache.cachedInitialsImagesForContactIDs?[contactPair.contact.id] {
                avatarView.image = cachedInitialsImage
            }

            let initialsImage = UIImage.fromInitials(contactPair.contact.initials)
            avatarView.image = initialsImage

            guard let initialsImage else { return }
            var cachedInitialsImagesForContactIDs = _ContactInitialsImageCache.cachedInitialsImagesForContactIDs ?? [:]
            cachedInitialsImagesForContactIDs[contactPair.contact.id] = initialsImage
            _ContactInitialsImageCache.cachedInitialsImagesForContactIDs = cachedInitialsImagesForContactIDs
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
        guard !Application.isInPrevaricationMode,
              ThemeService.isAppDefaultThemeApplied else {
            return message.contentType.isAudio || message.contentType == .text ? .custom { view in
                view.layer.cornerRadius = Floats.messageStyleCustomLayerCornerRadius
                view.layer.masksToBounds = false

                view.layer.shadowColor = UIColor(Colors.messageStyleCustomLayerShadowColor).cgColor
                view.layer.shadowOffset = .init(
                    width: 0,
                    height: Floats.messageStyleCustomLayerShadowOffsetHeight
                )
                view.layer.shadowOpacity = Float(Floats.messageStyleCustomLayerShadowOpacity)
                view.layer.shadowRadius = Floats.messageStyleCustomLayerShadowRadius
            } : .bubble
        }

        guard message.documentComponent == nil else { return .bubbleOutline(.gray) }
        return message.isFromCurrentUser ? .bubbleTail(.bottomRight, .curved) : .bubbleTail(.bottomLeft, .curved)
    }
}

public enum ContactInitialsImageCache {
    public static func clearCache() {
        _ContactInitialsImageCache.clearCache()
    }
}

private enum _ContactInitialsImageCache {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case initialsImagesForContactIDs
    }

    // MARK: - Properties

    @Cached(CacheKey.initialsImagesForContactIDs) fileprivate static var cachedInitialsImagesForContactIDs: [String: UIImage]?

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedInitialsImagesForContactIDs = nil
    }
}
