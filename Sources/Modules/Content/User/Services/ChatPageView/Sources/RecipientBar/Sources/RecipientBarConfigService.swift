//
//  RecipientBarConfigService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 15/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFAudio
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

@MainActor
final class RecipientBarConfigService {
    // MARK: - Types

    enum ContactViewSpacialConfiguration {
        case furthestTrailing(onSublevel: Int? = nil)
        case onSameLevelAsTextField
    }

    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.RecipientBarService.Config

    // MARK: - Dependencies

    @Dependency(\.avSpeechSynthesizer) private var avSpeechSynthesizer: AVSpeechSynthesizer
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.commonServices.audio.recording) private var recordingService: RecordingService

    // MARK: - Properties

    private let viewController: ChatPageViewController

    // MARK: - Init

    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - First Contact View

    func firstContactView(_ configuration: ContactViewSpacialConfiguration) -> UIView? {
        guard let recipientBarView = chatPageViewService.recipientBar?.layout.recipientBarView else { return nil }
        typealias Strings = AppConstants.Strings.ChatPageViewService.RecipientBarService.ContactSelectionUI
        var subviews = recipientBarView.subviews(for: Strings.contactViewSemanticTag)

        switch configuration {
        case let .furthestTrailing(onSublevel: sublevel):
            if let sublevel { subviews = subviews.filter { $0.frame.maxY == (Floats.initialLevelMaxY + value(for: sublevel)) } }
            return subviews.sorted(by: { $0.frame.maxX > $1.frame.maxX }).first

        case .onSameLevelAsTextField:
            guard let textField = chatPageViewService.recipientBar?.layout.textField else { return nil }
            return subviews
                .filter { $0.center.y == textField.center.y }
                .sorted(by: { $0.frame.maxX > $1.frame.maxX })
                .first
        }
    }

    // MARK: - Reconfigure Collection View

    func reconfigureCollectionView() {
        Task { @MainActor in
            var shouldReload = false

            func setInsetsAndReload() {
                Task { @MainActor [shouldReload] in
                    chatPageViewService.alternateMessage?.restoreAllAlternateTextMessageIDs()
                    chatPageViewService.alternateMessage?.restoreAllAudioTranscriptionMessageIDs()

                    avSpeechSynthesizer.stopSpeaking(at: .immediate)
                    chatPageViewService.audioMessagePlayback?.stopPlayback()

                    await chatPageViewService.recordingUI?.hideRecordingUI()
                    _ = recordingService.cancelRecording()

                    viewController.messagesCollectionView.isHidden = false

                    guard let recipientBarView = chatPageViewService.recipientBar?.layout.recipientBarView,
                          shouldReload else { return }

                    viewController.messagesCollectionView.contentInset.top = recipientBarView.frame.maxY
                    viewController.messagesCollectionView.verticalScrollIndicatorInsets.top = recipientBarView.frame.maxY
                    viewController.messagesCollectionView.reloadData()
                    viewController.messagesCollectionView.scrollToLastItem(animated: false)
                }
            }

            guard let contactSelectionUIService = chatPageViewService.recipientBar?.contactSelectionUI else { return }

            let isPreviousConversationEmpty = (clientSession.conversation.currentConversation ?? .empty).isEmpty
            let previousConversationIDKey = clientSession.conversation.currentConversation?.id.key ?? ""

            let conversations = clientSession.user.currentUser?.conversations?.visibleForCurrentUser.filter { $0.users != nil }
            let users = contactSelectionUIService.selectedContactPairs.users

            // NIT: Observed bugs with this disabled, but iMessage does it this way.
//            viewController.messageInputBar.inputTextView.text = ""
            Task.background { _ = await chatPageViewService.typingIndicator?.textViewDidChange(to: "") }

            defer { setInsetsAndReload() }

            Message.consentRequestMessageID = nil
            guard let existingConversation = conversations?.sortedByLatestMessageSentDate
                .first(where: { users.map(\.id).sorted() == $0.users!.map(\.id).sorted() }) else {
                defer { shouldReload = !isPreviousConversationEmpty }

                guard !contactSelectionUIService.selectedContactPairs.isEmpty else {
                    clientSession.conversation.setCurrentConversation(.empty)
                    return
                }

                guard !contactSelectionUIService.selectedContactPairs.allSatisfy(\.isMock) else {
                    clientSession.conversation.setCurrentConversation(.empty(withUsers: users))
                    return
                }

                clientSession.conversation.setCurrentConversation(.mock(withUsers: users))
                return
            }

            clientSession.conversation.setCurrentConversation(existingConversation)
            shouldReload = existingConversation.id.key != previousConversationIDKey
        }
    }

    // MARK: - Reconfigure Last Contact View

    func reconfigureLastContactView() {
        typealias Floats = AppConstants.CGFloats.ChatPageViewService.RecipientBarService.ContactSelectionUI
        typealias Strings = AppConstants.Strings.ChatPageViewService.RecipientBarService.ContactSelectionUI

        guard let contactView = firstContactView(.onSameLevelAsTextField),
              let contactLabel = contactView.firstSubview(for: Strings.contactLabelSemanticTag) as? UILabel,
              let recipientBarView = chatPageViewService.recipientBar?.layout.recipientBarView else { return }

        var labelText = (contactLabel.text ?? "")
        while labelText.hasSuffix(",") { labelText = labelText.dropSuffix() }
        contactLabel.text = labelText

        contactLabel.frame.size.height = contactLabel.intrinsicContentSize.height
        contactLabel.frame.size.width = contactLabel.intrinsicContentSize.width

        while contactLabel.frame.size.width >= recipientBarView.frame.size.width / Floats.contactViewMaximumWidthDivisor { contactLabel.frame.size.width -= 1 }

        contactView.frame.size.width = contactLabel.frame.size.width + Floats.contactViewWidthIncrement
        contactLabel.center = .init(x: contactView.bounds.midX, y: contactView.bounds.midY)
    }

    // MARK: - Reconfigure Recipient Bar

    func reconfigureRecipientBar(forSublevel sublevel: Int) {
        guard let recipientBarView = chatPageViewService.recipientBar?.layout.recipientBarView,
              let tableView = chatPageViewService.recipientBar?.layout.tableView else { return }
        typealias Floats = AppConstants.CGFloats.ChatPageViewService.RecipientBarService.Layout
        let recipientBarFrameHeight = Floats.frameHeight + value(for: sublevel)
        recipientBarView.frame.size.height = recipientBarFrameHeight
        chatPageViewService.recipientBar?.layout.configureBorders()
        tableView.contentInset.bottom = recipientBarFrameHeight
    }

    // MARK: - Reconfigure Text Field

    func reconfigureTextField(relativeTo view: UIView) {
        guard let recipientBarView = chatPageViewService.recipientBar?.layout.recipientBarView,
              let textField = chatPageViewService.recipientBar?.layout.textField,
              let toLabel = chatPageViewService.recipientBar?.layout.toLabel else { return }

        let isOnInitialLevel = (textField.center.y == toLabel.center.y || view.frame.maxY == Floats.initialLevelMaxY) // swiftlint:disable:next line_length
        let widthDecrement = isOnInitialLevel ? Floats.textFieldReconfigurationInitialLevelWidthDecrement : Floats.textFieldReconfigurationNotInitialLevelWidthDecrement

        textField.frame.origin.x = view.frame.maxX + Floats.textFieldReconfigurationXOriginIncrement
        textField.frame.size.width = (recipientBarView.frame.maxX - textField.frame.origin.x) - widthDecrement
        textField.center.y = view.center.y
    }

    // MARK: - Auxiliary

    private func value(for sublevel: Int) -> CGFloat {
        Floats.sublevelMultiplier * (sublevel - 1 < 0 ? 1 : .init(sublevel) - 1)
    }
}
