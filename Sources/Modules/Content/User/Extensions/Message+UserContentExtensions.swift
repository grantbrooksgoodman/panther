//
//  Message+UserContentExtensions.swift
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

// swiftformat:disable acronyms

extension Message: MessageType {
    // MARK: - Types

    public struct Sender: SenderType {
        public let displayName: String
        public let senderId: String
    }

    // MARK: - Properties

    public var kind: MessageKind {
        @Dependency(\.chatPageViewService.alternateMessage) var alternateMessageService: AlternateMessageService?

        typealias Colors = AppConstants.Colors.UserContentExtensions.Message

        // swiftlint:disable:next line_length
        let nonCurrentUserForegroundColor = !Application.isInPrevaricationMode && ThemeService.isDarkModeActive ? Colors.kindAttributedTextDarkForeground : Colors.kindAttributedTextLightForeground
        let attributedStringForegroundColor = UIColor(isFromCurrentUser ? Colors.kindAttributedTextCurrentUserForeground : nonCurrentUserForegroundColor)

        switch contentType {
        case .media(.audio):
            if let audioComponent,
               let translation {
                guard alternateMessageService?.isDisplayingAudioTranscription(for: self) ?? false else {
                    return .audio(isFromCurrentUser ? audioComponent.original : audioComponent.translated)
                }

                return .attributedText(
                    .messageCellString(
                        isFromCurrentUser ? translation.input.value.sanitized : translation.output,
                        foregroundColor: attributedStringForegroundColor,
                        italicized: true
                    )
                )
            }

        case .media:
            if let documentComponent {
                return .photo(documentComponent)
            } else if let imageComponent {
                return .photo(imageComponent)
            } else if let videoComponent {
                return .video(videoComponent)
            }

        default: ()
        }

        guard let translation else { return .text("�") }

        let isDisplayingAlternateText = alternateMessageService?.isDisplayingAlternateText(for: self) ?? false
        let primaryText = isFromCurrentUser ? translation.input.value.sanitized : translation.output
        let alternateText = isFromCurrentUser ? translation.output : translation.input.value.sanitized

        return .attributedText(
            .messageCellString(
                isDisplayingAlternateText ? alternateText : primaryText,
                foregroundColor: attributedStringForegroundColor,
                italicized: isDisplayingAlternateText
            )
        )
    }

    public var messageId: String { id }
    public var sender: SenderType { Sender(displayName: "", senderId: fromAccountID) }
}

// swiftformat:enable acronyms

public extension Message {
    var backgroundColor: UIColor { isFromCurrentUser ? .senderBubble : .receiverBubble }

    var isFromCurrentUser: Bool {
        @Persistent(.currentUserID) var currentUserID: String?
        return fromAccountID == currentUserID
    }

    var isMock: Bool { id == CommonConstants.newMessageID }

    var isPlayingMessage: Bool {
        @Dependency(\.chatPageViewService.audioMessagePlayback?.playingMessage) var playingMessage: Message?
        guard contentType.isAudio,
              audioComponent != nil,
              let playingMessage else { return false }
        return playingMessage.id == id
    }

    var isSpeakingMessage: Bool {
        @Dependency(\.chatPageViewService.contextMenu?.actionHandler.speakingMessage) var speakingMessage: Message?
        guard let speakingMessage else { return false }
        return speakingMessage.id == id
    }
}
