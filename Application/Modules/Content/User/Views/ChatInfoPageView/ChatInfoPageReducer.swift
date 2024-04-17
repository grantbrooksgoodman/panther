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

/* 3rd-party */
import Redux

public struct ChatInfoPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession.conversation) private var conversationSession: ConversationSessionService
    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.networking.services.translation) private var translator: HostedTranslationService
    @Dependency(\.chatInfoPageViewService) private var viewService: ChatInfoPageViewService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case changeMetadataButtonTapped
        case chatInfoCellTapped

        case doneHeaderItemTapped
        case doneToolbarButtonTapped

        case isPresentingCameraPickerSheetChanged(Bool, Exception?)
        case isPresentingImagePickerSheetChanged(Bool, Exception?)
        case selectedImageChanged(UIImage)
    }

    // MARK: - Feedback

    public enum Feedback {
        case changeMetadataActionSheetDismissed(ChatInfoPageViewService.MetadataChangeType?)
        case getChatParticipantsReturned(Callback<[ChatParticipant], Exception>)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
        case updateValueReturned(Callback<Conversation, Exception>)
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
        public var isChangeMetadataButtonEnabled = true
        public var isPresentingCameraPickerSheet = false
        public var isPresentingImagePickerSheet = false

        // Other
        @Localized(.done) public var doneButtonText: String
        public var preferredStatusBarStyle: UIStatusBarStyle = .lightContent
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
            guard chatParticipants.count == 1 else { return nil }
            return chatParticipants.first?.cnContactContainer
        }

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Init

    public init() { RuntimeStorage.store(#file, as: .presentedViewName) }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case let .action(action):
            return reduce(into: &state, for: action)

        case let .feedback(feedback):
            return reduce(into: &state, for: feedback)
        }
    }

    // MARK: - Reduce Action

    private func reduce(into state: inout State, for action: Action) -> Effect<Feedback> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading
            state.inputBarWasFirstResponder = chatPageViewService.inputBar?.isFirstResponder ?? false
            coreUI.resignFirstResponder()

            let getChatParticipantsTask: Effect<Feedback> = .task {
                let result = await viewService.getChatParticipants()
                return .getChatParticipantsReturned(result)
            }

            return .task {
                let result = await translator.resolve(ChatInfoPageViewStrings.self)
                return .resolveReturned(result)
            }.merge(with: getChatParticipantsTask)

        case .changeMetadataButtonTapped:
            state.isChangeMetadataButtonEnabled = false
            return .task {
                let result = await viewService.presentChangeMetadataActionSheet()
                return .changeMetadataActionSheetDismissed(result)
            }

        case .chatInfoCellTapped:
            state.visibleParticipants = state.visibleParticipants.isEmpty ? state.chatParticipants : []

        case .doneHeaderItemTapped,
             .doneToolbarButtonTapped:
            RootSheets.dismiss()
            guard state.inputBarWasFirstResponder else { return .none }
            chatPageViewService.inputBar?.becomeFirstResponder()

        case let .isPresentingCameraPickerSheetChanged(isPresentingCameraPickerSheet, exception):
            if let exception {
                Logger.log(exception, with: .toast())
            }
            state.isPresentingCameraPickerSheet = isPresentingCameraPickerSheet

            if !isPresentingCameraPickerSheet,
               !ThemeService.isDarkModeActive {
                state.preferredStatusBarStyle = .darkContent
            }
            state.isChangeMetadataButtonEnabled = true

        case let .isPresentingImagePickerSheetChanged(isPresentingImagePickerSheet, exception):
            if let exception {
                Logger.log(exception, with: .toast())
            }
            state.isPresentingImagePickerSheet = isPresentingImagePickerSheet

            if !isPresentingImagePickerSheet,
               !ThemeService.isDarkModeActive {
                state.preferredStatusBarStyle = .darkContent
            }
            state.isChangeMetadataButtonEnabled = true

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
                lastModifiedDate: conversation.metadata.lastModifiedDate
            )

            return .task {
                let result = await conversation.updateValue(newMetadata, forKey: .metadata)
                return .updateValueReturned(result)
            }
        }

        return .none
    }

    // MARK: - Reduce Feedback

    private func reduce(into state: inout State, for feedback: Feedback) -> Effect<Feedback> {
        switch feedback {
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
                lastModifiedDate: conversation.metadata.lastModifiedDate
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
                lastModifiedDate: conversation.metadata.lastModifiedDate
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

        case let .getChatParticipantsReturned(.success(chatParticipants)):
            state.chatParticipants = chatParticipants
            state.visibleParticipants = chatParticipants
            state.viewState = .loaded

        case let .getChatParticipantsReturned(.failure(exception)):
            Logger.log(exception)
            state.viewState = .error(exception)

        case let .resolveReturned(.success(strings)):
            state.strings = strings

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception)

        case let .updateValueReturned(.success(conversation)):
            conversationSession.setCurrentConversation(conversation)
            if let titleLabelText = state.cellViewData?.titleLabelText {
                chatPageViewService.setNavigationTitle(titleLabelText)
            }
            state.isChangeMetadataButtonEnabled = true
            state.viewID = UUID()

        case let .updateValueReturned(.failure(exception)):
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
