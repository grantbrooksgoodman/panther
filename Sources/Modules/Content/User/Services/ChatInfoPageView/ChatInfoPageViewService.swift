//
//  ChatInfoPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length

/* Native */
import Contacts
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

/// The service that handles the chat info page's user interactions.
///
/// Use ``ChatInfoPageViewService`` to load the current conversation's participants and to
/// respond to the chat info page's controls – changing the conversation's name and photo,
/// removing participants, leaving the conversation, previewing media, and sharing PenPals
/// data.
@MainActor // swiftlint:disable:next type_body_length
final class ChatInfoPageViewService {
    // MARK: - Types

    /// A change the user chose to make to the conversation's metadata.
    enum MetadataChangeType {
        /// A name change, carrying the metadata with the new name applied.
        case name(ConversationMetadata)

        /// A photo removal, carrying the metadata with the photo cleared.
        case removePhoto(ConversationMetadata)

        /// A request to capture a new photo with the camera.
        case selectPhotoFromCamera

        /// A request to choose a new photo from the photo library.
        case selectPhotoFromLibrary
    }

    private enum CacheKey: String, CaseIterable {
        case chatParticipantsForUserIDs
    }

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.commonServices.contact) private var contactService: ContactService
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.quickViewer) private var quickViewer: QuickViewer
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    /// A Boolean value that indicates whether a media preview is presented.
    private(set) var isPreviewingMedia = false

    @Cached(CacheKey.chatParticipantsForUserIDs) private var cachedChatParticipantsForUserIDs: [String: ChatParticipant]?
    @SharedEvent(\.chatInfoPageLoadingStateUpdated) private var chatInfoPageLoadingStateUpdated
    @SharedEvent(\.currentConversationActivityChanged) private var currentConversationActivityChanged
    @SharedEvent(\.currentConversationMetadataChanged) private var currentConversationMetadataChanged

    // MARK: - Init

    /// Creates a chat info page view service.
    nonisolated init() {}

    // MARK: - Computed Properties

    private var uiSegmentBackgroundViewBackgroundColor: UIColor {
        if Application.isInPrevaricationMode || UIApplication.isFullyV26Compatible {
            return .init(hex: ThemeService.isDarkModeActive ? 0x313136 : 0xE2E2E6)
        }

        return .groupedContentBackground
    }

    private var uiSegmentBackgroundViews: [UIView] {
        uiApplication
            .presentedViews
            .filter { $0.descriptor == "UISegment" }
            .compactMap(\.superview?.superview)
    }

    // MARK: - Get Chat Participants

    // swiftlint:disable function_body_length
    /// Returns the current conversation's participants, prepared for display.
    ///
    /// Each participant combines their user record with a matching device contact, when one
    /// exists. In PenPals conversations, participants who have not shared their data with the
    /// current user – and are not otherwise known to them – appear under their obfuscated
    /// PenPals names without contact information. Results outside PenPals conversations are
    /// cached in memory per user, and uncached participants resolve in parallel.
    ///
    /// - Returns: The participants, sorted by display name – names beginning with a letter
    ///   first.
    ///
    /// - Throws: An `Exception` if no current conversation is set, or if participant
    ///   resolution fails.
    func getChatParticipants() async throws(Exception) -> [ChatParticipant] {
        @Dependency(\.commonServices.penPals) var penPalsService: PenPalsService
        guard let conversation = clientSession.entity.conversation.currentConversation else {
            throw Exception(
                "No current conversation.",
                metadata: .init(sender: self)
            )
        }

        guard let users = conversation.users,
              !users.isEmpty,
              conversation.participants.count - 1 == users.count else {
            // TODO: Audit this guard. Should never be possible under SSoT + SPoT.
            try await conversation.resolveUsers(forceUpdate: true)
            return try await getChatParticipants()
        }

        let isPenPalsConversation = conversation.metadata.isPenPalsConversation

        // Return cached participants immediately; collect the rest for parallel resolution.
        var chatParticipants = [ChatParticipant]()
        var uncachedUsers = [User]()

        for user in users {
            if !isPenPalsConversation,
               let cachedParticipant = cachedChatParticipantsForUserIDs?[user.id] {
                chatParticipants.append(cachedParticipant)
            } else {
                uncachedUsers.append(user)
            }
        }

        // Resolve uncached users in parallel (the only async work is the CNContact lookup).
        let participants = try await uncachedUsers
            .parallelMap { @Sendable user -> (String, ChatParticipant)? in
                let currentUserSharesData = conversation.currentUserSharesPenPalsData(with: user)
                // swiftlint:disable:next identifier_name
                let currentUserDoesNotShareDataButOtherUserDoes = !currentUserSharesData && conversation.userSharesPenPalsDataWithCurrentUser(user)

                var chatParticipant: ChatParticipant?

                if !isPenPalsConversation
                    || conversation.mutuallySharedPenPalsDataBetweenCurrentUserAnd(user)
                    || currentUserDoesNotShareDataButOtherUserDoes
                    || penPalsService.isKnownToCurrentUser(user.id) {
                    let isPenPal = !conversation.mutuallySharedPenPalsDataBetweenCurrentUserAnd(user) &&
                        !penPalsService.isKnownToCurrentUser(user.id)

                    do {
                        let cnContact = try await self.contactService.firstCNContact(
                            for: user.phoneNumber
                        )

                        let contactPair: ContactPair = .init(
                            contact: .init(cnContact),
                            numberPairs: [.init(
                                phoneNumber: user.phoneNumber,
                                userIDs: [user.id]
                            )]
                        )

                        chatParticipant = .init(
                            displayName: contactPair.contact.fullName,
                            cnContactContainer: currentUserDoesNotShareDataButOtherUserDoes ? nil : .init(cnContact.mutableCopy() as? CNMutableContact),
                            contactPair: contactPair,
                            penPalsStatus: isPenPal ? (currentUserSharesData ? .currentUserSharesData : .currentUserDoesNotShareData) : nil
                        )
                    } catch {
                        let cnContact = CNMutableContact()
                        cnContact.phoneNumbers.append(
                            .init(
                                label: nil,
                                value: .init(stringValue: user.phoneNumber.formattedString())
                            )
                        )

                        let contactPair: ContactPair = .init(
                            contact: .init(cnContact),
                            numberPairs: [.init(
                                phoneNumber: user.phoneNumber,
                                userIDs: [user.id]
                            )]
                        )

                        chatParticipant = .init(
                            displayName: contactPair.contact.fullName,
                            cnContactContainer: currentUserDoesNotShareDataButOtherUserDoes ? nil : .init(cnContact, isUnknown: true),
                            contactPair: contactPair,
                            penPalsStatus: isPenPal ? (currentUserSharesData ? .currentUserSharesData : .currentUserDoesNotShareData) : nil
                        )
                    }
                } else {
                    chatParticipant = .init(
                        displayName: user.penPalsName,
                        cnContactContainer: nil,
                        contactPair: .withUser(user, name: user.penPalsName),
                        penPalsStatus: currentUserSharesData ? .currentUserSharesData : .currentUserDoesNotShareData
                    )
                }

                guard let chatParticipant else { return nil }
                return (user.id, chatParticipant)
            }

        let resolvedPairs = participants.compactMap(\.self)
        chatParticipants.append(contentsOf: resolvedPairs.map(\.1))

        if !isPenPalsConversation {
            var cachedChatParticipantsForUserIDs = cachedChatParticipantsForUserIDs ?? [:]
            for (userID, participant) in resolvedPairs {
                cachedChatParticipantsForUserIDs[userID] = participant
            }

            self.cachedChatParticipantsForUserIDs = cachedChatParticipantsForUserIDs
        }

        var withAlphabeticalPrefix = [ChatParticipant]()
        var withoutAlphabeticalPrefix = [ChatParticipant]()

        for participant in chatParticipants {
            if let firstCharacter = participant.displayName.first,
               firstCharacter.isLetter {
                withAlphabeticalPrefix.append(participant)
            } else {
                withoutAlphabeticalPrefix.append(participant)
            }
        }

        func sorted(_ participants: [ChatParticipant]) -> [ChatParticipant] {
            participants.sorted(by: { $0.displayName < $1.displayName })
        }

        return sorted(withAlphabeticalPrefix) + sorted(withoutAlphabeticalPrefix)
    } // swiftlint:enable function_body_length

    // MARK: - Reducer Action Handlers

    /// Asks the user to confirm leaving the given conversation, applying it if they accept.
    ///
    /// Leaving removes the current user from the conversation, dismisses all presented
    /// sheets, and removes the conversation from the session store. Failures surface as a
    /// toast.
    ///
    /// - Parameter conversation: The conversation to leave.
    func leaveConversationButtonTapped(_ conversation: Conversation?) {
        Task {
            guard let conversation else { return }
            var conversationName = "⌘\(conversation.metadata.name)⌘"
            if conversationName.sanitized.isBangQualifiedEmpty {
                conversationName = "Conversation"
            }

            guard let currentUserID = User.currentUserID,
                  await AKConfirmationAlert(
                      title: "Leave \(conversationName)",
                      message: "Are you sure you'd like to leave this conversation?",
                      cancelButtonTitle: Localized(.cancel).wrappedValue,
                      confirmButtonStyle: .destructivePreferred
                  ).present(translating: [
                      .confirmButtonTitle,
                      .message,
                      .title,
                  ]) else { return }

            chatInfoPageLoadingStateUpdated.send()
            RuntimeStorage.store(
                false,
                as: .shouldNotifyOfConversationAvailability
            )

            do throws(Exception) {
                try await clientSession.entity.activity.removeFromConversation(
                    currentUserID,
                    conversation: conversation
                )

                Application.dismissSheets()
                clientSession.store.removeConversation(idKey: conversation.id.key)
            } catch {
                Logger.log(
                    error,
                    with: .toast
                )
            }
        }
    }

    /// Previews the conversation's media files, starting at the given index.
    ///
    /// - Parameters:
    ///   - metadata: The display metadata of the tapped item.
    ///   - filePaths: The paths of the files available to preview.
    ///   - startingIndex: The index of the file to show first.
    func mediaItemViewTapped(
        _ metadata: MediaItemView.Metadata,
        filePaths: [String],
        startingIndex: Int
    ) {
        isPreviewingMedia = true
        try? quickViewer.preview(
            filesAtPaths: filePaths,
            startingIndex: startingIndex,
            title: Localized(.attachment).wrappedValue,
            embedded: true
        )

        StatusBar.overrideStyle(.appAware)
        quickViewer.onDismiss {
            NavigationBar.setAppearance(Application.isInPrevaricationMode ? .appDefault : .default())
            self.isPreviewingMedia = false
        }
    }

    /// Asks the user to confirm removing the given participant, applying it if they accept.
    ///
    /// Removal dismisses the chat sheet, removes the participant from the conversation,
    /// reloads the chat, and notifies observers of the activity change. Failures surface as a
    /// toast.
    ///
    /// - Parameters:
    ///   - chatParticipant: The participant to remove.
    ///   - conversation: The conversation to remove them from.
    func removeUserButtonTapped(
        _ chatParticipant: ChatParticipant,
        conversation: Conversation?
    ) {
        Task {
            guard let conversation,
                  let user = chatParticipant.firstUser else { return }

            guard await AKConfirmationAlert(
                title: user.displayName,
                message: "Are you sure you'd like to remove this person from the conversation?",
                cancelButtonTitle: Localized(.cancel).wrappedValue,
                confirmButtonStyle: .destructivePreferred
            ).present(translating: [
                .confirmButtonTitle,
                .message,
            ]) else { return }

            navigation.navigate(to: .chat(.sheet(.none)))
            chatInfoPageLoadingStateUpdated.send()

            do throws(Exception) {
                try await clientSession.entity.activity.removeFromConversation(
                    user.id,
                    conversation: conversation
                )

                chatPageViewService.reloadCollectionView()
                currentConversationActivityChanged.send()
            } catch {
                Logger.log(
                    error,
                    with: .toast
                )
            }
        }
    }

    /// Reapplies the segmented control's background color after a trait collection change.
    func traitCollectionChanged() {
        Task.delayed(by: .milliseconds(100)) { @MainActor in
            for uiSegmentBackgroundView in self.uiSegmentBackgroundViews {
                uiSegmentBackgroundView.backgroundColor = self.uiSegmentBackgroundViewBackgroundColor
            }
        }
    }

    /// Applies new metadata to the given conversation, recording an activity for the change.
    ///
    /// - Parameters:
    ///   - conversation: The conversation to update.
    ///   - action: The activity action describing the change.
    ///   - newMetadata: The metadata to apply.
    ///
    /// - Throws: An `Exception` if the activity cannot be synthesized, or if the update
    ///   fails.
    func updateMetadata(
        _ conversation: Conversation,
        action: Activity.Action,
        newMetadata: ConversationMetadata
    ) async throws(Exception) {
        guard let activity = Activity(action) else {
            throw Exception(
                "Failed to synthesize activity.",
                metadata: .init(sender: self)
            )
        }

        _ = try await conversation.updateValues(
            with: [
                \.activities: ((conversation.activities ?? []) + [activity]).filter { $0 != .empty },
                \.metadata: newMetadata,
            ]
        )
    }

    /// Responds to the chat info page appearing.
    ///
    /// This method dismisses the keyboard, configures segmented controls to size segments by
    /// content, and schedules a metadata change notification for when any in-flight message
    /// send completes.
    func viewAppeared() {
        uiApplication.resignFirstResponders()
        UISegmentedControl.appearance().apportionsSegmentWidthsByContent = true
        messageDeliveryService.addEffectUponIsSendingMessage(
            changedTo: false,
            id: .updateChatInfoPageView
        ) { self.currentConversationMetadataChanged.send() }
    }

    /// Responds to the chat info page finishing its initial load, correcting the segmented
    /// control's background color while the sheet remains presented.
    func viewLoaded() {
        Task.delayed(by: .seconds(1)) { @MainActor [weak self] in
            guard let self else { return }
            uiSegmentBackgroundViews
                .filter { $0.backgroundColor != self.uiSegmentBackgroundViewBackgroundColor }
                .forEach { $0.backgroundColor = self.uiSegmentBackgroundViewBackgroundColor }

            guard uiApplication.isPresentingSheet else { return }
            viewLoaded()
        }
    }

    // MARK: - Clear Cache

    /// Removes every cached chat participant.
    func clearCache() {
        cachedChatParticipantsForUserIDs = nil
    }
}

// swiftlint:enable file_length
