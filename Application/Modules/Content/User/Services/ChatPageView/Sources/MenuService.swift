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

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.Menu
    private typealias Strings = AppConstants.Strings.ChatPageViewService.Menu

    // MARK: - Dependencies

    @Dependency(\.avSpeechSynthesizer) private var avSpeechSynthesizer: AVSpeechSynthesizer
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession.user.currentUser) private var currentUser: User?
    @Dependency(\.networking.services.translation.languageRecognition) private var languageRecognitionService: LanguageRecognitionService
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiPasteboard) private var uiPasteboard: UIPasteboard

    // MARK: - Properties

    public private(set) var isShowingMenu = false
    public private(set) var speakingCell: MessageContentCell?
    public private(set) var speakingMessage: Message?

    private let menuInteraction: UIEditMenuInteraction
    private let viewController: ChatPageViewController

    private var selectedCell: MessageContentCell?

    // MARK: - Computed Properties

    private var selectedMessage: Message? {
        guard let selectedCell,
              let indexPath = viewController.messagesCollectionView.indexPath(for: selectedCell) else { return nil }
        return viewController.currentConversation?.messages?.itemAt(indexPath.section)
    }

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
        menuInteraction = .init(delegate: viewController)
    }

    // MARK: - Reset Speaking Cell

    public func resetSpeakingCell() {
        speakingCell = nil
        speakingMessage = nil
    }

    // MARK: - Set Is Showing Menu

    public func setIsShowingMenu(_ isShowingMenu: Bool, at index: Int) {
        self.isShowingMenu = isShowingMenu

        guard !isShowingMenu else { return }
        animateDeselection(forCellAt: index)
    }

    // MARK: - Set Speaking Cell

    public func setSpeakingCell(_ speakingCell: MessageContentCell) {
        self.speakingCell = speakingCell
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
        guard let message = viewController.currentConversation?.messages?.itemAt(index) else { return nil }

        var actions = [UIAction]()
        guard !message.hasAudioComponent else {
            let isDisplayingAudioTranscription = chatPageViewService.alternateMessage?.isDisplayingAudioTranscription(for: message) ?? false
            let actionTitle = Localized(isDisplayingAudioTranscription ? .viewAsAudio : .viewTranscription).wrappedValue

            if isDisplayingAudioTranscription {
                actions.append(
                    .init(
                        title: Localized(.copy).wrappedValue,
                        identifier: .init(rawValue: Strings.copyActionIdentifierRawValue),
                        handler: handleAction(_:)
                    )
                )
            }

            if avSpeechSynthesizer.isSpeaking || (isDisplayingAudioTranscription && message.isFromCurrentUser) {
                actions.append(
                    .init(
                        title: Localized(avSpeechSynthesizer.isSpeaking ? .stopSpeaking : .speak).wrappedValue,
                        identifier: .init(rawValue: Strings.speakActionIdentifierRawValue),
                        handler: handleAction(_:)
                    )
                )
            }

            actions.append(
                .init(
                    title: actionTitle,
                    identifier: .init(rawValue: Strings.audioMessageActionIdentifierRawValue),
                    handler: handleAction(_:)
                )
            )

            return .init(children: actions)
        }

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

        guard viewController.currentConversation?.participants.count == 2 || !message.isFromCurrentUser,
              message.translation.input.value().sanitized.rangeOfCharacter(from: .letters) != nil,
              let otherUser = viewController.currentConversation?.users?.first,
              otherUser.languageCode != currentUser?.languageCode,
              !avSpeechSynthesizer.isSpeaking else { return .init(children: actions) }

        let isDisplayingAlternateText = chatPageViewService.alternateMessage?.isDisplayingAlternateText(for: message) ?? false
        let actionTitle = Localized( // swiftlint:disable:next line_length
            message.isFromCurrentUser ? (isDisplayingAlternateText ? .viewOriginal : .viewTranslation) : (isDisplayingAlternateText ? .viewTranslation : .viewOriginal)
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

    private func handleAudioMessageAction() {
        guard let selectedCell else { return }
        chatPageViewService.alternateMessage?.toggle(.audioTranscription, for: selectedCell)
    }

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

        let isDisplayingAlternateText = chatPageViewService.alternateMessage?.isDisplayingAlternateText(for: selectedMessage) ?? false
        let languagePair = selectedMessage.translation.languagePair
        let currentUserUtteranceLanguageCode = isDisplayingAlternateText ? languagePair.to : languagePair.from
        let notCurrentUserUtteranceLanguageCode = isDisplayingAlternateText ? languagePair.from : languagePair.to

        var utteranceLanguageCode = selectedMessage.isFromCurrentUser ? currentUserUtteranceLanguageCode : notCurrentUserUtteranceLanguageCode
        if languageRecognitionService.matchConfidence(
            for: messageLabelText,
            inLanguage: utteranceLanguageCode
        ) <= .init(Floats.languageRecognitionMatchConfidenceThreshold) {
            utteranceLanguageCode = [
                currentUserUtteranceLanguageCode,
                notCurrentUserUtteranceLanguageCode,
            ].first(where: { $0 != utteranceLanguageCode }) ?? utteranceLanguageCode
        }

        let utterance: AVSpeechUtterance = .init(string: messageLabelText)
        utterance.voice = services.audio.textToSpeech.highestQualityVoice(utteranceLanguageCode, mustIncludeAudioFileSettings: true)
        services.audio.activateAudioSession()
        avSpeechSynthesizer.speak(utterance)

        speakingCell = selectedCell
        speakingMessage = selectedMessage
    }

    private func handleViewAlternateAction() {
        guard let selectedCell else { return }
        chatPageViewService.alternateMessage?.toggle(.alternateText, for: selectedCell)
    }

    // MARK: - Auxiliary

    private func animateDeselection(forCellAt index: Int) {
        let collectionView = viewController.messagesCollectionView
        guard let cell = collectionView.visibleCells.first(where: { collectionView.indexPath(for: $0)?.section == index }) as? MessageContentCell,
              let message = viewController.currentConversation?.messages?.itemAt(index) else { return }

        UIView.animate(withDuration: Floats.selectionAnimationDuration) {
            cell.messageContainerView.backgroundColor = message.backgroundColor
        }
    }

    private func animateSelectionForSelectedCell() {
        guard let selectedCell else { return }

        let backgroundColor = selectedCell.messageContainerView.backgroundColor
        guard backgroundColor?.resolvedColor(with: .current) == .senderBubble.resolvedColor(with: .current) ||
            backgroundColor == .receiverBubble else { return }

        UIView.animate(withDuration: Floats.selectionAnimationDuration) {
            guard backgroundColor == .receiverBubble,
                  ThemeService.isDarkModeActive else {
                selectedCell.messageContainerView.backgroundColor = backgroundColor?.darker(by: Floats.messageContainerViewBackgroundColorDarkeningPercentage)
                return
            }

            selectedCell.messageContainerView.backgroundColor = backgroundColor?.lighter(by: Floats.messageContainerViewBackgroundColorLighteningPercentage)
        }

        services.haptics.generateFeedback(.selection)
    }

    private func handleAction(_ action: UIAction) {
        dismissMenu()

        switch action.identifier.rawValue {
        case Strings.audioMessageActionIdentifierRawValue:
            handleAudioMessageAction()

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
        guard !isShowingMenu,
              !messageDeliveryService.isSendingMessage,
              !services.audio.recording.isInOrWillTransitionToRecordingState else { return }

        let touchPoint = recognizer.location(in: viewController.messagesCollectionView)

        guard let indexPath = viewController.messagesCollectionView.indexPathForItem(at: touchPoint),
              let selectedCell = viewController.messagesCollectionView.cellForItem(at: indexPath) as? MessageContentCell,
              let message = viewController.currentConversation?.messages?.itemAt(indexPath.section) else { return }

        guard message.id != CommonConstants.newMessageID else { return }

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

        animateSelectionForSelectedCell()
        menuInteraction.presentEditMenu(with: configuration)
    }
}
