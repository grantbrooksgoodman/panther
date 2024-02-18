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

/* 3rd-party */
import Redux

public final class RecipientBarConfigService {
    // MARK: - Types

    public enum ContactViewSpacialConfiguration {
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

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - First Contact View

    public func firstContactView(_ configuration: ContactViewSpacialConfiguration) -> UIView? {
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

    public func reconfigureCollectionView() {
        Task { @MainActor in
            var shouldReload = false

            func setInsetsAndReload() {
                Task { @MainActor in
                    chatPageViewService.alternateMessage?.restoreAllAlternateTextMessageIDs()
                    chatPageViewService.alternateMessage?.restoreAllAudioTranscriptionMessageIDs()

                    avSpeechSynthesizer.stopSpeaking(at: .immediate)
                    chatPageViewService.audioMessagePlayback?.stopPlayback()

                    await chatPageViewService.recordingUI?.hideRecordingUI()
                    _ = recordingService.cancelRecording()

                    chatPageViewService.inputBar?.configureInputBar(forceUpdate: true)
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

            guard let conversations = clientSession.user.currentUser?.conversations?.visibleForCurrentUser.filter({ $0.users != nil }) else { return }
            let users = contactSelectionUIService.selectedContactPairs.map(\.numberPairs).reduce([], +).map(\.users).reduce([], +)

            // FIXME: Observed bugs with this disabled, but iMessage does it this way.
//            viewController.messageInputBar.inputTextView.text = ""
            _ = await chatPageViewService.inputBar?.textViewDidChange(to: "")

            defer { setInsetsAndReload() }

            guard let existingConversation = conversations.sortedByLatestMessageSentDate
                .first(where: { users.map(\.id).sorted() == $0.users!.map(\.id).sorted() }) else {
                clientSession.conversation.setCurrentConversation(contactSelectionUIService.selectedContactPairs.isEmpty ? .empty : .mock(withUsers: users))
                shouldReload = !isPreviousConversationEmpty
                return
            }

            clientSession.conversation.setCurrentConversation(existingConversation)
            shouldReload = existingConversation.id.key != previousConversationIDKey
        }
    }

    // MARK: - Reconfigure Recipient Bar

    public func reconfigureRecipientBar(forSublevel sublevel: Int) {
        guard let recipientBarView = chatPageViewService.recipientBar?.layout.recipientBarView,
              let tableView = chatPageViewService.recipientBar?.layout.tableView else { return }
        typealias Floats = AppConstants.CGFloats.ChatPageViewService.RecipientBarService.Layout
        let recipientBarFrameHeight = Floats.frameHeight + value(for: sublevel)
        recipientBarView.frame.size.height = recipientBarFrameHeight
        chatPageViewService.recipientBar?.layout.configureBorders()
        tableView.contentInset.bottom = recipientBarFrameHeight
    }

    // MARK: - Reconfigure Text Field

    public func reconfigureTextField(relativeTo view: UIView) {
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

    private func value(for sublevel: Int) -> CGFloat { Floats.sublevelMultiplier * (sublevel - 1 < 0 ? 1 : .init(sublevel) - 1) }
}
