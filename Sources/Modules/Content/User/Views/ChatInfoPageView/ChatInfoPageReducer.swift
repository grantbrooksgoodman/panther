//
//  ChatInfoPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

// swiftlint:disable:next type_body_length
public struct ChatInfoPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession.conversation) private var conversationSession: ConversationSessionService
    @Dependency(\.networking.translationService) private var translator: HostedTranslationService
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.chatInfoPageViewService) private var viewService: ChatInfoPageViewService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case addContactButtonTapped
        case changeMetadataButtonTapped
        case chatInfoCellTapped
        case currentConversationMetadataChanged
        case penPalsSharingDataSwitchToggledOn

        case doneHeaderItemTapped
        case doneToolbarButtonTapped

        case changeMetadataActionSheetDismissed(ChatInfoPageViewService.MetadataChangeType?)
        case getChatParticipantsReturned(Callback<[ChatParticipant], Exception>)
        case isPresentingCameraPickerSheetChanged(Bool, Exception?)
        case isPresentingImagePickerSheetChanged(Bool, Exception?) // swiftlint:disable:next identifier_name
        case penPalsSharingDataConfirmationActionSheetDismissed(Bool)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
        case selectedImageChanged(UIImage)
        case updateValueReturned(Callback<Conversation, Exception>, togglePenPalsSharingDataSwitch: Bool = false)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Types */

        public enum ViewState: Equatable {
            case loading
            case error(Exception)
            case loaded
        }

        /* MARK: Properties */

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

        // Other
        @Localized(.done) public var doneButtonText: String
        public var viewState: ViewState = .loading
        public var viewID = UUID()

        /* MARK: Computed Properties */

        public var avatarImage: UIImage? { cellViewData?.thumbnailImage }

        public var cellViewData: ConversationCellViewData? {
            guard let conversation,
                  let cellViewData: ConversationCellViewData = .init(conversation) else { return nil }
            return cellViewData
        }

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

        public var conversation: Conversation? {
            @Dependency(\.clientSession.conversation.fullConversation) var currentConversation: Conversation?
            return currentConversation
        }

        public var singleCNContactContainer: CNContactContainer? {
            guard chatParticipants.count == 1,
                  conversation?.metadata.isPenPalsConversation == false else { return nil }
            return chatParticipants.first?.cnContactContainer
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
            state.inputBarWasFirstResponder = chatPageViewService.inputBar?.isFirstResponder ?? false
            state.isPenPalsSharingDataSwitchToggled = state.conversation?.isCurrentUserSharingPenPalsData ?? false
            uiApplication.resignFirstResponders()

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

        case let .changeMetadataActionSheetDismissed(.name(name)):
            guard let conversation = state.conversation,
                  name != conversation.metadata.name,
                  !(name.isBangQualifiedEmpty && conversation.metadata.name.isBangQualifiedEmpty) else {
                state.isChangeMetadataButtonEnabled = true
                return .none
            }

            let sanitizedName = name.isBangQualifiedEmpty ? .bangQualifiedEmpty : name
            let newMetadata: ConversationMetadata = .init(
                name: sanitizedName.trimmingBorderedWhitespace,
                imageData: conversation.metadata.imageData,
                isPenPalsConversation: conversation.metadata.isPenPalsConversation,
                lastModifiedDate: conversation.metadata.lastModifiedDate,
                penPalsSharingData: conversation.metadata.penPalsSharingData
            )

            return .task {
                let result = await conversation.updateValue(newMetadata, forKey: .metadata)
                return .updateValueReturned(result)
            }

        case .changeMetadataActionSheetDismissed(.removePhoto):
            guard let conversation = state.conversation else {
                state.isChangeMetadataButtonEnabled = true
                return .none
            }

            let newMetadata: ConversationMetadata = .init(
                name: conversation.metadata.name,
                imageData: nil,
                isPenPalsConversation: conversation.metadata.isPenPalsConversation,
                lastModifiedDate: conversation.metadata.lastModifiedDate,
                penPalsSharingData: conversation.metadata.penPalsSharingData
            )

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
            state.viewState = .loaded

        case let .getChatParticipantsReturned(.failure(exception)):
            Logger.log(exception)
            state.viewState = .error(exception)

        case let .isPresentingCameraPickerSheetChanged(isPresentingCameraPickerSheet, exception):
            if let exception {
                Logger.log(exception, with: .toast())
            }
            state.isPresentingCameraPickerSheet = isPresentingCameraPickerSheet

            if !Application.isInPrevaricationMode,
               !isPresentingCameraPickerSheet,
               !ThemeService.isDarkModeActive {
                StatusBarStyle.override(.darkContent)
            }
            state.isChangeMetadataButtonEnabled = true

        case let .isPresentingImagePickerSheetChanged(isPresentingImagePickerSheet, exception):
            if let exception {
                Logger.log(exception, with: .toast())
            }
            state.isPresentingImagePickerSheet = isPresentingImagePickerSheet

            if !Application.isInPrevaricationMode,
               !isPresentingImagePickerSheet,
               !ThemeService.isDarkModeActive {
                StatusBarStyle.override(.darkContent)
            }
            state.isChangeMetadataButtonEnabled = true

        case let .penPalsSharingDataConfirmationActionSheetDismissed(confirmed):
            @Persistent(.currentUserID) var currentUserID: String?
            guard confirmed,
                  let conversation = state.conversation,
                  let currentUserID else { return .none }

            var newPenPalsSharingData = conversation.metadata.penPalsSharingData.filter { $0.userID != currentUserID }
            newPenPalsSharingData.append(.init(userID: currentUserID, isSharingPenPalsData: true))

            var newMetadata: ConversationMetadata?
            if newPenPalsSharingData.allSatisfy(\.isSharingPenPalsData) {
                newMetadata = .init(
                    name: conversation.metadata.name,
                    imageData: conversation.metadata.imageData,
                    isPenPalsConversation: false,
                    lastModifiedDate: conversation.metadata.lastModifiedDate,
                    penPalsSharingData: newPenPalsSharingData.reduce(into: [PenPalsSharingData]()) { partialResult, data in
                        partialResult.append(.init(userID: data.userID, isSharingPenPalsData: false))
                    }
                )
            } else {
                newMetadata = .init(
                    name: conversation.metadata.name,
                    imageData: conversation.metadata.imageData,
                    isPenPalsConversation: conversation.metadata.isPenPalsConversation,
                    lastModifiedDate: conversation.metadata.lastModifiedDate,
                    penPalsSharingData: newPenPalsSharingData
                )
            }

            guard let newMetadata else { return .none }
            return .task {
                let result = await conversation.updateValue(newMetadata, forKey: .metadata)
                return .updateValueReturned(result, togglePenPalsSharingDataSwitch: true)
            }

        case .penPalsSharingDataSwitchToggledOn:
            return .task {
                let result = await viewService.presentPenPalsSharingDataConfirmationActionSheet()
                return .penPalsSharingDataConfirmationActionSheetDismissed(result)
            }

        case let .resolveReturned(.success(strings)):
            state.strings = strings

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception)

        case let .selectedImageChanged(image):
            guard let conversation = state.conversation,
                  let imageData = image.dataCompressed(toKB: 100) else {
                Logger.log(
                    .init("Failed to compress image.", metadata: [self, #file, #function, #line]),
                    with: .toast()
                )
                state.isChangeMetadataButtonEnabled = true
                return .none
            }

            let newMetadata: ConversationMetadata = .init(
                name: conversation.metadata.name,
                imageData: imageData,
                isPenPalsConversation: conversation.metadata.isPenPalsConversation,
                lastModifiedDate: conversation.metadata.lastModifiedDate,
                penPalsSharingData: conversation.metadata.penPalsSharingData
            )

            return .task {
                let result = await conversation.updateValue(newMetadata, forKey: .metadata)
                return .updateValueReturned(result)
            }

        case let .updateValueReturned(.success(conversation), togglePenPalsDataSharingSwitch):
            conversationSession.setCurrentConversation(conversation)
            if let titleLabelText = state.cellViewData?.titleLabelText {
                chatPageViewService.setNavigationTitle(titleLabelText)
            }
            state.isChangeMetadataButtonEnabled = true
            state.isPenPalsSharingDataSwitchToggled = togglePenPalsDataSharingSwitch
            state.viewID = UUID()

        case let .updateValueReturned(.failure(exception), _):
            Logger.log(exception, with: .toast())
            state.isChangeMetadataButtonEnabled = true
        }

        return .none
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.ChatInfoPageViewStringKey) -> String {
        (first(where: { $0.key == .chatInfoPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
