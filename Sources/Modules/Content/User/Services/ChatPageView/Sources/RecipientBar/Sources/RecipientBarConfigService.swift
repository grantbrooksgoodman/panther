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

/// The service that reconfigures the recipient bar and its message list as recipients change.
///
/// ``RecipientBarConfigService`` repositions the recipient bar's text field and selected-contact
/// views as recipients are added and removed, resizes the bar to fit them across multiple rows,
/// and resolves the current conversation from the selected contacts.
@MainActor
final class RecipientBarConfigService {
    // MARK: - Types

    /// A way of locating a selected-contact view within the recipient bar.
    enum ContactViewSpacialConfiguration {
        /// The trailing-most contact view, optionally restricted to the given row.
        case furthestTrailing(onSublevel: Int? = nil)

        /// The trailing-most contact view on the same row as the text field.
        case onSameLevelAsTextField
    }

    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.RecipientBarService.Config

    // MARK: - Dependencies

    @Dependency(\.avSpeechSynthesizer) private var avSpeechSynthesizer: AVSpeechSynthesizer
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession.entity) private var entitySession: EntitySession
    @Dependency(\.commonServices.audio.recording) private var recordingService: RecordingService

    // MARK: - Properties

    private let viewController: ChatPageViewController

    // MARK: - Init

    /// Creates the service, binding it to the given chat page view controller.
    ///
    /// - Parameter viewController: The chat page's messages view controller.
    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - First Contact View

    /// Returns the selected-contact view matching the given spatial configuration.
    ///
    /// - Parameter configuration: The way of locating the view within the recipient bar.
    ///
    /// - Returns: The matching contact view, or `nil` if none is found.
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

    /// Resolves the current conversation from the selected contacts and reloads the message list
    /// to match.
    ///
    /// When the selected contacts match an existing conversation, that conversation becomes
    /// current; otherwise, an empty or provisional conversation is set up in its place. The
    /// message list is reloaded when the resolved conversation differs from the previous one.
    func reconfigureCollectionView() {
        var shouldReload = false

        func setInsetsAndReload() {
            Task { @MainActor [shouldReload] in
                chatPageViewService.alternateMessage?.restoreAllAlternateTextMessageIDs()
                chatPageViewService.alternateMessage?.restoreAllAudioTranscriptionMessageIDs()

                avSpeechSynthesizer.stopSpeakingIfNeeded()
                chatPageViewService.audioMessagePlayback?.stopPlayback()

                await chatPageViewService.recordingUI?.hideRecordingUI()
                try? recordingService.cancelRecording()

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

        let isPreviousConversationEmpty = entitySession.conversation.currentConversation?.isEmpty ?? true
        let previousConversationIDKey = entitySession.conversation.currentConversation?.id.key ?? ""

        let conversations = entitySession.user.currentUser?.conversations?.visibleForCurrentUser.filter { $0.users != nil }
        let userIDs = contactSelectionUIService.selectedContactPairs.userIDs
        let users = contactSelectionUIService.selectedContactPairs.users

        // NIT: Observed bugs with this disabled, but iMessage does it this way.
//            viewController.messageInputBar.inputTextView.text = ""
        Task.background { @MainActor in
            try? await chatPageViewService
                .typingIndicator?
                .textViewDidChange(to: "")
        }

        defer { setInsetsAndReload() }

        Message.consentRequestMessageID = nil
        guard let existingConversation = conversations?
            .sortedByLatestMessageSentDate
            .first(where: {
                userIDs.sorted() == $0.users?.map(\.id).sorted()
            }) else {
            defer { shouldReload = !isPreviousConversationEmpty }

            guard !contactSelectionUIService.selectedContactPairs.isEmpty else {
                entitySession.conversation.setCurrentConversation(.empty)
                return
            }

            guard !contactSelectionUIService.selectedContactPairs.allSatisfy(\.isMock) else {
                entitySession.conversation.setCurrentConversation(.empty(withUsers: users))
                return
            }

            entitySession.conversation.setCurrentConversation(.mock(withUsers: users))
            return
        }

        entitySession.conversation.setCurrentConversation(existingConversation)
        shouldReload = existingConversation.id.key != previousConversationIDKey
    }

    // MARK: - Reconfigure Last Contact View

    /// Resizes the contact view on the text field's row to fit its label, trimming any trailing
    /// comma.
    func reconfigureLastContactView() {
        typealias Floats = AppConstants.CGFloats.ChatPageViewService.RecipientBarService.ContactSelectionUI
        typealias Strings = AppConstants.Strings.ChatPageViewService.RecipientBarService.ContactSelectionUI

        guard let contactView = firstContactView(.onSameLevelAsTextField),
              let contactLabel = contactView.firstSubview(for: Strings.contactLabelSemanticTag) as? UILabel,
              let recipientBarView = chatPageViewService.recipientBar?.layout.recipientBarView else { return }

        var labelText = (contactLabel.text ?? "")
        while labelText.hasSuffix(",") {
            labelText = labelText.dropSuffix()
        }
        contactLabel.text = labelText

        contactLabel.frame.size.height = contactLabel.intrinsicContentSize.height
        contactLabel.frame.size.width = contactLabel.intrinsicContentSize.width

        while contactLabel.frame.size.width >= recipientBarView.frame.size.width / Floats.contactViewMaximumWidthDivisor {
            contactLabel.frame.size.width -= 1
        }

        contactView.frame.size.width = contactLabel.frame.size.width + Floats.contactViewWidthIncrement
        contactLabel.center = .init(x: contactView.bounds.midX, y: contactView.bounds.midY)
    }

    // MARK: - Reconfigure Recipient Bar

    /// Resizes the recipient bar to accommodate the given number of contact-view rows.
    ///
    /// - Parameter sublevel: The number of rows of contact views to accommodate.
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

    /// Repositions the text field to follow the given view, sizing it to fill the remaining width
    /// of its row.
    ///
    /// - Parameter view: The view the text field should follow, such as the trailing-most
    ///   contact view.
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
