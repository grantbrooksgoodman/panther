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

final class AlternateMessageService {
    // MARK: - Types

    enum AlternateMessageType {
        case alternateText
        case audioTranscription
    }

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var alternateTextMessageIDs = [String]()
    private var audioTranscriptionMessageIDs = [String]()

    // MARK: - Computed Properties

    var textCellLabelFont: UIFont { getTextCellLabelFont() }

    // MARK: - Init

    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Is Displaying

    func isDisplayingAlternateText(for message: Message) -> Bool {
        alternateTextMessageIDs.contains(message.id)
    }

    func isDisplayingAudioTranscription(for message: Message) -> Bool {
        audioTranscriptionMessageIDs.contains(message.id)
    }

    // MARK: - Restore All

    func restoreAllAlternateTextMessageIDs() {
        alternateTextMessageIDs = []
    }

    func restoreAllAudioTranscriptionMessageIDs() {
        audioTranscriptionMessageIDs = []
    }

    // MARK: - Toggle

    func toggle(_ type: AlternateMessageType, for cell: MessageContentCell) {
        @Dependency(\.commonServices.analytics) var analytics: AnalyticsService
        @Dependency(\.chatPageViewService) var chatPageViewService: ChatPageViewService

        guard let indexPath = viewController.messagesCollectionView.indexPath(for: cell),
              let message = viewController.currentConversation?.messages?.itemAt(indexPath.section) else { return }

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

        defer { chatPageViewService.reloadItemsWhenSafe(at: [indexPath]) }

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
            guard let indexPath = viewController.messagesCollectionView.indexPath(for: textMessageCell),
                  let message = viewController.currentConversation?.messages?.itemAt(indexPath.section),
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
    var isItalicized: Bool { fontDescriptor.symbolicTraits.contains(.traitItalic) }
}
