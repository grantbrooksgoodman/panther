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

struct ChatInfoPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.conversationCellViewService) private var conversationCellViewService: ConversationCellViewService
    @Dependency(\.clientSession.conversation) private var conversationSession: ConversationSessionService
    @Dependency(\.build.isDeveloperModeEnabled) private var isDeveloperModeEnabled: Bool
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.chatInfoPageViewService) private var viewService: ChatInfoPageViewService

    // MARK: - Actions

    enum Action { // TODO: Make all models Sendable where possible. Good preparation for Swift 6 language mode.
        case viewAppeared
        case viewDisappeared

        case addContactButtonTapped

        case cameraPickerDismissed(Exception?)
        case changeMetadataActionSheetDismissed(ChatInfoPageViewService.MetadataChangeType?)
        case changeMetadataButtonTapped
        case chatInfoCellTapped
        case currentConversationMetadataChanged

        case doneHeaderItemTapped
        case doneToolbarButtonTapped

        case getChatParticipantsReturned(Callback<[ChatParticipant], Exception>)

        case leaveConversationButtonTapped
        case loadingStateUpdated

        case mediaItemViewTapped(MediaItemView.Metadata)

        case penPalParticipantViewTapped(ChatParticipant) // swiftlint:disable:next identifier_name
        case penPalsSharingDataConfirmationActionSheetDismissed(ConversationMetadata?)
        case penPalsSharingDataSwitchToggledOn
        case photoPickerDismissed(Exception?)

        case removeUserButtonTapped(ChatParticipant)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)

        case segmentedControlSelectionIndexChanged(Int)
        case selectedImageChanged(UIImage)

        case traitCollectionChanged

        case updateMetadataReturned(Callback<Conversation, Exception>, togglePenPalsSharingDataSwitch: Bool = false)
        case userInfoBadgeTapped(User?)
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Properties */

        var chatInfoCellViewID = UUID()
        var chatParticipants = [ChatParticipant]()
        @Localized(.done) var doneButtonText: String
        var isChangeMetadataButtonEnabled = true
        var isLeaveConversationButtonEnabled = true
        var isPenPalsSharingDataSwitchToggled = false
        var segmentedControlSelectionIndex = 0
        var segmentedControlViewID = UUID()
        var strings: [TranslationOutputMap] = ChatInfoPageViewStrings.defaultOutputMap
        var viewID = UUID()
        var viewState: StatefulView.ViewState = .loading
        var visibleParticipants = [ChatParticipant]()

        fileprivate var inputBarWasFirstResponder = false

        /* MARK: Computed Properties */

        var avatarImage: UIImage? { cellViewData?.thumbnailImage }

        var chatInfoCellImageSystemName: String {
            "chevron.\(visibleParticipants.isEmpty ? "right" : "down").circle"
        }

        var chatInfoCellSubtitleLabelText: String {
            chatParticipants.map { $0.displayName }.joined(separator: ", ")
        }

        var chatInfoCellTitleLabelText: String {
            "\(chatParticipants.count) \(strings.value(for: .participantCountLabelText))"
        }

        var chatTitleLabelText: String {
            guard let cellViewData else { return "" }
            return cellViewData.titleLabelText
        }

        var isDeveloperModeEnabled: Bool {
            @Dependency(\.build) var build: Build
            return build.isDeveloperModeEnabled
        }

        var mediaItemMetadata: [MediaItemView.Metadata] {
            conversation?
                .withMessagesOffsetFromCurrentUserAdditionDate
                .mediaItemMetadata ?? []
        }

        var segmentedControlMaxWidth: CGFloat {
            Dependency(\.uiApplication.mainScreen.bounds.width).wrappedValue * (2 / 3)
        }

        var segmentedControlOptionTitles: [String] {
            [
                strings.value(for: .segmentedControlParticipantsOptionText),
                strings.value(for: .segmentedControlMediaOptionText),
            ]
        }

        var shouldElongateSegmentedControl: Bool {
            RuntimeStorage.languageCode != "en" && segmentedControlOptionTitles
                .contains(where: { $0.count >= 25 || $0.components(separatedBy: " ").count > 2 })
        }

        var showsChangeMetadataButton: Bool {
            conversation?.metadata.isPenPalsConversation == false
        }

        var showsPenPalsSharingDataSwitch: Bool {
            conversation?.metadata.isPenPalsConversation == true && conversation?.participants.count == 2
        }

        var showsRemoveUserSwipeAction: Bool {
            // TODO: Remove the dependency on isDeveloperModeEnabled.
            guard conversation?.metadata.isPenPalsConversation == false || isDeveloperModeEnabled,
                  conversation?.metadata.requiresConsentFromInitiator == nil,
                  visibleParticipants.count > 2 else { return false }
            return true
        }

        var singleCNContactContainer: CNContactContainer? {
            guard chatParticipants.count == 1,
                  conversation?.metadata.isPenPalsConversation == false else { return nil }
            return chatParticipants.first?.cnContactContainer
        }

        var visibleParticipantsIncrement: Int {
            // TODO: Remove the dependency on isDeveloperModeEnabled.
            guard conversation?.metadata.isPenPalsConversation == false || isDeveloperModeEnabled,
                  conversation?.metadata.requiresConsentFromInitiator == nil,
                  !visibleParticipants.isEmpty,
                  visibleParticipants.count < 10 else { return 0 }
            return 1
        }

        fileprivate var cellViewData: ConversationCellViewData? {
            guard let conversation else { return nil }
            return .init(conversation)
        }

        fileprivate var conversation: Conversation? {
            @Dependency(\.clientSession.conversation.fullConversation) var currentConversation: Conversation?
            return currentConversation
        }
    }

    // MARK: - Reduce

    // swiftlint:disable:next function_body_length
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading
            state.inputBarWasFirstResponder = chatPageViewService.inputBar?.isFirstResponder == true
            state.isChangeMetadataButtonEnabled = state.conversation?.metadata.requiresConsentFromInitiator == nil
            state.isPenPalsSharingDataSwitchToggled = state.conversation?.currentUserSharesPenPalsDataWithAllUsers == true
            state.segmentedControlSelectionIndex = 0

            viewService.viewAppeared()
            let getChatParticipantsTask: Effect<Action> = .task {
                let result = await viewService.getChatParticipants()
                return .getChatParticipantsReturned(result)
            }

            return .task {
                let result = await translator.resolve(ChatInfoPageViewStrings.self)
                return .resolveReturned(result)
            }.merge(with: getChatParticipantsTask)

        case .addContactButtonTapped:
            navigation.navigate(to: .chat(.sheet(.contactSelector)))

        case let .cameraPickerDismissed(exception):
            navigation.navigate(to: .chat(.sheet(.none)))

            if let exception {
                Logger.log(exception, with: .toast)
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
            let action: Activity.Action = name.isBangQualifiedEmpty ? .removedName : .renamedConversation(
                name: name.removingOccurrences(of: [":"])
            )

            return .task {
                let result = await viewService.updateMetadata(
                    conversation,
                    action: action,
                    newMetadata: newMetadata
                )
                return .updateMetadataReturned(result)
            }

        case let .changeMetadataActionSheetDismissed(.removePhoto(newMetadata)):
            guard let conversation = state.conversation else {
                state.isChangeMetadataButtonEnabled = true
                return .none
            }

            return .task {
                let result = await viewService.updateMetadata(
                    conversation,
                    action: .removedGroupPhoto,
                    newMetadata: newMetadata
                )
                return .updateMetadataReturned(result)
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

        case .doneHeaderItemTapped,
             .doneToolbarButtonTapped:
            RootSheets.dismiss()
            guard state.inputBarWasFirstResponder else { return .none }
            chatPageViewService.inputBar?.becomeFirstResponder()

        case let .getChatParticipantsReturned(.success(chatParticipants)):
            state.chatParticipants = chatParticipants
            state.visibleParticipants = chatParticipants
            state.isLeaveConversationButtonEnabled = chatParticipants.count > 2

            guard state.viewState == .loading else {
                state.viewID = UUID()
                chatPageViewService.reloadCollectionView()
                return .none
            }

            state.viewState = .loaded
            viewService.viewLoaded()

        case let .getChatParticipantsReturned(.failure(exception)):
            Logger.log(exception)
            state.viewState = .error(exception)

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

        case let .penPalsSharingDataConfirmationActionSheetDismissed(newMetadata):
            guard let conversation = state.conversation,
                  let newMetadata else { return .none }
            return .task {
                let result = await conversation.updateValue(newMetadata, forKey: .metadata)
                return .updateMetadataReturned(result, togglePenPalsSharingDataSwitch: true)
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
                Logger.log(exception, with: .toast)
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

        case let .resolveReturned(.success(strings)):
            state.strings = strings
            state.segmentedControlViewID = UUID()

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception)

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
                let result = await viewService.updateMetadata(
                    conversation,
                    action: .changedGroupPhoto,
                    newMetadata: conversation.metadata.copyWith(imageData: imageData)
                )
                return .updateMetadataReturned(result)
            }

        case .traitCollectionChanged:
            viewService.traitCollectionChanged()

        case let .updateMetadataReturned(.success(conversation), togglePenPalsDataSharingSwitch):
            let oldConversationIsPenPalsConversation = state.conversation?.metadata.isPenPalsConversation == true

            conversationSession.setCurrentConversation(conversation)
            chatPageViewService.reloadCollectionView() // TODO: Audit why this didn't seem necessary before, but is now.

            if let titleLabelText = state.cellViewData?.titleLabelText {
                chatPageViewService.setNavigationTitle(titleLabelText)
            }

            state.isChangeMetadataButtonEnabled = true
            state.isPenPalsSharingDataSwitchToggled = togglePenPalsDataSharingSwitch
            state.viewID = UUID()

            guard oldConversationIsPenPalsConversation else { return .none }
            return .task {
                let result = await viewService.getChatParticipants()
                return .getChatParticipantsReturned(result)
            }

        case let .updateMetadataReturned(.failure(exception), _):
            Logger.log(exception, with: .toast)
            state.isChangeMetadataButtonEnabled = true

        case let .userInfoBadgeTapped(user):
            guard let user else { return .none }
            conversationCellViewService.presentUserInfoAlert(.init(user: user))

        case .viewDisappeared:
            NavigationBar.setAppearance(.chatPageView)
        }

        return .none
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.ChatInfoPageViewStringKey) -> String {
        (first(where: { $0.key == .chatInfoPageView(key) })?.value ?? key.rawValue).sanitized
    }
}

// swiftlint:enable file_length type_body_length
