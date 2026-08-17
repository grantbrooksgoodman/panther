//
//  ChatInfoPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import Networking

/// The reducer that drives the chat info page.
///
/// This page presents details about a conversation and the actions available on it. It lists the
/// conversation's participants and shared media, and – depending on the conversation's kind – lets
/// the user rename the conversation, change its photo, add or remove participants, leave the
/// conversation, and manage PenPals data sharing. Most of these actions are performed through
/// ``ChatInfoPageViewService``.
///
/// The page's behavior contract:
///
/// - On appearance, the page resolves its translated display strings and its participant list
///   concurrently, remaining in the loading state until the participants resolve. If resolving
///   the participants fails, the page enters the error state.
/// - A segmented control switches the page between its participant and media lists.
/// - The metadata actions available depend on the conversation's kind. The change-metadata
///   button – for renaming the conversation or changing its photo – is shown only for conversations
///   that are not PenPals conversations. The PenPals data-sharing switch is shown only for
///   two-participant PenPals conversations.
/// - Changing the conversation's name or photo, adding or removing a participant, and sharing
///   PenPals data are performed through ``ChatInfoPageViewService``. When metadata changes, the
///   page reloads the chat, updates its navigation title, and notifies observers of the change.
/// - Because the page mirrors state that lives outside it, several actions regenerate a view's
///   identity to force it to rebuild from the latest values.
struct ChatInfoPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.conversationCellViewService) private var conversationCellViewService: ConversationCellViewService
    @Dependency(\.clientSession.entity.conversation) private var conversationSession: ConversationSessionService
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.chatInfoPageViewService) private var viewService: ChatInfoPageViewService

    // MARK: - Properties

    @SharedEvent(\.currentConversationMetadataChanged) private var currentConversationMetadataChanged

    // MARK: - Actions

    /// The actions the chat info page can process.
    enum Action {
        /// An action that indicates the view appeared. Begins resolving the display strings and
        /// the participant list.
        case viewAppeared

        /// An action that indicates the view disappeared. Restores the chat page's navigation bar
        /// appearance.
        case viewDisappeared

        /// An action that indicates the user tapped the add-contact button. Presents the contact
        /// selector.
        case addContactButtonTapped

        /// An action that indicates the camera picker was dismissed, carrying any resulting
        /// `Exception`.
        case cameraPickerDismissed(Exception?)

        /// An action that indicates the change-metadata action sheet was dismissed, carrying the
        /// change the user chose, or `nil` if the sheet was canceled.
        case changeMetadataActionSheetDismissed(ChatInfoPageViewService.MetadataChangeType?)

        /// An action that indicates the user tapped the change-metadata button. Presents the
        /// change-metadata action sheet.
        case changeMetadataButtonTapped

        /// An action that indicates the user tapped the chat info cell. Expands or collapses the
        /// participant list.
        case chatInfoCellTapped

        /// An action that indicates the current conversation's metadata changed. Rebuilds the
        /// page from the latest values.
        case currentConversationMetadataChanged

        /// An action that indicates the user tapped the done header item. Dismisses the page.
        case doneHeaderItemTapped

        /// An action that indicates resolving the participant list failed, carrying the resulting
        /// `Exception`.
        case getChatParticipantsFailed(Exception)

        /// An action that indicates the participant list resolved, carrying the resolved
        /// participants.
        case getChatParticipantsReturned([ChatParticipant])

        /// An action that indicates the user tapped the leave-conversation button. Begins leaving
        /// the conversation.
        case leaveConversationButtonTapped

        /// An action that returns the page to its loading state.
        case loadingStateUpdated

        /// An action that indicates the user tapped a shared media item, carrying its metadata.
        /// Presents the media preview.
        case mediaItemViewTapped(MediaItemView.Metadata)

        /// An action that indicates the user tapped a PenPals participant, carrying the
        /// participant. Offers to share PenPals data with them, or shows their sharing status
        /// when data is already shared.
        case penPalParticipantViewTapped(ChatParticipant)

        // swiftlint:disable identifier_name
        /// An action that indicates the PenPals data-sharing confirmation action sheet was
        /// dismissed, carrying the identifier of the user to share data with, or `nil` if the
        /// sheet was canceled.
        case penPalsSharingDataConfirmationActionSheetDismissed(String?)
        // swiftlint:enable identifier_name

        /// An action that indicates the user toggled the PenPals data-sharing switch on. Offers
        /// to share PenPals data with the other participant.
        case penPalsSharingDataSwitchToggledOn

        /// An action that indicates the photo picker was dismissed, carrying any resulting
        /// `Exception`.
        case photoPickerDismissed(Exception?)

        /// An action that indicates the user tapped a participant's remove button, carrying the
        /// participant. Begins removing them from the conversation.
        case removeUserButtonTapped(ChatParticipant)

        /// An action that indicates display string resolution failed, carrying the resulting
        /// `Exception`.
        case resolveFailed(Exception)

        /// An action that indicates display string resolution succeeded, carrying the resolved
        /// strings.
        case resolveReturned([TranslationOutputMap])

        /// An action that indicates the segmented control's selection changed, carrying the new
        /// index.
        case segmentedControlSelectionIndexChanged(Int)

        /// An action that indicates the user selected a new conversation photo, carrying the
        /// chosen image. Applies it as the conversation's photo.
        case selectedImageChanged(UIImage)

        /// An action that indicates the trait collection changed.
        case traitCollectionChanged

        /// An action that indicates a metadata update failed, carrying the resulting `Exception`.
        case updateMetadataFailed(Exception)

        /// An action that indicates a metadata update finished. Reloads the chat, updates the
        /// navigation title, and notifies observers of the change.
        ///
        /// - Parameter togglePenPalsSharingDataSwitch: A Boolean value that indicates whether the
        ///   PenPals data-sharing switch should appear toggled on afterward.
        case updateMetadataReturned(togglePenPalsSharingDataSwitch: Bool = false)

        /// An action that indicates the user tapped a participant's info badge, carrying the
        /// user. Presents that user's info alert.
        case userInfoBadgeTapped(User?)
    }

    // MARK: - State

    /// The state of the chat info page.
    struct State: Equatable {
        /* MARK: Properties */

        /// The identity of the chat info cell. Regenerated to rebuild the cell when the
        /// participant list expands or collapses.
        var chatInfoCellViewID = UUID()

        /// The conversation's participants.
        var chatParticipants = [ChatParticipant]()

        /// A Boolean value that indicates whether the change-metadata button is enabled. Disabled
        /// while a metadata change is in progress, and while the conversation is awaiting the
        /// initiator's consent.
        var isChangeMetadataButtonEnabled = true

        /// A Boolean value that indicates whether the PenPals data-sharing switch is toggled on,
        /// reflecting whether the current user shares their PenPals data with all participants.
        var isPenPalsSharingDataSwitchToggled = false

        /// The index of the selected segmented control option: the participant list or the shared
        /// media list.
        var segmentedControlSelectionIndex = 0

        /// The identity of the segmented control. Regenerated to rebuild it once display strings
        /// resolve.
        var segmentedControlViewID = UUID()

        /// The page's translated display strings. Contains the default, untranslated strings
        /// until resolution completes.
        var strings: [TranslationOutputMap] = ChatInfoPageViewStrings.defaultOutputMap

        /// The identity of the page's content. Regenerated to rebuild it from the latest
        /// conversation values.
        var viewID = UUID()

        /// The page's loading state. Remains `loading` until the participant list resolves.
        var viewState: StatefulView.ViewState = .loading

        /// The participants currently shown in the chat info cell's expandable list. Empty while
        /// the list is collapsed.
        var visibleParticipants = [ChatParticipant]()

        fileprivate var inputBarWasFirstResponder = false

        /* MARK: Computed Properties */

        /// The conversation's avatar image, or `nil` if none is available.
        @MainActor
        var avatarImage: UIImage? {
            cellViewData?.thumbnailImage
        }

        /// The system image name for the chat info cell's expand-or-collapse chevron.
        var chatInfoCellImageSystemName: String {
            "chevron.\(visibleParticipants.isEmpty ? "right" : "down").circle"
        }

        /// The chat info cell's subtitle: the participants' display names, comma-separated.
        var chatInfoCellSubtitleLabelText: String {
            chatParticipants.map(\.displayName).joined(separator: ", ")
        }

        /// The chat info cell's title: the participant count followed by a localized label.
        var chatInfoCellTitleLabelText: String {
            "\(chatParticipants.count) \(strings.value(for: .participantCountLabelText))"
        }

        /// The conversation's title.
        @MainActor
        var chatTitleLabelText: String {
            guard let cellViewData else { return "" }
            return cellViewData.titleLabelText
        }

        /// A Boolean value that indicates whether the add-contact button is enabled. Disabled
        /// while a message is being sent.
        @MainActor
        var isAddContactButtonEnabled: Bool {
            !Dependency(\.messageDeliveryService.isSendingMessage).wrappedValue
        }

        /// A Boolean value that indicates whether Developer Mode is enabled.
        var isDeveloperModeEnabled: Bool {
            Dependency(\.build.isDeveloperModeEnabled).wrappedValue
        }

        /// A Boolean value that indicates whether the leave-conversation button is enabled.
        /// Enabled only when the conversation has more than two participants and no message is
        /// being sent.
        @MainActor
        var isLeaveConversationButtonEnabled: Bool {
            chatParticipants.count > 2 &&
                !Dependency(\.messageDeliveryService.isSendingMessage).wrappedValue
        }

        /// The metadata for the conversation's shared media items.
        @MainActor
        var mediaItemMetadata: [MediaItemView.Metadata] {
            conversation?
                .withMessagesOffsetFromCurrentUserAdditionDate
                .mediaItemMetadata ?? []
        }

        /// The maximum width of the segmented control, two-thirds of the screen's width.
        @MainActor
        var segmentedControlMaxWidth: CGFloat {
            Dependency(\.uiApplication.mainScreen.bounds.width).wrappedValue * (2 / 3)
        }

        /// The titles of the segmented control's options: the participant list and the shared
        /// media list.
        var segmentedControlOptionTitles: [String] {
            [
                strings.value(for: .segmentedControlParticipantsOptionText),
                strings.value(for: .segmentedControlMediaOptionText),
            ]
        }

        /// A Boolean value that indicates whether the segmented control should be elongated to
        /// fit long localized option titles.
        var shouldElongateSegmentedControl: Bool {
            RuntimeStorage.languageCode != "en" && segmentedControlOptionTitles
                .contains(where: { $0.count >= 25 || $0.components(separatedBy: " ").count > 2 })
        }

        /// A Boolean value that indicates whether the change-metadata button is shown. Shown only
        /// for conversations that are not PenPals conversations.
        var showsChangeMetadataButton: Bool {
            conversation?.metadata.isPenPalsConversation == false
        }

        /// A Boolean value that indicates whether the PenPals data-sharing switch is shown. Shown
        /// only for two-participant PenPals conversations.
        var showsPenPalsSharingDataSwitch: Bool {
            conversation?.metadata.isPenPalsConversation == true && conversation?.participants.count == 2
        }

        /// A Boolean value that indicates whether participants can be removed with a swipe
        /// action. Available only in conversations that are not PenPals conversations, are not
        /// awaiting the initiator's consent, and have more than two visible participants.
        var showsRemoveUserSwipeAction: Bool {
            guard conversation?.metadata.isPenPalsConversation == false,
                  conversation?.metadata.requiresConsentFromInitiator == nil,
                  visibleParticipants.count > 2 else { return false }
            return true
        }

        /// The system contact container for the conversation's sole participant, or `nil` when
        /// there is not exactly one participant or the conversation is a PenPals conversation.
        var singleCNContactContainer: CNContactContainer? {
            guard chatParticipants.count == 1,
                  conversation?.metadata.isPenPalsConversation == false else { return nil }
            return chatParticipants.first?.cnContactContainer
        }

        /// The amount by which to increase the number of participant rows shown. Its value is `1`
        /// when the participant list is expanded for a conversation that is not a PenPals
        /// conversation, is not awaiting the initiator's consent, and has fewer than ten visible
        /// participants; otherwise, `0`.
        var visibleParticipantsIncrement: Int {
            guard conversation?.metadata.isPenPalsConversation == false,
                  conversation?.metadata.requiresConsentFromInitiator == nil,
                  !visibleParticipants.isEmpty,
                  visibleParticipants.count < 10 else { return 0 }
            return 1
        }

        @MainActor
        fileprivate var cellViewData: ConversationCellViewData? {
            guard let conversation else { return nil }
            return .init(conversation)
        }

        fileprivate var conversation: Conversation? {
            Dependency(\.clientSession.entity.conversation.currentConversation).wrappedValue
        }
    }

    // MARK: - Reduce

    // swiftlint:disable cyclomatic_complexity function_body_length
    /// Updates the page's state in response to the given action, returning any effect to run.
    ///
    /// - Parameters:
    ///   - state: The page's current state, mutated in place.
    ///   - action: The action to process.
    ///
    /// - Returns: An effect for the system to run, or `.none`.
    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading
            state.inputBarWasFirstResponder = chatPageViewService.inputBar?.isFirstResponder == true
            state.isChangeMetadataButtonEnabled = state.conversation?.metadata.requiresConsentFromInitiator == nil
            state.isPenPalsSharingDataSwitchToggled = state.conversation?.currentUserSharesPenPalsDataWithAllUsers == true
            state.segmentedControlSelectionIndex = 0

            viewService.viewAppeared()
            let getChatParticipantsTask: Effect<Action> = .task {
                do throws(Exception) {
                    return try await .getChatParticipantsReturned(
                        viewService.getChatParticipants()
                    )
                } catch {
                    return .getChatParticipantsFailed(error)
                }
            }

            return .task {
                do throws(Exception) {
                    return try await .resolveReturned(
                        translator.resolve(ChatInfoPageViewStrings.self)
                    )
                } catch {
                    return .resolveFailed(error)
                }
            }.merge(with: getChatParticipantsTask)

        case .addContactButtonTapped:
            navigation.navigate(to: .chat(.sheet(.contactSelector)))

        case let .cameraPickerDismissed(exception):
            navigation.navigate(to: .chat(.sheet(.none)))

            if let exception {
                Logger.log(
                    exception,
                    with: .toast
                )
            }

            if !Application.isInPrevaricationMode,
               !ThemeService.isDarkModeActive {
                StatusBar.overrideStyle(.darkContent)
            }

            state.isChangeMetadataButtonEnabled = true

        case let .changeMetadataActionSheetDismissed(.name(newMetadata)):
            guard let conversation = state.conversation else {
                state.isChangeMetadataButtonEnabled = true
                return .none
            }

            let name = newMetadata.name
            let action: Activity.Action = name.isBangQualifiedEmpty ? .removedName : .renamedConversation(name: name)

            return .task {
                do throws(Exception) {
                    try await viewService.updateMetadata(
                        conversation,
                        action: action,
                        newMetadata: newMetadata
                    )

                    return .updateMetadataReturned()
                } catch {
                    return .updateMetadataFailed(error)
                }
            }

        case let .changeMetadataActionSheetDismissed(.removePhoto(newMetadata)):
            guard let conversation = state.conversation else {
                state.isChangeMetadataButtonEnabled = true
                return .none
            }

            return .task {
                do throws(Exception) {
                    try await viewService.updateMetadata(
                        conversation,
                        action: .removedGroupPhoto,
                        newMetadata: newMetadata
                    )

                    return .updateMetadataReturned()
                } catch {
                    return .updateMetadataFailed(error)
                }
            }

        case .changeMetadataActionSheetDismissed(.none):
            state.isChangeMetadataButtonEnabled = true
            return .none

        case .changeMetadataActionSheetDismissed(.selectPhotoFromCamera):
            navigation.navigate(to: .chat(.sheet(.cameraPicker)))

        case .changeMetadataActionSheetDismissed(.selectPhotoFromLibrary):
            navigation.navigate(to: .chat(.sheet(.photoPicker)))

        case .changeMetadataButtonTapped:
            state.isChangeMetadataButtonEnabled = false
            return .task {
                let result = await viewService.presentChangeMetadataActionSheet()
                return .changeMetadataActionSheetDismissed(result)
            }

        case .chatInfoCellTapped:
            state.chatInfoCellViewID = UUID()
            state.visibleParticipants = state.visibleParticipants.isEmpty ? state.chatParticipants : []

        case .currentConversationMetadataChanged:
            state.viewID = UUID()

        case .doneHeaderItemTapped:
            RootSheets.dismiss()
            guard state.inputBarWasFirstResponder else { return .none }
            chatPageViewService.inputBar?.becomeFirstResponder()

        case let .getChatParticipantsFailed(exception):
            Logger.log(exception)
            state.viewState = .error(exception)

        case let .getChatParticipantsReturned(chatParticipants):
            state.chatParticipants = chatParticipants
            state.visibleParticipants = chatParticipants

            guard state.viewState == .loading else {
                state.viewID = UUID()
                chatPageViewService.reloadCollectionView()
                return .none
            }

            state.viewState = .loaded
            viewService.viewLoaded()

        case .leaveConversationButtonTapped:
            viewService.leaveConversationButtonTapped(state.conversation)

        case .loadingStateUpdated:
            state.viewState = .loading

        case let .mediaItemViewTapped(metadata):
            viewService.mediaItemViewTapped(
                metadata,
                filePaths: state.mediaItemMetadata.map(\.file.localPathURL.path),
                startingIndex: state.mediaItemMetadata.map(\.file).firstIndex(of: metadata.file) ?? 0
            )

        case let .penPalsSharingDataConfirmationActionSheetDismissed(userID):
            guard let conversation = state.conversation,
                  let userID else { return .none }
            return .task {
                do throws(Exception) {
                    _ = try await conversation.updatePenPalsSharingData(
                        sharingWith: [userID]
                    )

                    return .updateMetadataReturned(
                        togglePenPalsSharingDataSwitch: true
                    )
                } catch {
                    return .updateMetadataFailed(error)
                }
            }

        case let .penPalParticipantViewTapped(chatParticipant):
            guard let user = chatParticipant.firstUser else { return .none }

            if let penPalsStatus = chatParticipant.penPalsStatus,
               penPalsStatus == .currentUserSharesData {
                return .fireAndForget {
                    await viewService.showPenPalsSharingStatusToast(
                        user.id,
                        displayName: chatParticipant.displayName
                    )
                }
            }

            return .task {
                let result = await viewService.presentPenPalsSharingDataConfirmationActionSheet(
                    user.id,
                    displayName: chatParticipant.displayName
                )
                return .penPalsSharingDataConfirmationActionSheetDismissed(result)
            }

        case .penPalsSharingDataSwitchToggledOn:
            guard let otherUser = state.conversation?.users?.first else { return .none }
            return .task {
                let result = await viewService.presentPenPalsSharingDataConfirmationActionSheet(
                    otherUser.id,
                    displayName: otherUser.penPalsName
                )
                return .penPalsSharingDataConfirmationActionSheetDismissed(result)
            }

        case let .photoPickerDismissed(exception):
            navigation.navigate(to: .chat(.sheet(.none)))

            if let exception {
                Logger.log(
                    exception,
                    with: .toast
                )
            }

            if !Application.isInPrevaricationMode,
               !ThemeService.isDarkModeActive {
                StatusBar.overrideStyle(.darkContent)
            }

            state.isChangeMetadataButtonEnabled = true

        case let .removeUserButtonTapped(chatParticipant):
            viewService.removeUserButtonTapped(
                chatParticipant,
                conversation: state.conversation
            )

        case let .resolveFailed(exception):
            Logger.log(exception)

        case let .resolveReturned(strings):
            state.strings = strings
            state.segmentedControlViewID = UUID()

        case let .segmentedControlSelectionIndexChanged(segmentedControlSelectionIndex):
            state.segmentedControlSelectionIndex = segmentedControlSelectionIndex

        case let .selectedImageChanged(image):
            guard let conversation = state.conversation,
                  let imageData = image.dataCompressed(toKB: 100) else {
                Logger.log(
                    .init("Failed to compress image.", metadata: .init(sender: self)),
                    with: .toast
                )
                state.isChangeMetadataButtonEnabled = true
                return .none
            }

            return .task {
                do throws(Exception) {
                    try await viewService.updateMetadata(
                        conversation,
                        action: .changedGroupPhoto,
                        newMetadata: conversation.metadata.copyWith(imageData: imageData)
                    )

                    return .updateMetadataReturned()
                } catch {
                    return .updateMetadataFailed(error)
                }
            }

        case .traitCollectionChanged:
            viewService.traitCollectionChanged()

        case let .updateMetadataFailed(exception):
            Logger.log(
                exception,
                with: .toast
            )

            state.isChangeMetadataButtonEnabled = true

        case let .updateMetadataReturned(togglePenPalsDataSharingSwitch):
            let oldConversationIsPenPalsConversation = state.conversation?.metadata.isPenPalsConversation == true

            chatPageViewService.reloadCollectionView() // TODO: Audit why this didn't seem necessary before, but is now.
            currentConversationMetadataChanged.send()

            if let titleLabelText = state.cellViewData?.titleLabelText {
                chatPageViewService.setNavigationTitle(titleLabelText)
            }

            state.isChangeMetadataButtonEnabled = true
            state.isPenPalsSharingDataSwitchToggled = togglePenPalsDataSharingSwitch
            state.viewID = UUID()

            guard oldConversationIsPenPalsConversation else { return .none }
            return .task {
                do throws(Exception) {
                    return try await .getChatParticipantsReturned(
                        viewService.getChatParticipants()
                    )
                } catch {
                    return .getChatParticipantsFailed(error)
                }
            }

        case let .userInfoBadgeTapped(user):
            guard let user else { return .none }
            conversationCellViewService.presentUserInfoAlert(user)

        case .viewDisappeared:
            NavigationBar.setAppearance(.chatPageView)
        }

        return .none
    } // swiftlint:enable cyclomatic_complexity function_body_length
}

private extension [TranslationOutputMap] {
    func value(for key: TranslatedLabelStringCollection.ChatInfoPageViewStringKey) -> String {
        (first(where: { $0.key == .chatInfoPageView(key) })?.value ?? key.rawValue).sanitized
    }
}

// swiftlint:enable file_length type_body_length
