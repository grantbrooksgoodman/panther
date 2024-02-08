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

/* 3rd-party */
import MessageKit
import Redux

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

        guard hasAudioComponent,
              let audioComponent else {
            guard alternateMessageService?.isDisplayingAlternate(for: self) ?? false else {
                return .text(isFromCurrentUser ? translation.input.value() : translation.output)
            }

            typealias Colors = AppConstants.Colors.ChatPageView
            typealias Floats = AppConstants.CGFloats.ChatPageView

            let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
            let nonCurrentUserForegroundColor = isDarkMode ? Colors.messageAttributedTextDarkForeground : Colors.messageAttributedTextLightForeground

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = Floats.messageAttributedTextParagraphLineSpacing
            return .attributedText(
                .init(
                    string: isFromCurrentUser ? translation.output : translation.input.value(),
                    attributes: [
                        .font: UIFont.systemFont(ofSize: Floats.messageAttributedTextSystemFontSize).italicized,
                        .foregroundColor: UIColor(isFromCurrentUser ? Colors.messageAttributedTextCurrentUserForeground : nonCurrentUserForegroundColor),
                        .paragraphStyle: paragraphStyle,
                    ]
                )
            )
        }

        return .audio(isFromCurrentUser ? audioComponent.original : audioComponent.translated)
    }

    public var messageId: String { id }
    public var sender: SenderType { Sender(displayName: "", senderId: fromAccountID) }
}

// swiftformat:enable acronyms

public extension Message {
    var backgroundColor: UIColor { isFromCurrentUser ? .senderBubble : .receiverBubble }

    static var empty: Message {
        .init(
            "",
            fromAccountID: "",
            hasAudioComponent: false,
            audioComponents: nil,
            translations: [
                .init(
                    input: .init(""),
                    output: "",
                    languagePair: .system
                ),
            ],
            readDate: nil,
            sentDate: .init()
        )
    }

    var isFromCurrentUser: Bool {
        @Persistent(.currentUserID) var currentUserID: String?
        return fromAccountID == currentUserID
    }

    var isMock: Bool { id == UserContentConstants.newMessageID }

    var isPlayingMessage: Bool {
        @Dependency(\.chatPageViewService.audioMessagePlayback?.playingMessage) var playingMessage: Message?
        guard hasAudioComponent,
              audioComponent != nil,
              let playingMessage else { return false }
        return playingMessage.id == id
    }
}
