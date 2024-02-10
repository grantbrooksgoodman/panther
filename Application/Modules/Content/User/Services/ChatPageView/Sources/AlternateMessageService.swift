//
//  AlternateMessageService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 08/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import MessageKit
import Redux

public final class AlternateMessageService {
    // MARK: - Types

    public enum AlternateMessageType {
        case alternateText
        case audioTranscription
    }

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var alternateTextMessageIDs = [String]()
    private var audioTranscriptionMessageIDs = [String]()

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Is Displaying

    public func isDisplayingAlternateText(for message: Message) -> Bool {
        alternateTextMessageIDs.contains(message.id)
    }

    public func isDisplayingAudioTranscription(for message: Message) -> Bool {
        audioTranscriptionMessageIDs.contains(message.id)
    }

    // MARK: - Restore All

    public func restoreAllAlternateTextMessageIDs() {
        alternateTextMessageIDs = []
    }

    public func restoreAllAudioTranscriptionMessageIDs() {
        audioTranscriptionMessageIDs = []
    }

    // MARK: - Toggle

    public func toggle(_ type: AlternateMessageType, for cell: MessageContentCell) {
        guard let indexPath = viewController.messagesCollectionView.indexPath(for: cell),
              let messages = viewController.currentConversation?.messages,
              messages.count > indexPath.section else { return }
        let message = messages[indexPath.section]

        func append() {
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

        defer { viewController.messagesCollectionView.reloadItems(at: [indexPath]) }

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
}
