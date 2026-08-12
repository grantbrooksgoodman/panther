//
//  SettingsPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length

/* Native */
@preconcurrency import Contacts
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

/// The reducer that drives the settings page.
///
/// This page presents the app's settings. It shows the user's contact card and data usage, and
/// provides the toggles and buttons for the app's options – AI-enhanced translations, message
/// recipient consent, PenPals participation, blocked users, theme, language, and account actions.
/// Most of these actions are performed through ``SettingsPageViewService``.
///
/// The page's behavior contract:
///
/// - On appearance, the page resolves its translated display strings, the user's contact card,
///   and the user's data usage concurrently, and initializes its switches from the current user.
///   It remains in the loading state until string resolution completes.
/// - Toggling a switch applies the change, but only when the toggle came from the user rather
///   than a programmatic update.
/// - Tapping a button performs its action, and tapping done dismisses the page.
struct SettingsPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.commonServices.contact) private var contactService: ContactService
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.clientSession.entity.user) private var userSession: UserSessionService
    @Dependency(\.settingsPageViewService) private var viewService: SettingsPageViewService

    // MARK: - Properties

    @SharedEvent(\.traitCollectionChanged) private var traitCollectionChanged

    // MARK: - Actions

    /// The actions the settings page can process.
    enum Action {
        /// An action that indicates the view appeared. Begins resolving the display strings, the
        /// user's contact card, and the user's data usage, and initializes the switches.
        case viewAppeared

        /// An action that indicates the user tapped the blocked users button. Presents the
        /// blocked users list.
        case blockedUsersButtonTapped

        /// An action that indicates the user tapped the build info button. Advances the build
        /// info to its next value.
        case buildInfoButtonTapped

        /// An action that indicates the user tapped the change theme button. Begins changing the
        /// app's theme.
        case changeThemeButtonTapped

        /// An action that indicates the user tapped the clear caches button. Clears the app's
        /// caches.
        case clearCachesButtonTapped

        /// An action that indicates the user tapped the delete account button. Begins deleting
        /// the account.
        case deleteAccountButtonTapped

        /// An action that indicates the user tapped the done button. Dismisses the page.
        case doneToolbarButtonTapped

        /// An action that indicates the user tapped the invite friends button. Begins inviting
        /// friends to the app.
        case inviteFriendsButtonTapped

        /// An action that indicates the user tapped the leave review button. Prompts the user to
        /// leave a review.
        case leaveReviewButtonTapped

        /// An action that indicates the user tapped the send feedback button. Begins sending
        /// feedback.
        case sendFeedbackButtonTapped

        /// An action that indicates the user tapped the sign out button. Signs the user out.
        case signOutButtonTapped

        /// An action that indicates a long press on the build info button was recognized. Copies
        /// the build info to the clipboard, or – after the copyright text has been revealed
        /// repeatedly – offers to enter prerelease mode.
        case longPressGestureRecognized

        /// An action that indicates the trait collection changed. Rebuilds the page.
        case traitCollectionChanged

        /// An action that indicates the view disappeared. Restores the conversations page's
        /// navigation bar appearance.
        case viewDisappeared

        /// An action that indicates the AI-enhanced translations switch was toggled. Applies the
        /// change only when the toggle came from the user.
        ///
        /// - Parameters:
        ///   - on: The switch's new value.
        ///   - fromBinding: A Boolean value that indicates whether the toggle originated from the
        ///     user interacting with the switch, rather than a programmatic update.
        case aiEnhancedTranslationsSwitchToggled(on: Bool, fromBinding: Bool = false)

        /// An action that indicates fetching the user's contact card failed, carrying the
        /// resulting `Exception`. Falls back to the user's phone number.
        case fetchCNContactForCurrentUserFailed(Exception)

        /// An action that indicates the user's contact card resolved, carrying the contact.
        /// Updates the contact detail view.
        case fetchCNContactForCurrentUserReturned(CNContact)

        /// An action that indicates fetching the user's data usage failed, carrying the resulting
        /// `Exception`.
        case getCurrentUserDataUsageFailed(Exception)

        /// An action that indicates the user's data usage resolved, carrying the amount in
        /// kilobytes.
        case getCurrentUserDataUsageReturned(Int)

        /// An action that indicates the message recipient consent switch was toggled, carrying
        /// its new value. Applies the change.
        ///
        /// - Parameter on: The switch's new value.
        case messageRecipientConsentSwitchToggled(on: Bool)

        /// An action that indicates the PenPals participation switch was toggled. Applies the
        /// change only when the toggle came from the user.
        ///
        /// - Parameters:
        ///   - on: The switch's new value.
        ///   - fromBinding: A Boolean value that indicates whether the toggle originated from the
        ///     user interacting with the switch, rather than a programmatic update.
        case penPalsParticipantSwitchToggled(on: Bool, fromBinding: Bool = false)

        /// An action that indicates display string resolution failed, carrying the resulting
        /// `Exception`.
        case resolveFailed(Exception)

        /// An action that indicates display string resolution succeeded, carrying the resolved
        /// strings.
        case resolveReturned([TranslationOutputMap])
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Constants Accessors */

        private typealias Strings = AppConstants.Strings.SettingsPageView

        /* MARK: Properties */

        /// The localized text the done button displays.
        let doneToolbarButtonText = Localized(.done).wrappedValue

        /// The page's navigation title.
        let navigationTitle = Localized(.settings).wrappedValue.removingOccurrences(of: ["…"])

        /// The strings the build info button currently displays.
        var buildInfoButtonStrings: BuildInfoButtonStrings = .init(.bundleVersionAndBuildNumber)

        /// The current user's system contact card, if available.
        var cnContact: CNContact?

        /// The image shown in the user's contact detail view.
        var contactDetailViewImage: UIImage?

        /// The subtitle shown in the user's contact detail view.
        var contactDetailViewSubtitleLabelText: String?

        /// The title shown in the user's contact detail view.
        var contactDetailViewTitleLabelText = ""

        /// The current user's data usage, in kilobytes.
        var dataUsageInKilobytes = 0

        /// The identity of the data usage view. Regenerated to rebuild it when the usage updates.
        var dataUsageViewID = UUID()

        /// The developer mode list rows, if any.
        var developerModeListItems: [ListRowView.Configuration]?

        /// The identity of the grouped list. Regenerated to rebuild it when the trait collection
        /// changes.
        var groupedListViewsID = UUID()

        /// A Boolean value that indicates whether the AI-enhanced translations switch is on.
        var isAIEnhancedTranslationsSwitchToggled = false

        /// A Boolean value that indicates whether the message recipient consent switch is on.
        var isMessageRecipientConsentSwitchToggled = false

        /// A Boolean value that indicates whether the PenPals participation switch is on.
        var isPenPalsParticipantSwitchToggled = false

        /// The page's translated display strings. Contains the default, untranslated strings
        /// until resolution completes.
        var strings: [TranslationOutputMap] = SettingsPageViewStrings.defaultOutputMap

        /// The identity of the page's content. Regenerated to rebuild it from the latest values.
        var viewID = UUID()

        /// The page's loading state. Remains `loading` until display string resolution completes.
        var viewState: StatefulView.ViewState = .loading

        fileprivate var timesEncounteredCopyrightText = 0
        fileprivate var traitCollectionChanged = false

        /* MARK: Computed Properties */

        /// The blocked users button's text, including the count of blocked users.
        var blockedUsersButtonText: String {
            @Dependency(\.clientSession.entity.user.currentUser?.blockedUserIDs) var blockedUserIDs: [String]?
            return "\(strings.value(for: .blockedUsersButtonText)) (\((blockedUserIDs ?? []).count))"
        }

        /// The build info button's image for dark backgrounds.
        var buildInfoButtonDarkBackgroundImage: UIImage {
            .ntWhite
        }

        /// The build info button's image for light backgrounds.
        var buildInfoButtonLightBackgroundImage: UIImage {
            .ntBlack
        }

        /// A Boolean value that indicates whether the blocked users button is enabled. Enabled
        /// when the user has blocked at least one user.
        var isBlockedUsersButtonEnabled: Bool {
            @Dependency(\.clientSession.entity.user.currentUser?.blockedUserIDs) var blockedUserIDs: [String]?
            return !(blockedUserIDs ?? []).isBangQualifiedEmpty
        }

        /// A Boolean value that indicates whether the change theme button is enabled. Disabled
        /// while a theme change is pending.
        var isChangeThemeButtonEnabled: Bool {
            @Persistent(.init("pendingThemeID")) var pendingThemeID: String?
            return pendingThemeID == nil
        }

        /// The navigation bar appearance for the current theme.
        @MainActor
        var navigationBarAppearance: NavigationBarAppearance {
            guard !Application.isInPrevaricationMode else { return .appDefault }
            return ThemeService.isAppDefaultThemeApplied ? .default() : .themed()
        }
    }

    // MARK: - Reduce

    // swiftlint:disable function_body_length
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
            state.viewState = .loading
            state.developerModeListItems = viewService.developerModeListItems()

            state.isAIEnhancedTranslationsSwitchToggled = userSession.currentUser?.aiEnhancedTranslationsEnabled ?? false
            state.isMessageRecipientConsentSwitchToggled = userSession.currentUser?.messageRecipientConsentRequired ?? false
            state.isPenPalsParticipantSwitchToggled = userSession.currentUser?.isPenPalsParticipant ?? false

            NavigationBar.setAppearance(state.navigationBarAppearance)
            let fetchCNContactForCurrentUserTask: Effect<Action> = .task {
                do throws(Exception) {
                    return try await .fetchCNContactForCurrentUserReturned(
                        viewService.fetchCNContactForCurrentUser()
                    )
                } catch {
                    return .fetchCNContactForCurrentUserFailed(error)
                }
            }

            let getCurrentUserDataUsageTask: Effect<Action> = .task {
                do throws(Exception) {
                    return try await .getCurrentUserDataUsageReturned(
                        viewService.getCurrentUserDataUsage()
                    )
                } catch {
                    return .getCurrentUserDataUsageFailed(error)
                }
            }

            return .task {
                do throws(Exception) {
                    return try await .resolveReturned(
                        translator.resolve(SettingsPageViewStrings.self)
                    )
                } catch {
                    return .resolveFailed(error)
                }
            }
            .merge(with: fetchCNContactForCurrentUserTask)
            .merge(with: getCurrentUserDataUsageTask)

        case let .aiEnhancedTranslationsSwitchToggled(on, fromBinding):
            state.isAIEnhancedTranslationsSwitchToggled = on
            guard fromBinding else { return .none }
            viewService.aiEnhancedTranslationsSwitchToggled(on: on)

        case .blockedUsersButtonTapped:
            viewService.blockedUsersButtonTapped()

        case .buildInfoButtonTapped:
            state.buildInfoButtonStrings = state.buildInfoButtonStrings.next
            state.timesEncounteredCopyrightText += state.buildInfoButtonStrings == .init(.copyright) ? 1 : 0

        case .changeThemeButtonTapped:
            viewService.changeThemeButtonTapped()

        case .clearCachesButtonTapped:
            viewService.clearCachesButtonTapped()

        case .deleteAccountButtonTapped:
            viewService.deleteAccountButtonTapped()

        case .doneToolbarButtonTapped:
            navigation.navigate(to: .userContent(.sheet(.none)))

        case let .fetchCNContactForCurrentUserFailed(exception):
            state.contactDetailViewTitleLabelText = userSession.currentUser?.phoneNumber.formattedString() ?? state.contactDetailViewTitleLabelText
            Logger.log(exception)

        case let .fetchCNContactForCurrentUserReturned(cnContact):
            state.cnContact = cnContact

            let contact = Contact(cnContact)
            let formattedPhoneNumberString = userSession.currentUser?.phoneNumber.formattedString() ?? contact.phoneNumbers.first?.formattedString()

            state.contactDetailViewImage = contact.image
            state.contactDetailViewSubtitleLabelText = formattedPhoneNumberString == contact.fullName ? "" : formattedPhoneNumberString
            state.contactDetailViewTitleLabelText = contact.fullName

        case let .getCurrentUserDataUsageFailed(exception):
            Logger.log(exception)

        case let .getCurrentUserDataUsageReturned(dataUsageInKilobytes):
            state.dataUsageInKilobytes = dataUsageInKilobytes
            state.dataUsageViewID = UUID()

        case .inviteFriendsButtonTapped:
            viewService.inviteFriendsButtonTapped()

        case .leaveReviewButtonTapped:
            viewService.leaveReviewButtonTapped()

        case .longPressGestureRecognized:
            if state.buildInfoButtonStrings == .init(.copyright),
               state.timesEncounteredCopyrightText > 1 {
                viewService.promptToEnterPrereleaseMode()
            } else {
                viewService.setClipboardWithHapticFeedback(state.buildInfoButtonStrings.labelText)
            }

        case let .messageRecipientConsentSwitchToggled(on: on):
            state.isMessageRecipientConsentSwitchToggled = on
            viewService.messageRecipientConsentSwitchToggled(on: on)

        case let .penPalsParticipantSwitchToggled(on, fromBinding):
            state.isPenPalsParticipantSwitchToggled = on
            guard fromBinding else { return .none }
            viewService.penPalsParticipantSwitchToggled(on: on)

        case let .resolveFailed(exception):
            Logger.log(exception)
            state.viewState = .loaded

        case let .resolveReturned(strings):
            state.strings = strings
            state.viewState = .loaded

        case .sendFeedbackButtonTapped:
            viewService.sendFeedbackButtonTapped()

        case .signOutButtonTapped:
            viewService.signOutButtonTapped()

        case .traitCollectionChanged:
            state.traitCollectionChanged = true
            state.viewID = UUID()
            guard viewService.isMainPagePresented else { return .none }
            state.groupedListViewsID = UUID()

        case .viewDisappeared:
            let traitCollectionDidChange = state.traitCollectionChanged
            return .task { @MainActor in
                NavigationBar.setAppearance(.conversationsPageView)
                ConversationsPageView.reapplyNavigationBarItemGlassTintIfNeeded()
                guard traitCollectionDidChange else { return .none }
                traitCollectionChanged.send()
                return .none
            }
        }

        return .none
    } // swiftlint:enable function_body_length
}

private extension [TranslationOutputMap] {
    func value(for key: TranslatedLabelStringCollection.SettingsPageViewStringKey) -> String {
        (first(where: { $0.key == .settingsPageView(key) })?.value ?? key.rawValue).sanitized
    }
}

// swiftlint:enable file_length
