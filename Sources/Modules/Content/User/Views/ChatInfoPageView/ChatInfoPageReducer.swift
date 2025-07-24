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

public struct ChatInfoPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.conversationCellViewService) private var conversationCellViewService: ConversationCellViewService
    @Dependency(\.clientSession.conversation) private var conversationSession: ConversationSessionService
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.chatInfoPageViewService) private var viewService: ChatInfoPageViewService

    // MARK: - Properties

    private var uiSegmentBackgroundViews: [UIView] {
        uiApplication
            .presentedViews
            .filter { String(type(of: $0)) == "UISegment" }
            .compactMap(\.superview?.superview)
    }

    // MARK: - Actions

    public enum Action {
        case viewAppeared
        case viewDisappeared

        case addContactButtonTapped
        case changeMetadataButtonTapped
        case chatInfoCellTapped
        case currentConversationMetadataChanged
        case mediaItemViewTapped(MediaItemView.Metadata)
        case penPalsSharingDataSwitchToggledOn
        case userInfoBadgeTapped(User?)

        case doneHeaderItemTapped
        case doneToolbarButtonTapped
        case penPalParticipantViewTapped(ChatParticipant)
        case segmentedControlSelectionIndexChanged(Int)
        case traitCollectionChanged

        case changeMetadataActionSheetDismissed(ChatInfoPageViewService.MetadataChangeType?)
        case getChatParticipantsReturned(Callback<[ChatParticipant], Exception>)
        case isPresentingCameraPickerSheetChanged(Bool, Exception?)
        case isPresentingImagePickerSheetChanged(Bool, Exception?) // swiftlint:disable:next identifier_name
        case penPalsSharingDataConfirmationActionSheetDismissed(ConversationMetadata?)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
        case selectedImageChanged(UIImage)
        case updateValueReturned(Callback<Conversation, Exception>, togglePenPalsSharingDataSwitch: Bool = false)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        public var segmentedControlSelectionIndex = 0

        // Array
        public var chatParticipants = [ChatParticipant]()
        public var strings: [TranslationOutputMap] = ChatInfoPageViewStrings.defaultOutputMap
        public var visibleParticipants = [ChatParticipant]()

        // Bool
        public var inputBarWasFirstResponder = false
        public var isAddContactButtonEnabled = true
        public var isChangeMetadataButtonEnabled = true
        public var isPenPalsSharingDataSwitchToggled = false
        public var isPresentingCameraPickerSheet = false
        public var isPresentingImagePickerSheet = false

        // UUID
        public var chatInfoCellViewID = UUID()
        public var segmentedControlViewID = UUID()
        public var viewID = UUID()

        // Other
        @Localized(.done) public var doneButtonText: String
        public var viewState: StatefulView.ViewState = .loading

        /* MARK: Computed Properties */

        public var avatarImage: UIImage? { cellViewData?.thumbnailImage }

        public var chatInfoCellImageSystemName: String {
            "chevron.\(visibleParticipants.isEmpty ? "right" : "down").circle"
        }

        public var chatInfoCellSubtitleLabelText: String {
            chatParticipants.map { $0.displayName }.joined(separator: ", ")
        }

        public var chatInfoCellTitleLabelText: String {
            "\(chatParticipants.count) \(strings.value(for: .participantCountLabelText))"
        }

        public var chatTitleLabelText: String {
            guard let cellViewData else { return "" }
            return cellViewData.titleLabelText
        }

        public var isDeveloperModeEnabled: Bool {
            @Dependency(\.build) var build: Build
            return build.isDeveloperModeEnabled
        }

        public var mediaItemMetadata: [MediaItemView.Metadata] {
            conversation?.mediaItemMetadata ?? []
        }

        public var segmentedControlMaxWidth: CGFloat {
            Dependency(\.uiApplication.mainScreen.bounds.width).wrappedValue * (2 / 3)
        }

        public var segmentedControlOptionTitles: [String] {
            [
                strings.value(for: .segmentedControlParticipantsOptionText),
                strings.value(for: .segmentedControlMediaOptionText),
            ]
        }

        public var shouldElongateSegmentedControl: Bool {
            RuntimeStorage.languageCode != "en" && segmentedControlOptionTitles
                .contains(where: { $0.count >= 25 || $0.components(separatedBy: " ").count > 2 })
        }

        public var showsChangeMetadataButton: Bool {
            conversation?.metadata.isPenPalsConversation == false
        }

        public var showsPenPalsSharingDataSwitch: Bool {
            conversation?.metadata.isPenPalsConversation == true && conversation?.participants.count == 2
        }

        public var singleCNContactContainer: CNContactContainer? {
            guard chatParticipants.count == 1,
                  conversation?.metadata.isPenPalsConversation == false else { return nil }
            return chatParticipants.first?.cnContactContainer
        }

        fileprivate var cellViewData: ConversationCellViewData? {
            guard let conversation,
                  let cellViewData: ConversationCellViewData = .init(conversation) else { return nil }
            return cellViewData
        }

        fileprivate var conversation: Conversation? {
            @Dependency(\.clientSession.conversation.fullConversation) var currentConversation: Conversation?
            return currentConversation
        }

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    // swiftlint:disable:next function_body_length
    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading
            state.inputBarWasFirstResponder = chatPageViewService.inputBar?.isFirstResponder == true
            state.isChangeMetadataButtonEnabled = state.conversation?.metadata.requiresConsentFromInitiator == nil
            state.isPenPalsSharingDataSwitchToggled = state.conversation?.currentUserSharesPenPalsDataWithAllUsers == true
            state.segmentedControlSelectionIndex = 0

            uiApplication.resignFirstResponders()
            UISegmentedControl.appearance().apportionsSegmentWidthsByContent = true

            let getChatParticipantsTask: Effect<Action> = .task {
                let result = await viewService.getChatParticipants()
                return .getChatParticipantsReturned(result)
            }

            return .task {
                let result = await translator.resolve(ChatInfoPageViewStrings.self)
                return .resolveReturned(result)
            }.merge(with: getChatParticipantsTask)

        case .addContactButtonTapped:
            break

        case let .changeMetadataActionSheetDismissed(.name(newMetadata)):
            guard let conversation = state.conversation else {
                state.isChangeMetadataButtonEnabled = true
                return .none
            }

            return .task {
                let result = await conversation.updateValue(newMetadata, forKey: .metadata)
                return .updateValueReturned(result)
            }

        case let .changeMetadataActionSheetDismissed(.removePhoto(newMetadata)):
            guard let conversation = state.conversation else {
                state.isChangeMetadataButtonEnabled = true
                return .none
            }

            return .task {
                let result = await conversation.updateValue(newMetadata, forKey: .metadata)
                return .updateValueReturned(result)
            }

        case .changeMetadataActionSheetDismissed(.none):
            state.isChangeMetadataButtonEnabled = true
            return .none

        case .changeMetadataActionSheetDismissed(.selectPhotoFromCamera):
            state.isPresentingCameraPickerSheet = true

        case .changeMetadataActionSheetDismissed(.selectPhotoFromLibrary):
            state.isPresentingImagePickerSheet = true

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
            state.isAddContactButtonEnabled = chatParticipants.count <= 9

            guard state.viewState == .loading else {
                state.viewID = UUID()
                chatPageViewService.reloadCollectionView()
                return .none
            }

            state.viewState = .loaded
            return .task(delay: .seconds(1)) { @MainActor in
                uiSegmentBackgroundViews.forEach { $0.backgroundColor = .groupedContentBackground }
                return .none
            }

        case let .getChatParticipantsReturned(.failure(exception)):
            Logger.log(exception)
            state.viewState = .error(exception)

        case let .isPresentingCameraPickerSheetChanged(isPresentingCameraPickerSheet, exception):
            if let exception {
                Logger.log(exception, with: .toast)
            }
            state.isPresentingCameraPickerSheet = isPresentingCameraPickerSheet

            if !Application.isInPrevaricationMode,
               !isPresentingCameraPickerSheet,
               !ThemeService.isDarkModeActive {
                StatusBar.overrideStyle(.darkContent)
            }
            state.isChangeMetadataButtonEnabled = true

        case let .isPresentingImagePickerSheetChanged(isPresentingImagePickerSheet, exception):
            if let exception {
                Logger.log(exception, with: .toast)
            }
            state.isPresentingImagePickerSheet = isPresentingImagePickerSheet

            if !Application.isInPrevaricationMode,
               !isPresentingImagePickerSheet,
               !ThemeService.isDarkModeActive {
                StatusBar.overrideStyle(.darkContent)
            }
            state.isChangeMetadataButtonEnabled = true

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
                return .updateValueReturned(result, togglePenPalsSharingDataSwitch: true)
            }

        case let .penPalParticipantViewTapped(chatParticipant):
            guard let user = chatParticipant.firstUser else { return .none }

            if let penPalsStatus = chatParticipant.penPalsStatus,
               penPalsStatus == .currentUserSharesData {
                return .task {
                    await viewService.showPenPalsSharingStatusToast(
                        user.id,
                        displayName: chatParticipant.displayName
                    )
                    return .none
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
                    .init("Failed to compress image.", metadata: [self, #file, #function, #line]),
                    with: .toast
                )
                state.isChangeMetadataButtonEnabled = true
                return .none
            }

            let newMetadata: ConversationMetadata = .init(
                name: conversation.metadata.name,
                imageData: imageData,
                isPenPalsConversation: conversation.metadata.isPenPalsConversation,
                lastModifiedDate: conversation.metadata.lastModifiedDate,
                messageRecipientConsentAcknowledgementData: conversation.metadata.messageRecipientConsentAcknowledgementData,
                penPalsSharingData: conversation.metadata.penPalsSharingData,
                requiresConsentFromInitiator: conversation.metadata.requiresConsentFromInitiator
            )

            return .task {
                let result = await conversation.updateValue(newMetadata, forKey: .metadata)
                return .updateValueReturned(result)
            }

        case .traitCollectionChanged:
            return .task(delay: .milliseconds(100)) { @MainActor in
                NavigationBar.setAppearance(Application.isInPrevaricationMode ? .appDefault : .default())
                uiSegmentBackgroundViews.forEach { $0.backgroundColor = .groupedContentBackground }
                return .none
            }

        case let .updateValueReturned(.success(conversation), togglePenPalsDataSharingSwitch):
            let oldConversationIsPenPalsConversation = state.conversation?.metadata.isPenPalsConversation == true

            conversationSession.setCurrentConversation(conversation)
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

        case let .updateValueReturned(.failure(exception), _):
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
