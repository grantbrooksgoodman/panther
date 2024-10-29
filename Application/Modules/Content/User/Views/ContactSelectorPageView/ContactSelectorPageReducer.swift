//
//  ContactSelectorPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

public struct ContactSelectorPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.commonServices.invite) private var inviteService: InviteService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case cancelToolbarButtonTapped
        case inviteToolbarButtonTapped

        case isPresentedChanged(Bool)
        case searchQueryChanged(String)
        case selectedContactPairChanged(ContactPair)
    }

    // MARK: - Feedback

    public enum Feedback {
        case presentInvitationPromptReturned(Exception?)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        // String
        @Localized(.cancel) public var cancelToolbarButtonText: String
        @Localized(.done) public var doneToolbarButtonText: String
        @Localized(.invite) public var inviteToolbarButtonText: String
        @Localized(.contacts) public var navigationTitle: String
        @Localized(.noResults) public var noResultsLabelText: String
        public var searchQuery = ""

        // Other
        public var isPresented: Binding<Bool>
        public var selectedContactPair: ContactPair?

        /* MARK: Computed Properties */

        public var contactPairs: [ContactPair] {
            @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
            return contactPairArchive ?? .init()
        }

        public var queriedContactPairs: [ContactPair] { contactPairs.queried(by: searchQuery) }
        public var sections: [String: [ContactPair]] { .init(grouping: queriedContactPairs, by: { $0.contact.tableViewSectionTitle }) }

        /* MARK: Init */

        public init(_ isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        /* MARK: Equatable Conformance */

        public static func == (left: State, right: State) -> Bool {
            let sameCancelToolbarButtonText = left.cancelToolbarButtonText == right.cancelToolbarButtonText
            let sameContactPairs = left.contactPairs == right.contactPairs
            let sameDoneToolbarButtonText = left.doneToolbarButtonText == right.doneToolbarButtonText
            let sameInviteToolbarButtonText = left.inviteToolbarButtonText == right.inviteToolbarButtonText
            let sameIsPresented = left.isPresented.wrappedValue == right.isPresented.wrappedValue
            let sameNavigationTitle = left.navigationTitle == right.navigationTitle
            let sameNoResultsLabelText = left.noResultsLabelText == right.noResultsLabelText
            let sameQueriedContactPairs = left.queriedContactPairs == right.queriedContactPairs
            let sameSearchQuery = left.searchQuery == right.searchQuery
            let sameSections = left.sections == right.sections
            let sameSelectedContactPair = left.selectedContactPair == right.selectedContactPair

            guard sameCancelToolbarButtonText,
                  sameContactPairs,
                  sameDoneToolbarButtonText,
                  sameInviteToolbarButtonText,
                  sameIsPresented,
                  sameNavigationTitle,
                  sameNoResultsLabelText,
                  sameQueriedContactPairs,
                  sameSearchQuery,
                  sameSections,
                  sameSelectedContactPair else { return false }

            return true
        }
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.viewAppeared):
            NavigationBar.setAppearance(.themed(showsDivider: false))
            core.gcd.after(.seconds(1)) { core.ui.resignFirstResponder() }

        case .action(.cancelToolbarButtonTapped):
            state.isPresented.wrappedValue = false
            core.ui.resignFirstResponder()
            core.gcd.after(.milliseconds(250)) { chatPageViewService.inputBar?.forceAppearance() }

        case .action(.inviteToolbarButtonTapped):
            return .task {
                let result = await inviteService.presentInvitationPrompt()
                return .presentInvitationPromptReturned(result)
            }

        case let .action(.isPresentedChanged(isPresented)):
            state.isPresented.wrappedValue = isPresented

        case let .action(.searchQueryChanged(searchQuery)):
            state.searchQuery = searchQuery

        case let .action(.selectedContactPairChanged(selectedContactPair)):
            state.selectedContactPair = selectedContactPair
            state.isPresented.wrappedValue = false
            core.gcd.after(.milliseconds(100)) {
                chatPageViewService.recipientBar?.contactSelectionUI.selectContactPair(selectedContactPair, performInputBarFix: true)
            }

        case let .feedback(.presentInvitationPromptReturned(exception)):
            guard let exception else { return .none }
            Logger.log(exception, with: .toast())
        }

        return .none
    }
}
