//
//  AlternateMessageService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 08/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

/// The service that manages messages displaying alternate content, such as original text or audio
/// transcriptions.
///
/// ``AlternateMessageService`` tracks which messages currently show alternate content in place of
/// their default content, and toggles that state per message. It also supplies the font used to
/// render text message cells.
@MainActor
final class AlternateMessageService {
    // MARK: - Types

    /// The kinds of alternate content a message can display.
    enum AlternateMessageType {
        /// The message's original, untranslated text.
        case alternateText

        /// The transcription of the message's audio.
        case audioTranscription
    }

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var alternateTextMessageIDs = [String]()
    private var audioTranscriptionMessageIDs = [String]()

    // MARK: - Computed Properties

    /// The font used to render text message cells, derived from a currently visible text message.
    ///
    /// Falls back to the system font when no suitable visible cell is available.
    var textCellLabelFont: UIFont {
        getTextCellLabelFont()
    }

    // MARK: - Init

    /// Creates the service, binding it to the given chat page view controller.
    ///
    /// - Parameter viewController: The chat page's messages view controller.
    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Is Displaying

    /// Returns a Boolean value that indicates whether the given message currently displays its
    /// alternate text.
    ///
    /// - Parameter message: The message to query.
    ///
    /// - Returns: `true` if the message displays its alternate text; otherwise, `false`.
    func isDisplayingAlternateText(for message: Message) -> Bool {
        alternateTextMessageIDs.contains(message.id)
    }

    /// Returns a Boolean value that indicates whether the given message currently displays its
    /// audio transcription.
    ///
    /// - Parameter message: The message to query.
    ///
    /// - Returns: `true` if the message displays its audio transcription; otherwise, `false`.
    func isDisplayingAudioTranscription(for message: Message) -> Bool {
        audioTranscriptionMessageIDs.contains(message.id)
    }

    // MARK: - Restore All

    /// Restores every message displaying alternate text to its default content.
    func restoreAllAlternateTextMessageIDs() {
        alternateTextMessageIDs = []
    }

    /// Restores every message displaying an audio transcription to its default content.
    func restoreAllAudioTranscriptionMessageIDs() {
        audioTranscriptionMessageIDs = []
    }

    // MARK: - Toggle

    /// Toggles the given kind of alternate content for the message in the given cell, then
    /// reloads the cell.
    ///
    /// - Parameters:
    ///   - type: The kind of alternate content to toggle.
    ///   - cell: The cell whose message to toggle.
    func toggle(
        _ type: AlternateMessageType,
        for cell: MessageContentCell
    ) {
        @Dependency(\.commonServices.analytics) var analytics: AnalyticsService
        @Dependency(\.chatPageViewService) var chatPageViewService: ChatPageViewService

        guard let indexPath = viewController.messagesCollectionView.indexPath(for: cell),
              let message = viewController.displayedMessages.itemAt(indexPath.section) else { return }

        func append() {
            analytics.logEvent(.viewAlternate)

            switch type {
            case .alternateText:
                alternateTextMessageIDs.append(message.id)

            case .audioTranscription:
                audioTranscriptionMessageIDs.append(message.id)
            }
        }

        func remove() {
            switch type {
            case .alternateText:
                alternateTextMessageIDs.removeAll(where: { $0 == message.id })

            case .audioTranscription:
                audioTranscriptionMessageIDs.removeAll(where: { $0 == message.id })
            }
        }

        defer {
            Task { @MainActor in
                chatPageViewService.reloadItemsWhenSafe(
                    at: [indexPath],
                    animated: false
                )
            }
        }

        switch type {
        case .alternateText:
            guard !alternateTextMessageIDs.contains(message.id) else {
                remove()
                return
            }

        case .audioTranscription:
            guard !audioTranscriptionMessageIDs.contains(message.id) else {
                remove()
                return
            }
        }

        append()
    }

    // MARK: - Auxiliary

    private func getTextCellLabelFont() -> UIFont {
        typealias Floats = AppConstants.CGFloats.UserContentExtensions.NSAttributedString

        let visibleTextMessageCells = viewController
            .messagesCollectionView
            .visibleCells
            .compactMap { $0 as? TextMessageCell }

        var modelCell: TextMessageCell?
        for textMessageCell in visibleTextMessageCells where !textMessageCell.messageLabel.font.isItalicized {
            guard let indexPath = viewController
                .messagesCollectionView
                .indexPath(for: textMessageCell),
                let message = viewController
                .displayedMessages
                .itemAt(indexPath.section),
                message.contentType == .text,
                !isDisplayingAlternateText(for: message),
                !isDisplayingAudioTranscription(for: message) else { continue }
            modelCell = textMessageCell
        }

        guard let modelCell else { return .systemFont(ofSize: Floats.messageCellStringSystemFontSize) }
        return modelCell.messageLabel.font
    }
}

private extension UIFont {
    var isItalicized: Bool {
        fontDescriptor.symbolicTraits.contains(.traitItalic)
    }
}
