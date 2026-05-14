//
//  ContextMenuActionHandlerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/11/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import AVFAudio
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Translator

/* 3rd-party */
import MessageKit

@MainActor
final class ContextMenuActionHandlerService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.ContextMenu
    private typealias Strings = AppConstants.Strings.ChatPageViewService.ContextMenu

    // MARK: - Dependencies

    @Dependency(\.avSpeechSynthesizer) private var avSpeechSynthesizer: AVSpeechSynthesizer
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.coreKit.hud) private var coreHUD: CoreKit.HUD
    @Dependency(\.clientSession.user.currentUser) private var currentUser: User?
    @Dependency(\.languageRecognitionService) private var languageRecognitionService: LanguageRecognitionService
    @Dependency(\.alertKitConfig.reportDelegate) private var reportDelegate: AlertKit.ReportDelegate?
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiPasteboard) private var uiPasteboard: UIPasteboard

    // MARK: - Properties

    private(set) var speakingMessage: Message?

    private let viewController: ChatPageViewController

    @Persistent(.retranslatedMessageIDs) private var retranslatedMessageIDs: [String: Set<TranslationPlatform>]?

    // MARK: - Computed Properties

    var speakingCell: MessageContentCell? {
        viewController.messagesCollectionView.visibleCells.first(where: {
            guard let indexPath = viewController.messagesCollectionView.indexPath(for: $0),
                  let message = viewController.currentConversation?.messages?.itemAt(indexPath.section),
                  message.isSpeakingMessage else { return false }
            return true
        }) as? MessageContentCell
    }

    private var selectedCell: UICollectionViewCell? {
        guard let selectedCellIndexPath else { return nil }
        return viewController.messagesCollectionView.cellForItem(at: selectedCellIndexPath)
    }

    private var selectedCellIndexPath: IndexPath? {
        guard let selectedMessageID = chatPageViewService.contextMenu?.interaction.selectedMessageID,
              let messageIndex = viewController.currentConversation?.messages?.firstIndex(where: { $0.id == selectedMessageID }) else { return nil }
        return .init(item: 0, section: messageIndex)
    }

    private var selectedMessage: Message? {
        guard let selectedMessageID = chatPageViewService.contextMenu?.interaction.selectedMessageID else { return nil }
        return viewController.currentConversation?.messages?.first(where: { $0.id == selectedMessageID })
    }

    // MARK: - Init

    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Menu for Message

    func menuForMessage(_ message: Message) -> Menu? {
        guard !message.isConsentMessage else { return nil }
        var actions: [MenuElement] = message.reactions == nil ? [] : [
            .init(
                title: Localized(.reactionDetails).wrappedValue,
                image: .init(systemName: Strings.reactionDetailsActionImageSystemName),
                identifier: .init(Strings.reactionDetailsActionIdentifierRawValue),
                handler: handleAction(_:)
            ),
        ]

        if message.contentType.isMedia {
            actions.append(
                .init(
                    title: Localized(.saveFile).wrappedValue,
                    image: .init(systemName: Strings.saveActionImageSystemName),
                    identifier: .init(Strings.saveActionIdentifierRawValue),
                    handler: handleAction(_:)
                )
            )

            return .init(children: actions)
        }

        guard !message.contentType.isAudio else { return .init(children: actions + getAudioMessageActions(for: message)) }

        actions.append(contentsOf: getTextMessageMenuActions(for: message))
        return .init(children: actions)
    }

    // MARK: - Reset Speaking Message

    func resetSpeakingMessage() {
        speakingMessage = nil
    }

    // MARK: - Action Handlers

    private func handleAudioMessageAction() {
        chatPageViewService.contextMenu?.dismissMenu()
        guard let selectedCell = selectedCell as? MessageContentCell else { return }
        chatPageViewService.alternateMessage?.toggle(.audioTranscription, for: selectedCell)
    }

    private func handleCopyAction() {
        chatPageViewService.contextMenu?.dismissMenu()
        guard let selectedCell = selectedCell as? TextMessageCell else { return }
        uiPasteboard.string = selectedCell.messageLabel.text
    }

    private func handleReactionDetailsAction() {
        chatPageViewService.contextMenu?.dismissMenu()
        Task { @MainActor in
            RootSheets.present(.reactionDetailsPageView)
        }
    }

    private func handleReportMistranslationAction() {
        chatPageViewService.contextMenu?.dismissMenu()

        guard let selectedMessage,
              let translation = selectedMessage.translation,
              let attemptedPlatforms = retranslatedMessageIDs?[selectedMessage.id],
              let reportDelegate else { return }

        let exception = Exception(
            "A mistranslation has been reported (\(translation.reference.hostingKey.shortCode)).",
            userInfo: [
                "AttempedPlatforms": attemptedPlatforms.description,
                "Descriptor": "A mistranslation has been reported.",
                "HostedOverrideErrorCode": "CA45",
                "ReferenceHostingKey": translation.reference.hostingKey,
            ],
            metadata: .init(sender: self)
        )

        reportDelegate.fileReport(exception)
    }

    private func handleRetryTranslationAction() {
        chatPageViewService.contextMenu?.dismissMenu()
        guard let selectedCellIndexPath,
              let selectedMessage else { return }

        Task { @MainActor in
            if let exception = await services.messageRetranslation.retranslateMessageInCurrentConversation(
                selectedMessage,
                indexPath: selectedCellIndexPath
            ) {
                Logger.log(exception, with: .toast)
            }
        }
    }

    private func handleSaveAction() {
        if let image = selectedMessage?.imageComponent?.image(.full) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            coreHUD.showSuccess()
        } else if let videoPathString = selectedMessage?.videoComponent?.localPathURL.path() {
            UISaveVideoAtPathToSavedPhotosAlbum(videoPathString, nil, nil, nil)
            coreHUD.showSuccess()
        } else if let documentPathURL = selectedMessage?.documentComponent?.localPathURL {
            let exception = services.documentExport.presentExportController(forFileAt: documentPathURL)
            services.documentExport.onDismiss { cancelled in
                guard !cancelled else { return }
                guard let exception else { return self.coreHUD.showSuccess() }
                Logger.log(exception, with: .toast)
            }
        }
    }

    private func handleSpeakAction() {
        services.audio.activateAudioSession()
        chatPageViewService.contextMenu?.dismissMenu()
        Task { @MainActor in
            func processed(_ string: String?) -> String {
                string?.lowercasedTrimmingWhitespaceAndNewlines.sanitized ?? ""
            }

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
            let languagePair = selectedMessage.translation?.languagePair ?? .system
            let currentUserUtteranceLanguageCode = isDisplayingAlternateText ? languagePair.to : languagePair.from
            let notCurrentUserUtteranceLanguageCode = isDisplayingAlternateText ? languagePair.from : languagePair.to

            var utteranceLanguageCode = selectedMessage.isFromCurrentUser ? currentUserUtteranceLanguageCode : notCurrentUserUtteranceLanguageCode
            if await languageRecognitionService.matchConfidence(
                for: messageLabelText,
                inLanguage: utteranceLanguageCode
            ) <= .init(Floats.languageRecognitionMatchConfidenceThreshold),
                await languageRecognitionService.matchConfidence(
                    for: messageLabelText,
                    inLanguage: notCurrentUserUtteranceLanguageCode
                ) >= .init(Floats.languageRecognitionMatchConfidenceThreshold),
                processed(selectedMessage.translation?.input.value) == processed(selectedMessage.translation?.output) {
                utteranceLanguageCode = [
                    currentUserUtteranceLanguageCode,
                    notCurrentUserUtteranceLanguageCode,
                ].first(where: { $0 != utteranceLanguageCode }) ?? utteranceLanguageCode
            }

            let utterance: AVSpeechUtterance = .init(string: messageLabelText)
            utterance.voice = services.audio.textToSpeech.highestQualityVoice(utteranceLanguageCode, mustIncludeAudioFileSettings: true)

            speakingMessage = selectedMessage
            avSpeechSynthesizer.speak(utterance)
        }
    }

    private func handleViewAlternateAction() {
        chatPageViewService.contextMenu?.dismissMenu()
        guard let selectedCell = selectedCell as? MessageContentCell else { return }
        chatPageViewService.alternateMessage?.toggle(.alternateText, for: selectedCell)
    }

    // MARK: - Auxiliary

    private func getAudioMessageActions(for message: Message) -> [MenuElement] {
        var actions = [MenuElement]()

        let isDisplayingAudioTranscription = chatPageViewService.alternateMessage?.isDisplayingAudioTranscription(for: message) ?? false
        let actionTitle = Localized(isDisplayingAudioTranscription ? .viewAsAudio : .viewTranscription).wrappedValue

        if isDisplayingAudioTranscription {
            actions.append(
                .init(
                    title: Localized(.copy).wrappedValue,
                    image: .init(systemName: Strings.copyActionImageSystemName),
                    identifier: .init(rawValue: Strings.copyActionIdentifierRawValue),
                    handler: handleAction(_:)
                )
            )
        }

        if avSpeechSynthesizer.isSpeaking || (isDisplayingAudioTranscription && message.isFromCurrentUser) {
            actions.append(
                .init(
                    title: Localized(avSpeechSynthesizer.isSpeaking ? .stopSpeaking : .speak).wrappedValue,
                    image: .init(systemName: Strings.speakActionImageSystemName),
                    identifier: .init(rawValue: Strings.speakActionIdentifierRawValue),
                    handler: handleAction(_:)
                )
            )
        }

        let audioMessageActionImage = UIImage(
            systemName: isDisplayingAudioTranscription ? Strings.audioMessageActionImageSystemName : Strings.audioMessageActionAlternateImageSystemName
        )

        actions.append(
            .init(
                title: actionTitle,
                image: audioMessageActionImage,
                identifier: .init(rawValue: Strings.audioMessageActionIdentifierRawValue),
                handler: handleAction(_:)
            )
        )

        return actions
    }

    private func getViewAlternateAction(for message: Message) -> MenuElement? {
        guard viewController.currentConversation?.participants.count == 2 || !message.isFromCurrentUser,
              message.translation?.languagePair.isIdempotent == false,
              message.translation?.input.value.sanitized.containsLetters == true,
              let languageCode = message.isFromCurrentUser ? message.translation?.languagePair.to : message.translation?.languagePair.from,
              languageCode != currentUser?.languageCode,
              !avSpeechSynthesizer.isSpeaking else { return nil }

        let isDisplayingAlternateText = chatPageViewService.alternateMessage?.isDisplayingAlternateText(for: message) ?? false
        let actionTitle = Localized( // swiftlint:disable:next line_length
            message.isFromCurrentUser ? (isDisplayingAlternateText ? .viewOriginal : .viewTranslation) : (isDisplayingAlternateText ? .viewTranslation : .viewOriginal)
        ).wrappedValue

        return .init(
            title: actionTitle,
            image: .init(resource: .viewAlternate),
            identifier: .init(rawValue: Strings.viewAlterateActionIdentifierRawValue),
            handler: handleAction(_:)
        )
    }

    private func handleAction(_ action: MenuElement) {
        guard let identifier = action.identifier else { return }
        switch identifier.rawValue {
        case Strings.audioMessageActionIdentifierRawValue: handleAudioMessageAction()
        case Strings.copyActionIdentifierRawValue: handleCopyAction()
        case Strings.reactionDetailsActionIdentifierRawValue: handleReactionDetailsAction()
        case Strings.reportMistranslationActionIdentifierRawValue: handleReportMistranslationAction()
        case Strings.retryTranslationActionIdentifierRawValue: handleRetryTranslationAction()
        case Strings.saveActionIdentifierRawValue: handleSaveAction()
        case Strings.speakActionIdentifierRawValue: handleSpeakAction()
        case Strings.viewAlterateActionIdentifierRawValue: handleViewAlternateAction()
        default: ()
        }
    }

    private func getTextMessageMenuActions(for message: Message) -> [MenuElement] {
        let speakActionImage = UIImage(
            systemName: avSpeechSynthesizer.isSpeaking ? Strings.speakActionAlternateImageSystemName : Strings.speakActionImageSystemName
        )

        var actions: [MenuElement] = [
            .init(
                title: Localized(.copy).wrappedValue,
                image: .init(systemName: Strings.copyActionImageSystemName),
                identifier: .init(rawValue: Strings.copyActionIdentifierRawValue),
                handler: handleAction(_:)
            ),
            .init(
                title: Localized(avSpeechSynthesizer.isSpeaking ? .stopSpeaking : .speak).wrappedValue,
                image: speakActionImage,
                identifier: .init(rawValue: Strings.speakActionIdentifierRawValue),
                handler: handleAction(_:)
            ),
        ]

        let translation = message.translation
        let containsLetters = translation?.input.value.containsLetters == true || translation?.output.sanitized.containsLetters == true
        let isDisplayingAlternate = chatPageViewService
            .alternateMessage?
            .isDisplayingAlternateText(for: message) == true

        guard !avSpeechSynthesizer.isSpeaking,
              containsLetters == true,
              let translationCode = translation?.reference.hostingKey.shortCode else { return actions }

        let exceptionCode = Exception(
            "A mistranslation has been reported (\(translationCode)).",
            metadata: .init(sender: self)
        ).code

        if retranslatedMessageIDs?.hasTriedAllTranslationPlatforms(for: message.id) != true,
           translation?.languagePair.isIdempotent == false,
           (message.isFromCurrentUser && isDisplayingAlternate) ||
           (!message.isFromCurrentUser && !isDisplayingAlternate) {
            actions.append(.init(
                title: Localized(.retryTranslation).wrappedValue,
                image: .init(systemName: Strings.retryTranslationActionImageSystemName),
                identifier: .init(rawValue: Strings.retryTranslationActionIdentifierRawValue),
                handler: handleAction(_:)
            ))
        } else if retranslatedMessageIDs?.hasTriedAllTranslationPlatforms(for: message.id) == true,
                  (reportDelegate as? ErrorReportingService)?
                  .reportedErrorCodes
                  .contains(
                      exceptionCode
                  ) != true {
            actions.append(.init(
                title: Localized(.reportMistranslation).wrappedValue,
                image: .init(systemName: Strings.reportMistranslationActionImageSystemName),
                identifier: .init(rawValue: Strings.reportMistranslationActionIdentifierRawValue),
                handler: handleAction(_:)
            ))
        }

        if let viewAlternateAction = getViewAlternateAction(for: message) {
            actions.append(viewAlternateAction)
        }

        return actions
    }
}

private extension [String: Set<TranslationPlatform>] {
    func hasTriedAllTranslationPlatforms(for messageID: String) -> Bool {
        self[messageID] == Set(TranslationPlatform.allCases)
    }
}

// swiftlint:enable file_length type_body_length
