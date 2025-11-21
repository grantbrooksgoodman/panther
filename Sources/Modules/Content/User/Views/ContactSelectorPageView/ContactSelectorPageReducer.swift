//
//  ContactSelectorPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public struct ContactSelectorPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.contactSelectorPageViewService) private var viewService: ContactSelectorPageViewService

    // MARK: - Actions

    public enum Action {
        case viewDisappeared

        case cancelToolbarButtonTapped
        case inviteToolbarButtonTapped

        case searchQueryChanged(String)
        case selectedContactPairChanged(ContactPair)

        case traitCollectionChanged
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        // String
        @Localized(.invite) public var inviteToolbarButtonText: String
        @Localized(.contacts) public var navigationTitle: String
        @Localized(.noResults) public var noResultsLabelText: String
        public var searchQuery = ""

        // Other
        public let entryPoint: ContactSelectorPageView.EntryPoint

        public var selectedContactPair: ContactPair?

        fileprivate var traitCollectionDidChange = false

        /* MARK: Computed Properties */

        public var contactPairs: [ContactPair] {
            @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
            return contactPairArchive ?? .init()
        }

        public var queriedContactPairs: [ContactPair] { contactPairs.queried(by: searchQuery) }
        public var sections: [String: [ContactPair]] { .init(grouping: queriedContactPairs, by: { $0.contact.tableViewSectionTitle }) }

        /* MARK: Init */

        public init(_ entryPoint: ContactSelectorPageView.EntryPoint) {
            self.entryPoint = entryPoint
        }
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .cancelToolbarButtonTapped:
            viewService.cancelToolbarButtonTapped(from: state.entryPoint)

        case .inviteToolbarButtonTapped:
            viewService.inviteToolbarButtonTapped()

        case let .searchQueryChanged(searchQuery):
            state.searchQuery = searchQuery

        case let .selectedContactPairChanged(selectedContactPair):
            state.selectedContactPair = selectedContactPair
            let entryPoint = state.entryPoint
            return .fireAndForget {
                await viewService.selectedContactPairChanged(
                    selectedContactPair,
                    from: entryPoint
                )
            }

        case .traitCollectionChanged:
            state.traitCollectionDidChange = true

        case .viewDisappeared:
            guard state.entryPoint == .chatInfoPageView,
                  state.traitCollectionDidChange else { return .none }
            Observables.currentConversationMetadataChanged.trigger()
        }

        return .none
    }
}
