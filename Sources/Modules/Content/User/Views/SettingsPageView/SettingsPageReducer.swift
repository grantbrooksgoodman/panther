//
//  SettingsPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Contacts
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

struct SettingsPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.commonServices.contact) private var contactService: ContactService
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.clientSession.user) private var userSession: UserSessionService
    @Dependency(\.settingsPageViewService) private var viewService: SettingsPageViewService

    // MARK: - Actions

    enum Action {
        case viewAppeared

        case blockedUsersButtonTapped
        case buildInfoButtonTapped
        case changeThemeButtonTapped
        case clearCachesButtonTapped
        case deleteAccountButtonTapped
        case doneToolbarButtonTapped
        case inviteFriendsButtonTapped
        case leaveReviewButtonTapped
        case sendFeedbackButtonTapped
        case signOutButtonTapped

        case longPressGestureRecognized
        case traitCollectionChanged
        case viewDisappeared

        case aiEnhancedTranslationsSwitchToggled(on: Bool, fromBinding: Bool = false)
        case fetchCNContactForCurrentUserReturned(Callback<CNContact, Exception>)
        case getCurrentUserDataUsageReturned(Callback<Int, Exception>)
        case messageRecipientConsentSwitchToggled(on: Bool)
        case penPalsParticipantSwitchToggled(on: Bool, fromBinding: Bool = false)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Constants Accessors */

        private typealias Strings = AppConstants.Strings.SettingsPageView

        /* MARK: Properties */

        let doneToolbarButtonText = Localized(.done).wrappedValue
        let navigationTitle = Localized(.settings).wrappedValue.removingOccurrences(of: ["…"])

        var buildInfoButtonStrings: BuildInfoButtonStrings = .init(.bundleVersionAndBuildNumber)
        var cnContact: CNContact?
        var contactDetailViewImage: UIImage?
        var contactDetailViewSubtitleLabelText: String?
        var contactDetailViewTitleLabelText = ""
        var dataUsageInKilobytes = 0
        var dataUsageViewID = UUID()
        var developerModeListItems: [ListRowView.Configuration]?
        var groupedListViewsID = UUID()
        var isAIEnhancedTranslationsSwitchToggled = false
        var isMessageRecipientConsentSwitchToggled = false
        var isPenPalsParticipantSwitchToggled = false
        var strings: [TranslationOutputMap] = SettingsPageViewStrings.defaultOutputMap
        var viewID = UUID()
        var viewState: StatefulView.ViewState = .loading

        fileprivate var timesEncounteredCopyrightText = 0
        fileprivate var traitCollectionChanged = false

        /* MARK: Computed Properties */

        var blockedUsersButtonText: String {
            @Dependency(\.clientSession.user.currentUser?.blockedUserIDs) var blockedUserIDs: [String]?
            return "\(strings.value(for: .blockedUsersButtonText)) (\((blockedUserIDs ?? []).count))"
        }

        var buildInfoButtonDarkBackgroundImage: UIImage { .ntWhite }
        var buildInfoButtonLightBackgroundImage: UIImage { .ntBlack }

        var isBlockedUsersButtonEnabled: Bool {
            @Dependency(\.clientSession.user.currentUser?.blockedUserIDs) var blockedUserIDs: [String]?
            return !(blockedUserIDs ?? []).isBangQualifiedEmpty
        }

        var isChangeThemeButtonEnabled: Bool {
            @Persistent(.init("pendingThemeID")) var pendingThemeID: String?
            return pendingThemeID == nil
        }

        @MainActor
        var navigationBarAppearance: NavigationBarAppearance {
            guard !Application.isInPrevaricationMode else { return .appDefault }
            return ThemeService.isAppDefaultThemeApplied ? .default() : .themed()
        }
    }

    // MARK: - Reduce

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading
            state.developerModeListItems = viewService.developerModeListItems()

            state.isAIEnhancedTranslationsSwitchToggled = userSession.currentUser?.aiEnhancedTranslationsEnabled ?? false
            state.isMessageRecipientConsentSwitchToggled = userSession.currentUser?.messageRecipientConsentRequired ?? false
            state.isPenPalsParticipantSwitchToggled = userSession.currentUser?.isPenPalsParticipant ?? false

            NavigationBar.setAppearance(state.navigationBarAppearance)
            let fetchCNContactForCurrentUserTask: Effect<Action> = .task {
                let result = await viewService.fetchCNContactForCurrentUser()
                return .fetchCNContactForCurrentUserReturned(result)
            }

            let getCurrentUserDataUsageTask: Effect<Action> = .task {
                let result = await viewService.getCurrentUserDataUsage()
                return .getCurrentUserDataUsageReturned(result)
            }

            return .task {
                let result = await translator.resolve(SettingsPageViewStrings.self)
                return .resolveReturned(result)
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

        case let .fetchCNContactForCurrentUserReturned(.success(cnContact)):
            state.cnContact = cnContact

            let contact = Contact(cnContact)
            let formattedPhoneNumberString = userSession.currentUser?.phoneNumber.formattedString() ?? contact.phoneNumbers.first?.formattedString()

            state.contactDetailViewImage = contact.image
            state.contactDetailViewSubtitleLabelText = formattedPhoneNumberString == contact.fullName ? "" : formattedPhoneNumberString
            state.contactDetailViewTitleLabelText = contact.fullName

        case let .fetchCNContactForCurrentUserReturned(.failure(exception)):
            state.contactDetailViewTitleLabelText = userSession.currentUser?.phoneNumber.formattedString() ?? state.contactDetailViewTitleLabelText
            Logger.log(exception)

        case let .getCurrentUserDataUsageReturned(.success(dataUsageInKilobytes)):
            state.dataUsageInKilobytes = dataUsageInKilobytes
            state.dataUsageViewID = UUID()

        case let .getCurrentUserDataUsageReturned(.failure(exception)):
            Logger.log(exception)

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

        case let .resolveReturned(.success(strings)):
            state.strings = strings
            state.viewState = .loaded

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception)
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
            let traitCollectionChanged = state.traitCollectionChanged
            return .task { @MainActor in
                NavigationBar.setAppearance(.conversationsPageView)
                ConversationsPageView.reapplyNavigationBarItemGlassTintIfNeeded()
                guard traitCollectionChanged else { return .none }
                Observables.traitCollectionChanged.trigger()
                return .none
            }
        }

        return .none
    }
}

private extension [TranslationOutputMap] {
    func value(for key: TranslatedLabelStringCollection.SettingsPageViewStringKey) -> String {
        (first(where: { $0.key == .settingsPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
