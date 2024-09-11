//
//  NewChatPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 10/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

public struct NewChatPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.commonServices.analytics) private var analyticsService: AnalyticsService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case conversationChanged(Conversation)
        case isPresentedChanged(Bool)
        case isPresentingContactSelectorSheetChanged(Bool)

        case doneToolbarButtonTapped
    }

    // MARK: - Feedback

    public enum Feedback {}

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        // Bool
        public var isPresented: Binding<Bool>
        public var isPresentingContactSelectorSheet = false

        // String
        @Localized(.cancel) public var doneToolbarButtonText: String
        @Localized(.newMessage) public var navigationTitle: String

        // Other
        public var conversation: Conversation = .empty

        /* MARK: Init */

        public init(_ isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        /* MARK: Equatable Conformance */

        public static func == (left: State, right: State) -> Bool {
            let sameConversation = left.conversation == right.conversation
            let sameDoneToolbarButtonText = left.doneToolbarButtonText == right.doneToolbarButtonText
            let sameIsPresented = left.isPresented.wrappedValue == right.isPresented.wrappedValue
            let sameIsPresentingContactSelectorSheet = left.isPresentingContactSelectorSheet == right.isPresentingContactSelectorSheet
            let sameNavigationTitle = left.navigationTitle == right.navigationTitle

            guard sameConversation,
                  sameDoneToolbarButtonText,
                  sameIsPresented,
                  sameIsPresentingContactSelectorSheet,
                  sameNavigationTitle else { return false }

            return true
        }
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.viewAppeared):
            analyticsService.logEvent(.accessNewChatPage)
            NavigationBar.setAppearance(.themed(showsDivider: false))

        case let .action(.conversationChanged(conversation)):
            state.conversation = conversation

        case .action(.doneToolbarButtonTapped):
            state.isPresented.wrappedValue = false

        case let .action(.isPresentedChanged(isPresented)):
            state.isPresented.wrappedValue = isPresented
            guard !isPresented else { return .none }
            analyticsService.logEvent(.dismissNewChatPage)

        case let .action(.isPresentingContactSelectorSheetChanged(isPresentingContactSelectorSheet)):
            state.isPresentingContactSelectorSheet = isPresentingContactSelectorSheet
        }

        return .none
    }
}
