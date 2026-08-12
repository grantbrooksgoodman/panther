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

extension Message: @preconcurrency MessageType {
    // MARK: - Types

    /// A message sender, identified for display in the message list.
    struct Sender: SenderType {
        /// The sender's display name.
        let displayName: String

        /// The sender's unique identifier.
        let senderId: String
    }

    // MARK: - Properties

    /// The message's content, as represented for display in the message list.
    ///
    /// Maps the message to text, attributed text, audio, photo, or video based on its content
    /// type and the alternate content it currently displays.
    @MainActor
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

    /// The message's unique identifier.
    var messageId: String {
        id
    }

    /// The message's sender.
    var sender: SenderType {
        Sender(displayName: "", senderId: fromAccountID)
    }
}

// swiftformat:enable acronyms

extension Message {
    // MARK: - Properties

    /// The identifier of the conversation's message receipt consent request message, if known.
    static var consentRequestMessageID: String? {
        get { _consentRequestMessageIDCache.wrappedValue }
        set { _consentRequestMessageIDCache.wrappedValue = newValue }
    }

    /// The attributed string for a system message, combining its date separator and activity
    /// text, or `nil` if the message is not a system message.
    @MainActor
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

    /// The message bubble's background color, distinguishing sent from received messages.
    @MainActor
    var backgroundColor: UIColor {
        isFromCurrentUser ? .senderBubble : .receiverBubble
    }

    /// A Boolean value that indicates whether this message acknowledges a message receipt consent
    /// request.
    var isConsentAcknowledgementMessage: Bool {
        guard let translation else { return false }
        return translation.input.value == Localized(
            .messageRecipientConsentAcknowledgementMessage,
            languageCode: translation.languagePair.from
        ).wrappedValue
    }

    /// A Boolean value that indicates whether this message is a message receipt consent request
    /// or acknowledgement.
    var isConsentMessage: Bool {
        isConsentAcknowledgementMessage || isConsentRequestMessage
    }

    /// A Boolean value that indicates whether this message requests message receipt consent.
    var isConsentRequestMessage: Bool {
        if let consentRequestMessageID = Message.consentRequestMessageID { return id == consentRequestMessageID }
        @Dependency(\.clientSession.entity.conversation.currentConversation) var currentConversation: Conversation?

        guard let translation else { return false }
        let inputMatches = translation.input.value == Localized(
            .messageRecipientConsentRequestMessage,
            languageCode: translation.languagePair.from
        ).wrappedValue

        guard let currentConversation else { return inputMatches }
        let firstMessageID = currentConversation
            .messages?
            .first?
            .id ??
            currentConversation
            .messageIDs
            .first
        let isConsentMessage = inputMatches && (id == CommonConstants.newMessageID || id == firstMessageID)
        Message.consentRequestMessageID = (isConsentMessage && id != CommonConstants.newMessageID) ? id : Message.consentRequestMessageID

        return isConsentMessage
    }

    /// A Boolean value that indicates whether the message was sent by the current user.
    var isFromCurrentUser: Bool {
        fromAccountID == User.currentUserID
    }

    /// A Boolean value that indicates whether the message is an outbox message whose delivery
    /// failed.
    var isFailedOutboxMessage: Bool {
        guard isOutboxMessage else { return false }
        @Dependency(\.clientSession.outbox) var outbox: MessageOutboxService
        return outbox.entry(forID: id)?.state == .failed
    }

    /// A Boolean value that indicates whether the message is a mock, representing a message not
    /// yet sent.
    var isMock: Bool {
        id == CommonConstants.newMessageID
    }

    /// A Boolean value that indicates whether the message is staged in the outbox awaiting
    /// delivery.
    var isOutboxMessage: Bool {
        id.hasPrefix("outbox-")
    }

    /// A Boolean value that indicates whether this message's audio is currently playing.
    @MainActor
    var isPlayingMessage: Bool {
        @Dependency(\.chatPageViewService.audioMessagePlayback?.playingMessage) var playingMessage: Message?
        guard contentType.isAudio,
              audioComponent != nil,
              let playingMessage else { return false }
        return playingMessage.id == id
    }

    /// A Boolean value that indicates whether this message is currently being spoken aloud.
    @MainActor
    var isSpeakingMessage: Bool {
        @Dependency(\.chatPageViewService.contextMenu?.actionHandler.speakingMessage) var speakingMessage: Message?
        guard let speakingMessage else { return false }
        return speakingMessage.id == id
    }

    /// A Boolean value that indicates whether the message is a system message, such as a
    /// conversation activity notice.
    var isSystemMessage: Bool {
        fromAccountID == CommonConstants.systemMessageID
    }

    /// A copy of this system message hydrated with its localized activity text, or the message
    /// itself if it is not a system message.
    @MainActor
    var systemLocalized: Message {
        @Dependency(\.clientSession.entity.conversation.currentConversation) var conversation: Conversation?
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

    private static let _consentRequestMessageIDCache = LockIsolated<String?>(nil)

    // MARK: - Methods

    /// Returns a Boolean value that indicates whether the message's text contains the given
    /// search term, ignoring case and surrounding whitespace.
    ///
    /// - Parameter searchTerm: The term to search for.
    ///
    /// - Returns: `true` if the message's text contains the term; otherwise, `false`.
    func textContains(_ searchTerm: String) -> Bool {
        guard let translation else { return false }
        let searchTerm = searchTerm.lowercasedTrimmingWhitespaceAndNewlines
        let comparator = isFromCurrentUser ? translation.input.value : translation.output.sanitized
        return comparator.lowercasedTrimmingWhitespaceAndNewlines.contains(searchTerm)
    }
}
