//
//  ContactSelectorPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

/// The reducer that drives the contact selector page.
///
/// This page lets the user choose a contact – either to add a participant to an existing
/// conversation, when presented from the chat info page, or to start a new conversation, when
/// presented from the new chat page. Its title, strings, and available actions depend on the
/// entry point it was presented from.
///
/// The page's behavior contract:
///
/// - On appearance, the page resolves its translated display strings when presented from the
///   chat info page; from the new chat page, it loads immediately. If resolution fails, the page
///   loads anyway.
/// - The contact list shows the user's known contacts filtered by the search query, grouped into
///   alphabetical sections.
/// - When presented from the chat info page and the query is a phone number with no matching
///   contact, the user can look up a registered user by that number. A successful lookup shows
///   the user as the sole result, unless they are an obfuscated PenPals participant; a failed
///   lookup offers to send an invitation.
/// - Selecting a contact, canceling, and inviting someone are performed through
///   ``ContactSelectorPageViewService``.
struct ContactSelectorPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.commonServices.penPals) private var penPalsService: PenPalsService
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.contactSelectorPageViewService) private var viewService: ContactSelectorPageViewService

    // MARK: - Actions

    /// The actions the contact selector page can process.
    enum Action {
        /// An action that indicates the view appeared. Begins display string resolution when
        /// presented from the chat info page; otherwise, loads immediately.
        case viewAppeared

        /// An action that indicates the view disappeared. Restores the new chat page's navigation
        /// bar appearance when applicable.
        case viewDisappeared

        /// An action that indicates the user tapped the cancel toolbar button. Dismisses the
        /// page.
        case cancelToolbarButtonTapped

        /// An action that indicates the user tapped the find-user button. Looks up a registered
        /// user by the entered phone number.
        case findUserButtonTapped

        /// An action that indicates the user tapped the invite toolbar button. Begins inviting
        /// someone to the app.
        case inviteToolbarButtonTapped

        /// An action that indicates the user lookup failed, carrying the resulting `Exception`.
        /// Offers to send an invitation when no registered user has the entered phone number.
        case findUserFailed(Exception)

        /// An action that indicates the user lookup succeeded, carrying the found user. Shows the
        /// user as the sole result, unless they are an obfuscated PenPals participant.
        case findUserReturned(User)

        /// An action that indicates display string resolution failed, carrying the resulting
        /// `Exception`.
        case resolveFailed(Exception)

        /// An action that indicates display string resolution succeeded, carrying the resolved
        /// strings.
        case resolveReturned([TranslationOutputMap])

        /// An action that indicates the search query changed, carrying the new value.
        case searchQueryChanged(String)

        /// An action that indicates the user selected a contact, carrying the selected contact
        /// pair. Applies the selection for the current entry point.
        case selectedContactPairChanged(ContactPair)
    }

    // MARK: - State

    /// The state of the contact selector page.
    struct State: Equatable {
        /* MARK: Properties */

        /// The context the page was presented from.
        let entryPoint: ContactSelectorPageView.EntryPoint

        /// The localized text the invite toolbar button displays.
        @Localized(.invite) var inviteToolbarButtonText: String

        /// The search query the user has entered.
        var searchQuery = ""

        /// The contact pair the user selected, if any.
        var selectedContactPair: ContactPair?

        /// The page's translated display strings. Contains the default, untranslated strings
        /// until resolution completes.
        var strings: [TranslationOutputMap] = ContactSelectorPageViewStrings.defaultOutputMap

        /// The page's loading state. Remains `loading` until the page is ready to display.
        var viewState: StatefulView.ViewState = .loading

        fileprivate var foundContactPair: ContactPair?

        /* MARK: Computed Properties */

        /// The user's known contact pairs, from the contact pair archive.
        var contactPairs: [ContactPair] {
            @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
            return contactPairArchive ?? .init()
        }

        /// The page's navigation title.
        var navigationTitle: String {
            entryPoint == .chatInfoPageView ? strings.value(for: .navigationTitle) : Localized(.contacts).wrappedValue
        }

        /// The text shown when no contacts match the search.
        var noResultsLabelText: String {
            if entryPoint == .chatInfoPageView,
               !searchQuery.isBlank,
               searchQuery == searchQuery.digits {
                return strings.value(for: .noResultsLabelText)
            }

            return Localized(.noResults).wrappedValue
        }

        /// The contact pairs matching the search query, or the single found user when a phone
        /// number lookup succeeded.
        @MainActor
        var queriedContactPairs: [ContactPair] {
            guard let foundContactPair else { return contactPairs.queried(by: searchQuery) }
            return [foundContactPair]
        }

        /// The search bar's placeholder text.
        var searchBarPlaceholderText: String {
            entryPoint == .chatInfoPageView ? strings.value(for: .searchBarPlaceholderText) : Localized(.search).wrappedValue
        }

        /// The queried contact pairs grouped into sections by their section title.
        @MainActor
        var sections: [String: [ContactPair]] {
            .init(
                grouping: queriedContactPairs,
                by: { $0.contact.tableViewSectionTitle }
            )
        }

        /// A Boolean value that indicates whether the invite button is shown. Shown when the user
        /// has no known contacts, or when composing a new conversation.
        var shouldShowInviteButton: Bool {
            contactPairs.isEmpty || entryPoint == .newChatPageView
        }

        fileprivate var queryMatchesFoundContactPair: Bool {
            guard let foundContactPair else { return false }

            let phoneNumbers = foundContactPair
                .users
                .compactMap(\.phoneNumber)

            let numberStrings = (
                phoneNumbers.compiledNumberStrings +
                    phoneNumbers.map(\.nationalNumberString)
            ).map(\.digits)

            return numberStrings.contains(searchQuery)
        }

        /* MARK: Init */

        /// Creates a state for the given entry point.
        ///
        /// - Parameter entryPoint: The context the page was presented from.
        init(_ entryPoint: ContactSelectorPageView.EntryPoint) {
            self.entryPoint = entryPoint
        }
    }

    // MARK: - Reduce

    /// Updates the page's state in response to the given action, returning any effect to run.
    ///
    /// - Parameters:
    ///   - state: The page's current state, mutated in place.
    ///   - action: The action to process.
    ///
    /// - Returns: An effect for the system to run, or `.none`.
    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            guard state.entryPoint == .chatInfoPageView else {
                state.viewState = .loaded
                return .none
            }

            state.viewState = .loading
            return .task {
                do throws(Exception) {
                    return try await .resolveReturned(
                        translator.resolve(ContactSelectorPageViewStrings.self)
                    )
                } catch {
                    return .resolveFailed(error)
                }
            }

        case .cancelToolbarButtonTapped:
            viewService.cancelToolbarButtonTapped(from: state.entryPoint)

        case .findUserButtonTapped:
            guard state.entryPoint == .chatInfoPageView,
                  state.queriedContactPairs.isEmpty,
                  state.searchQuery == state.searchQuery.digits else { return .none }
            let phoneNumber = PhoneNumber(state.searchQuery.digits)
            return .task {
                do throws(Exception) {
                    return try await .findUserReturned(
                        viewService.findUser(with: phoneNumber)
                    )
                } catch {
                    return .findUserFailed(error)
                }
            }

        case let .findUserReturned(user):
            guard !penPalsService.isObfuscatedPenPalWithCurrentUser(user) else { return .none }
            state.foundContactPair = user.contactPair ?? .withUser(
                user,
                name: user.displayName
            )

        case let .findUserFailed(exception):
            guard exception.isEqual(to: .noUsersWithPhoneNumber) else {
                Logger.log(
                    exception,
                    with: .toast
                )

                return .none
            }

            let phoneNumber = PhoneNumber(state.searchQuery.digits)
            return .fireAndForget {
                await viewService.presentInvitationPrompt(phoneNumber: phoneNumber)
            }

        case .inviteToolbarButtonTapped:
            viewService.inviteToolbarButtonTapped()

        case let .resolveFailed(exception):
            Logger.log(
                exception,
                with: .toast
            )

            state.viewState = .loaded

        case let .resolveReturned(strings):
            state.strings = strings
            state.viewState = .loaded

        case let .searchQueryChanged(searchQuery):
            state.searchQuery = searchQuery
            guard searchQuery.isBlank || !state.queryMatchesFoundContactPair else { return .none }
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

        case .viewDisappeared:
            guard Application.isInPrevaricationMode,
                  UIApplication.isFullyV26Compatible,
                  state.entryPoint == .newChatPageView else { return .none }

            NavigationBar.setAppearance(.newChatPageView)
        }

        return .none
    }
}

private extension [TranslationOutputMap] {
    func value(for key: TranslatedLabelStringCollection.ContactSelectorPageViewStringKey) -> String {
        (first(where: { $0.key == .contactSelectorPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
