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

    struct Sender: SenderType {
        let displayName: String
        let senderId: String
    }

    // MARK: - Properties

    var kind: MessageKind {
        @Dependency(\.chatPageViewService.alternateMessage) var alternateMessageService: AlternateMessageService?

        guard !isSystemMessage else { return .custom(nil) }
        typealias Colors = AppConstants.Colors.UserContentExtensions.Message

        // swiftlint:disable:next line_length
        let nonCurrentUserForegroundColor = !Application.isInPrevaricationMode && ThemeService.isDarkModeActive ? Colors.kindAttributedTextDarkForeground : Colors.kindAttributedTextLightForeground
        let attributedStringForegroundColor = UIColor(isFromCurrentUser ? Colors.kindAttributedTextCurrentUserForeground : nonCurrentUserForegroundColor)

        switch contentType {
        case .audio:
            if let audioComponent,
               let translation {
                guard alternateMessageService?.isDisplayingAudioTranscription(for: self) ?? false else {
                    return .audio(isFromCurrentUser ? audioComponent.original : audioComponent.translated)
                }

                return .attributedText(
                    .messageCellString(
                        isFromCurrentUser ? translation.input.value.sanitized : translation.output.sanitized,
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
        let primaryText = isFromCurrentUser ? translation.input.value : translation.output
        let alternateText = isFromCurrentUser ? translation.output : translation.input.value

        let consentAcknowledgementMessage = Localized(.messageRecipientConsentAcknowledgementMessage).wrappedValue
        let consentRequestMessage = Localized(.messageRecipientConsentRequestMessage).wrappedValue

        let resolvedText = isConsentMessage ? (
            isConsentAcknowledgementMessage ? consentAcknowledgementMessage : consentRequestMessage
        ).sanitized.trimmingBorderedWhitespace : (isDisplayingAlternateText ? alternateText : primaryText)

        return .attributedText(
            .messageCellString(
                resolvedText.sanitized,
                foregroundColor: attributedStringForegroundColor,
                italicized: isConsentMessage || isDisplayingAlternateText
            )
        )
    }

    var messageId: String { id }
    var sender: SenderType { Sender(displayName: "", senderId: fromAccountID) }
}

// swiftformat:enable acronyms

extension Message {
    // MARK: - Properties

    var attributedSystemString: NSAttributedString? {
        typealias Colors = AppConstants.Colors.SystemMessageCell
        typealias Floats = AppConstants.CGFloats.SystemMessageCell

        guard isSystemMessage,
              let text = systemLocalized.translation?.output,
              let dateString = sentDate.chatPageMessageSeparatorAttributedDateString else { return nil }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = Floats.labelParagraphStyleLineSpacing

        let mutableDateString = NSMutableAttributedString(attributedString: dateString)
        mutableDateString.addAttributes(
            [.paragraphStyle: paragraphStyle],
            range: .init(
                location: 0,
                length: mutableDateString.length
            )
        )

        let activityString = text.sanitized.attributed(.init(
            [
                .font: UIFont.systemFont(ofSize: Floats.activityStringSystemFontSize),
                .foregroundColor: Colors.activityStringForeground,
            ],
            secondaryAttributes: [.init(
                [
                    .font: UIFont.boldSystemFont(ofSize: Floats.activityStringSystemFontSize),
                    .foregroundColor: Colors.activityStringForeground,
                ],
                stringRanges: text.matches(of: /⌘(.*?)⌘/).map { String($0.1) }
            )]
        ))

        let combinedString = NSMutableAttributedString(attributedString: mutableDateString)
        combinedString.append(NSAttributedString(string: "\n"))
        combinedString.append(activityString)

        return combinedString
    }

    var backgroundColor: UIColor { isFromCurrentUser ? .senderBubble : .receiverBubble }

    static var consentRequestMessageID: String?

    var isConsentAcknowledgementMessage: Bool {
        guard let translation else { return false }
        return translation.input.value == Localized(
            .messageRecipientConsentAcknowledgementMessage,
            languageCode: translation.languagePair.from
        ).wrappedValue
    }

    var isConsentMessage: Bool { isConsentAcknowledgementMessage || isConsentRequestMessage }

    var isConsentRequestMessage: Bool {
        if let consentRequestMessageID = Message.consentRequestMessageID { return id == consentRequestMessageID }
        @Dependency(\.clientSession.conversation.fullConversation) var fullConversation: Conversation?

        guard let translation else { return false }
        let inputMatches = translation.input.value == Localized(
            .messageRecipientConsentRequestMessage,
            languageCode: translation.languagePair.from
        ).wrappedValue

        guard let fullConversation else { return inputMatches }
        let firstMessageID = fullConversation
            .messages?
            .filteringSystemMessages
            .first?
            .id ??
            fullConversation
            .messageIDs
            .first
        let isConsentMessage = inputMatches && (id == CommonConstants.newMessageID || id == firstMessageID)
        Message.consentRequestMessageID = (isConsentMessage && id != CommonConstants.newMessageID) ? id : Message.consentRequestMessageID
        return isConsentMessage
    }

    var isFromCurrentUser: Bool { fromAccountID == User.currentUserID }

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

    var isSystemMessage: Bool {
        fromAccountID == CommonConstants.systemMessageID
    }

    /// - Returns: The provided system message, hydrated with localized strings.
    var systemLocalized: Message {
        @Dependency(\.clientSession.conversation.fullConversation) var conversation: Conversation?
        guard isSystemMessage,
              let activity = conversation?
              .activities?
              .first(where: { id == $0.encodedHash }) else { return self }
        return .init(
            activity.encodedHash,
            fromAccountID: CommonConstants.systemMessageID,
            contentType: .text,
            richContent: nil,
            translationReferences: [.init(
                languagePair: .system,
                type: .idempotent(activity.encodedHash)
            )],
            translations: [
                .init(
                    input: .init(activity.description),
                    output: activity.description,
                    languagePair: .system
                ),
            ],
            readReceipts: nil,
            sentDate: activity.date
        )
    }

    // MARK: - Methods

    func textContains(_ searchTerm: String) -> Bool {
        guard let translation else { return false }
        let searchTerm = searchTerm.lowercasedTrimmingWhitespaceAndNewlines
        let comparator = isFromCurrentUser ? translation.input.value : translation.output.sanitized
        return comparator.lowercasedTrimmingWhitespaceAndNewlines.contains(searchTerm)
    }
}
