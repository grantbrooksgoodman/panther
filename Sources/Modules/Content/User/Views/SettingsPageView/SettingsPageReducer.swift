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

public struct SettingsPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.commonServices.contact) private var contactService: ContactService
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.clientSession.user) private var userSession: UserSessionService
    @Dependency(\.settingsPageViewService) private var viewService: SettingsPageViewService

    // MARK: - Actions

    public enum Action {
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

        case fetchCNContactForCurrentUserReturned(Callback<CNContact, Exception>)
        case messageRecipientConsentSwitchToggled(on: Bool)
        case penPalsParticipantSwitchToggled(on: Bool, fromBinding: Bool = false)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Constants Accessors */

        private typealias Strings = AppConstants.Strings.SettingsPageView

        /* MARK: Properties */

        // Array
        public var developerModeListItems: [ListRowView.Configuration]?
        public var strings: [TranslationOutputMap] = SettingsPageViewStrings.defaultOutputMap

        // Bool
        public var isMessageRecipientConsentSwitchToggled = false
        public var isPenPalsParticipantSwitchToggled = false

        fileprivate var traitCollectionChanged = false

        // String
        public let doneToolbarButtonText = Localized(.done).wrappedValue
        public let navigationTitle = Localized(.settings).wrappedValue.removingOccurrences(of: ["..."])

        public var contactDetailViewSubtitleLabelText: String?
        public var contactDetailViewTitleLabelText = ""

        // Other
        public var buildInfoButtonStrings: BuildInfoButtonStrings = .init(.bundleVersionAndBuildNumber)
        public var contactDetailViewImage: UIImage?
        public var cnContact: CNContact?
        public var viewID = UUID()
        public var viewState: StatefulView.ViewState = .loading

        fileprivate var timesEncounteredCopyrightText = 0

        /* MARK: Computed Properties */

        // Bool
        public var isBlockedUsersButtonEnabled: Bool {
            @Dependency(\.clientSession.user.currentUser?.blockedUserIDs) var blockedUserIDs: [String]?
            return !(blockedUserIDs ?? []).isBangQualifiedEmpty
        }

        public var isChangeThemeButtonEnabled: Bool {
            @Persistent(.init("pendingThemeID")) var pendingThemeID: String?
            return pendingThemeID == nil
        }

        // UIImage
        public var buildInfoButtonDarkBackgroundImage: UIImage { .ntWhite }
        public var buildInfoButtonLightBackgroundImage: UIImage { .ntBlack }

        // Other
        public var blockedUsersButtonText: String {
            @Dependency(\.clientSession.user.currentUser?.blockedUserIDs) var blockedUserIDs: [String]?
            return "\(strings.value(for: .blockedUsersButtonText)) (\((blockedUserIDs ?? []).count))"
        }

        public var navigationBarAppearance: NavigationBarAppearance {
            guard !Application.isInPrevaricationMode else { return .appDefault }
            return ThemeService.isAppDefaultThemeApplied ? .default() : .themed()
        }

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading
            state.developerModeListItems = viewService.developerModeListItems()
            state.isMessageRecipientConsentSwitchToggled = userSession.currentUser?.messageRecipientConsentRequired ?? false
            state.isPenPalsParticipantSwitchToggled = userSession.currentUser?.isPenPalsParticipant ?? false

            NavigationBar.setAppearance(state.navigationBarAppearance)
            let fetchCNContactForCurrentUserTask: Effect<Action> = .task {
                let result = await viewService.fetchCNContactForCurrentUser()
                return .fetchCNContactForCurrentUserReturned(result)
            }

            return .task {
                let result = await translator.resolve(SettingsPageViewStrings.self)
                return .resolveReturned(result)
            }.merge(with: fetchCNContactForCurrentUserTask)

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

        case .viewDisappeared:
            let traitCollectionChanged = state.traitCollectionChanged
            return .task { @MainActor in
                NavigationBar.setAppearance(.conversationsPageView)
                guard traitCollectionChanged else { return .none }
                Observables.traitCollectionChanged.trigger()
                return .none
            }
        }

        return .none
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.SettingsPageViewStringKey) -> String {
        (first(where: { $0.key == .settingsPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
