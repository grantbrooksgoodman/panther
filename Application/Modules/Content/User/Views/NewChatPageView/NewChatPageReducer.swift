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

/* 3rd-party */
import Redux

public struct NewChatPageReducer: Reducer {
    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case conversationChanged(Conversation)
        case isPresentedChanged(Bool)
    }

    // MARK: - Feedback

    public enum Feedback {}

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        public var conversation: Conversation = .empty
        public var doneToolbarButtonText = ""
        public var isPresented: Binding<Bool>

        /* MARK: Init */

        public init(_ isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        /* MARK: Equatable Conformance */

        public static func == (left: State, right: State) -> Bool {
            let sameConversation = left.conversation == right.conversation
            let sameDoneToolbarButtonText = left.doneToolbarButtonText == right.doneToolbarButtonText
            let sameIsPresented = left.isPresented.wrappedValue == right.isPresented.wrappedValue

            guard sameConversation,
                  sameDoneToolbarButtonText,
                  sameIsPresented else { return false }

            return true
        }
    }

    // MARK: - Init

    public init() { RuntimeStorage.store(#file, as: .presentedViewName) }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.viewAppeared):
            state.doneToolbarButtonText = Localized(.cancel).wrappedValue

        case let .action(.conversationChanged(conversation)):
            state.conversation = conversation

        case let .action(.isPresentedChanged(isPresented)):
            state.isPresented.wrappedValue = isPresented
        }

        return .none
    }
}
