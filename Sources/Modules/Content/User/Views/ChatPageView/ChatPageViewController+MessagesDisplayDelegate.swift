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

extension ChatPageViewController: @MainActor MessagesDisplayDelegate {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageView.MessagesDisplayDelegate
    private typealias Floats = AppConstants.CGFloats.ChatPageView.MessagesDisplayDelegate
    private typealias Strings = AppConstants.Strings.ChatPageView.MessagesDisplayDelegate

    // MARK: - Background Color

    func backgroundColor(
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) -> UIColor {
        currentConversation?.messages?.itemAt(indexPath.section)?.backgroundColor ?? .senderBubble
    }

    // MARK: - Configure Audio Cell

    func configureAudioCell(_ cell: AudioMessageCell, message: MessageType) {
        @Dependency(\.chatPageViewService.audioMessagePlayback) var audioMessagePlaybackService: AudioMessagePlaybackService?
        guard let message = message as? Message else { return }

        cell.playButton.setImage(.play.withRenderingMode(.alwaysTemplate), for: .normal)
        cell.playButton.setImage(.stop.withRenderingMode(.alwaysTemplate), for: .selected)

        let accentColor: UIColor = message.isFromCurrentUser ? UIColor(Colors.audioCellProgressViewCurrentUserAccent) : .accent

        cell.durationLabel.textColor = accentColor
        cell.playButton.tintColor = accentColor

        cell.progressView.progressTintColor = accentColor
        cell.progressView.trackTintColor = message.isFromCurrentUser ? message
            .backgroundColor
            .darker(by: Floats.audioCellProgressViewTrackTintColorDarkeningPercentage)?
            .withAlphaComponent(Floats.audioCellProgressViewTrackTintColorAlphaComponent) : nil

        guard message.isPlayingMessage else { return }

        audioMessagePlaybackService?.setPlayingCell(cell)
        cell.playButton.isSelected = true
    }

    // MARK: - Configure Avatar View

    func configureAvatarView(
        _ avatarView: AvatarView,
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) {
        @Dependency(\.clientSession) var clientSession: ClientSession
        @Dependency(\.commonServices.penPals) var penPalsService: PenPalsService

        guard let message = message as? Message,
              Application.isInPrevaricationMode || !message.isFromCurrentUser else { return }

        func configureGenericAvatar() {
            avatarView.backgroundColor = UIColor(Colors.genericAvatarViewBackground)
            avatarView.image = .init(systemName: Strings.avatarViewImageSystemName)
            avatarView.tintColor = UIColor(Colors.genericAvatarViewTint)
        }

        func configurePenPalsAvatar() {
            avatarView.backgroundColor = UIColor(Colors.penPalsAvatarViewBackground)

            guard let penPalsIconColor = (
                currentConversation?
                    .users?
                    .first(where: { $0.id == message.fromAccountID }) ??
                    UserCache
                    .knownUsers
                    .first(where: { $0.id == message.fromAccountID })
            )?
                .penPalsIconColor else {
                avatarView.image = SquareIconView.image(.penPalsIcon())
                avatarView.tintColor = UIColor(Colors.penPalsAvatarViewTint)
                return
            }

            avatarView.image = SquareIconView.image(.penPalsIcon(backgroundColor: .init(uiColor: penPalsIconColor)))
            avatarView.tintColor = penPalsIconColor
        }

        guard let users = currentConversation?.users,
              let currentUser = clientSession.user.currentUser,
              let matchingUser = (users + [currentUser])
              .first(where: { $0.id == message.fromAccountID }) ??
              UserCache
              .knownUsers
              .first(where: { $0.id == message.fromAccountID }) else {
            return configureGenericAvatar()
        }

        guard clientSession.conversation.currentConversation?.mutuallySharedPenPalsDataBetweenCurrentUserAnd(matchingUser) == true ||
            penPalsService.isKnownToCurrentUser(matchingUser.id) else {
            return configurePenPalsAvatar()
        }

        guard let contactPair = matchingUser.contactPair else { return configureGenericAvatar() }

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

    func detectorAttributes(
        for detector: DetectorType,
        and message: MessageType,
        at indexPath: IndexPath
    ) -> [NSAttributedString.Key: Any] {
        guard let message = message as? Message else { return .init() }

        let primaryColor = UIColor(Colors.detectorAttributesPrimaryForeground)
        let alternateColor = UIColor(Colors.detectorAttributesAlternateForeground)
        let colorToUse = message.isFromCurrentUser ? primaryColor : (ThemeService.isDarkModeActive ? primaryColor : alternateColor)

        return [
            .foregroundColor: colorToUse,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
    }

    // MARK: - Enabled Detectors

    func enabledDetectors(
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) -> [DetectorType] {
        [.date, .phoneNumber, .url]
    }

    // MARK: - Message Style

    func messageStyle(
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

@MainActor
enum ContactInitialsImageCache {
    static func clearCache() {
        _ContactInitialsImageCache.clearCache()
    }
}

@MainActor
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
