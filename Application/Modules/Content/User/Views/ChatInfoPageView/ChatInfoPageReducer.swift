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
    @Dependency(\.chatInfoPageViewService) private var viewService: ChatInfoPageViewService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case changeNameButtonTapped

        case doneToolbarButtonTapped
        case traitCollectionChanged
    }

    // MARK: - Feedback

    public enum Feedback {
        case changeNameAlertDismissed(input: String?)
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

        // Bool
        public var inputBarWasFirstResponder = false
        public var isChangeNameButtonEnabled = true

        // Other
        @Localized(.done) public var doneToolbarButtonText: String
        public var viewState: ViewState = .loading
        public var viewID = UUID()

        /* MARK: Computed Properties */

        public var avatarImage: UIImage? { cellViewData?.contactImage }

        public var cellViewData: ConversationCellViewData? {
            guard let conversation,
                  let cellViewData: ConversationCellViewData = .init(conversation) else { return nil }
            return cellViewData
        }

        public var chatTitleLabelText: String {
            guard let cellViewData else { return "" }
            return cellViewData.titleLabelText
        }

        public var conversation: Conversation? {
            @Dependency(\.clientSession.conversation.fullConversation) var currentConversation: Conversation?
            return currentConversation
        }

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Init

    public init() { RuntimeStorage.store(#file, as: .presentedViewName) }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.viewAppeared):
            state.viewState = .loaded
            state.inputBarWasFirstResponder = chatPageViewService.inputBar?.isFirstResponder ?? false
            coreUI.resignFirstResponder()

        case .action(.changeNameButtonTapped):
            state.isChangeNameButtonEnabled = false
            return .task {
                let result = await viewService.presentChangeNameAlert()
                return .changeNameAlertDismissed(input: result)
            }

        case .action(.doneToolbarButtonTapped):
            RootSheets.dismiss()
            guard state.inputBarWasFirstResponder else { return .none }
            chatPageViewService.inputBar?.becomeFirstResponder()

        case .action(.traitCollectionChanged):
            coreUI.setNavigationBarAppearance()

        case let .feedback(.changeNameAlertDismissed(input: input)):
            guard let input,
                  let conversation = state.conversation,
                  input != conversation.name else {
                state.isChangeNameButtonEnabled = true
                return .none
            }

            let sanitizedInput = input.isBangQualifiedEmpty ? .bangQualifiedEmpty : input
            return .task {
                let result = await conversation.updateValue(sanitizedInput.trimmingBorderedWhitespace, forKey: .name)
                return .updateValueReturned(result)
            }

        case let .feedback(.updateValueReturned(.success(conversation))):
            conversationSession.setCurrentConversation(conversation)
            if let titleLabelText = state.cellViewData?.titleLabelText {
                chatPageViewService.setNavigationTitle(titleLabelText)
            }
            state.isChangeNameButtonEnabled = true
            state.viewID = UUID()

        case let .feedback(.updateValueReturned(.failure(exception))):
            Logger.log(exception, with: .toast())
            state.isChangeNameButtonEnabled = true
        }

        return .none
    }
}
