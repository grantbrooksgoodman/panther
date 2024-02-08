//
//  MenuService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 07/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFAudio
import Foundation
import UIKit

/* 3rd-party */
import MessageKit
import Redux

public final class MenuService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.MenuService
    private typealias Strings = AppConstants.Strings.MenuService

    // MARK: - Dependencies

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.avSpeechSynthesizer) private var avSpeechSynthesizer: AVSpeechSynthesizer
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.uiPasteboard) private var uiPasteboard: UIPasteboard

    // MARK: - Properties

    public private(set) var isShowingMenu = false

    private let menuInteraction: UIEditMenuInteraction
    private let viewController: ChatPageViewController

    private var selectedCell: MessageContentCell?

    // MARK: - Computed Properties

    private var selectedMessage: Message? {
        guard let selectedCell,
              let indexPath = viewController.messagesCollectionView.indexPath(for: selectedCell),
              let messages = viewController.currentConversation?.messages,
              messages.count > indexPath.section else { return nil }
        return messages[indexPath.section]
    }

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
        menuInteraction = .init(delegate: viewController)
    }

    // MARK: - Set Is Showing Menu

    public func setIsShowingMenu(_ isShowingMenu: Bool) {
        self.isShowingMenu = isShowingMenu
    }

    // MARK: - Configure Menu Gesture Recognizer

    public func configureMenuGestureRecognizer() {
        func addOrEnable(_ gestureRecognizer: UIGestureRecognizer) {
            guard let existingGestureRecognizer = viewController.messagesCollectionView.gestureRecognizers?.first(where: { $0 == gestureRecognizer }) else {
                viewController.messagesCollectionView.addGestureRecognizer(gestureRecognizer)
                return
            }

            existingGestureRecognizer.isEnabled = true
        }

        let longPressGesture: UILongPressGestureRecognizer = .init(target: self, action: #selector(longPressGestureRecognized))
        longPressGesture.delaysTouchesBegan = true
        longPressGesture.minimumPressDuration = Floats.longPressGestureMinimumPressDuration
        addOrEnable(longPressGesture)
    }

    // MARK: - Dismiss Menu

    public func dismissMenu() {
        menuInteraction.dismissMenu()
    }

    // MARK: - Menu for Message

    public func menuForMessage(at index: Int) -> UIMenu? {
        guard let messages = viewController.currentConversation?.messages,
              messages.count > index else { return nil }
        let message = messages[index]

        var actions = [UIAction]()
        guard !message.hasAudioComponent else { return .init(children: actions) }

        actions = [
            .init(
                title: Localized(.copy).wrappedValue,
                identifier: .init(rawValue: Strings.copyActionIdentifierRawValue),
                handler: handleAction(_:)
            ),
            .init(
                title: Localized(avSpeechSynthesizer.isSpeaking ? .stopSpeaking : .speak).wrappedValue,
                identifier: .init(rawValue: Strings.speakActionIdentifierRawValue),
                handler: handleAction(_:)
            ),
        ]

        guard viewController.currentConversation?.participants.count == 2 || !message.isFromCurrentUser else { return .init(children: actions) }

        let isDisplayingAlternate = chatPageViewService.alternateMessage?.isDisplayingAlternate(for: message) ?? false
        let actionTitle = Localized(
            message.isFromCurrentUser ? (isDisplayingAlternate ? .viewOriginal : .viewTranslation) : (isDisplayingAlternate ? .viewTranslation : .viewOriginal)
        ).wrappedValue

        actions.append(
            .init(
                title: actionTitle,
                identifier: .init(rawValue: Strings.viewAlterateActionIdentifierRawValue),
                handler: handleAction(_:)
            )
        )

        return .init(children: actions)
    }

    // MARK: - Action Handlers

    private func handleCopyAction() {
        guard let selectedCell = selectedCell as? TextMessageCell else { return }
        uiPasteboard.string = selectedCell.messageLabel.text
    }

    private func handleSpeakAction() {
        guard let selectedCell = selectedCell as? TextMessageCell,
              let selectedMessage,
              let messageLabelText = selectedCell.messageLabel.text else { return }

        avSpeechSynthesizer.delegate = viewController

        guard !avSpeechSynthesizer.isSpeaking else {
            avSpeechSynthesizer.stopSpeaking(at: .immediate)
            return
        }

        chatPageViewService.audioMessagePlayback?.stopPlayback()

        let utterance: AVSpeechUtterance = .init(string: messageLabelText)
        let languagePair = selectedMessage.translation.languagePair
        let utteranceLanguageCode = selectedMessage.isFromCurrentUser ? languagePair.from : languagePair.to

        utterance.voice = audioService.highestQualityVoice(utteranceLanguageCode)
        avSpeechSynthesizer.speak(utterance)
    }

    private func handleViewAlternateAction() {
        guard let selectedCell else { return }
        chatPageViewService.alternateMessage?.toggleAlternate(for: selectedCell)
    }

    // MARK: - Auxiliary

    private func handleAction(_ action: UIAction) {
        dismissMenu()

        switch action.identifier.rawValue {
        case Strings.copyActionIdentifierRawValue:
            handleCopyAction()

        case Strings.speakActionIdentifierRawValue:
            handleSpeakAction()

        case Strings.viewAlterateActionIdentifierRawValue:
            handleViewAlternateAction()

        default: ()
        }
    }

    @objc
    private func longPressGestureRecognized(recognizer: UILongPressGestureRecognizer) {
        guard !isShowingMenu else { return }

        let touchPoint = recognizer.location(in: viewController.messagesCollectionView)

        guard let indexPath = viewController.messagesCollectionView.indexPathForItem(at: touchPoint),
              let selectedCell = viewController.messagesCollectionView.cellForItem(at: indexPath) as? MessageContentCell else { return }

        let convertedTouchPoint = viewController.messagesCollectionView.convert(touchPoint, to: selectedCell.messageContainerView)
        guard selectedCell.messageContainerView.bounds.contains(convertedTouchPoint),
              let containerSuperview = selectedCell.messageContainerView.superview else { return }

        self.selectedCell = selectedCell
        selectedCell.messageContainerView.addInteraction(menuInteraction)

        let configuration: UIEditMenuConfiguration = .init(
            identifier: indexPath.section,
            sourcePoint: .init(
                x: convertedTouchPoint.x,
                y: containerSuperview.frame.minY
            )
        )

        menuInteraction.presentEditMenu(with: configuration)
    }
}
