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
import Networking

struct ContactSelectorPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.commonServices.penPals) private var penPalsService: PenPalsService
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.contactSelectorPageViewService) private var viewService: ContactSelectorPageViewService

    // MARK: - Actions

    enum Action {
        case viewAppeared
        case viewDisappeared

        case cancelToolbarButtonTapped
        case findUserButtonTapped
        case inviteToolbarButtonTapped

        case findUserReturned(Callback<User, Exception>)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
        case searchQueryChanged(String)
        case selectedContactPairChanged(ContactPair)

        case traitCollectionChanged
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Properties */

        let entryPoint: ContactSelectorPageView.EntryPoint

        @Localized(.invite) var inviteToolbarButtonText: String
        var searchQuery = ""
        var selectedContactPair: ContactPair?
        var strings: [TranslationOutputMap] = ContactSelectorPageViewStrings.defaultOutputMap
        var viewState: StatefulView.ViewState = .loading

        fileprivate var foundContactPair: ContactPair?
        fileprivate var traitCollectionDidChange = false

        /* MARK: Computed Properties */

        var contactPairs: [ContactPair] {
            @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
            return contactPairArchive ?? .init()
        }

        var navigationTitle: String {
            entryPoint == .chatInfoPageView ? strings.value(for: .navigationTitle) : Localized(.contacts).wrappedValue
        }

        var noResultsLabelText: String {
            if entryPoint == .chatInfoPageView,
               !searchQuery.isBlank,
               searchQuery == searchQuery.digits {
                return strings.value(for: .noResultsLabelText)
            }

            return Localized(.noResults).wrappedValue
        }

        var queriedContactPairs: [ContactPair] {
            guard let foundContactPair else { return contactPairs.queried(by: searchQuery) }
            return [foundContactPair]
        }

        var searchBarPlaceholderText: String {
            entryPoint == .chatInfoPageView ? strings.value(for: .searchBarPlaceholderText) : Localized(.search).wrappedValue
        }

        var sections: [String: [ContactPair]] {
            .init(
                grouping: queriedContactPairs,
                by: { $0.contact.tableViewSectionTitle }
            )
        }

        var shouldShowInviteButton: Bool {
            contactPairs.isEmpty || entryPoint == .newChatPageView
        }

        /* MARK: Init */

        init(_ entryPoint: ContactSelectorPageView.EntryPoint) {
            self.entryPoint = entryPoint
        }
    }

    // MARK: - Reduce

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            guard state.entryPoint == .chatInfoPageView else {
                state.viewState = .loaded
                return .none
            }

            state.viewState = .loading
            return .task {
                let result = await translator.resolve(ContactSelectorPageViewStrings.self)
                return .resolveReturned(result)
            }

        case .cancelToolbarButtonTapped:
            viewService.cancelToolbarButtonTapped(from: state.entryPoint)

        case .findUserButtonTapped:
            guard state.entryPoint == .chatInfoPageView,
                  state.queriedContactPairs.isEmpty,
                  state.searchQuery == state.searchQuery.digits else { return .none }
            let phoneNumber = PhoneNumber(state.searchQuery.digits)
            return .task {
                let result = await viewService.findUser(with: phoneNumber)
                return .findUserReturned(result)
            }

        case let .findUserReturned(.success(user)):
            guard !penPalsService.isObfuscatedPenPalWithCurrentUser(user) else { return .none }
            state.foundContactPair = user.contactPair ?? .withUser(
                user,
                name: user.displayName
            )

        case let .findUserReturned(.failure(exception)):
            guard exception.isEqual(to: .noUsersWithPhoneNumber) else {
                Logger.log(exception, with: .toast)
                return .none
            }

            let phoneNumber = PhoneNumber(state.searchQuery.digits)
            return .fireAndForget {
                await viewService.presentInvitationPrompt(phoneNumber: phoneNumber)
            }

        case .inviteToolbarButtonTapped:
            viewService.inviteToolbarButtonTapped()

        case let .resolveReturned(.success(strings)):
            state.strings = strings
            state.viewState = .loaded

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception, with: .toast)
            state.viewState = .loaded

        case let .searchQueryChanged(searchQuery):
            state.searchQuery = searchQuery
            guard searchQuery.isBlank else { return .none }
            state.foundContactPair = nil

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

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.ContactSelectorPageViewStringKey) -> String {
        (first(where: { $0.key == .contactSelectorPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
