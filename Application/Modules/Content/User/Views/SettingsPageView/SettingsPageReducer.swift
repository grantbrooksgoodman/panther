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
import SwiftUI

/* 3rd-party */
import CoreArchitecture

public struct SettingsPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.commonServices.contact) private var contactService: ContactService
    @Dependency(\.networking.services.translation) private var translator: HostedTranslationService
    @Dependency(\.clientSession.user) private var userSession: UserSessionService
    @Dependency(\.settingsPageViewService) private var viewService: SettingsPageViewService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case buildInfoButtonTapped
        case longPressGestureRecognized

        case changeThemeButtonTapped
        case clearCachesButtonTapped
        case deleteAccountButtonTapped
        case inviteFriendsButtonTapped
        case leaveReviewButtonTapped
        case sendFeedbackButtonTapped
        case signOutButtonTapped

        case doneToolbarButtonTapped

        case traitCollectionChanged
        case viewDisappeared
    }

    // MARK: - Feedback

    public enum Feedback {
        case fetchCNContactForCurrentUserReturned(Callback<CNContact, Exception>)
        case inviteFriendsButtonTappedReturned(Exception?)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Constants Accessors */

        private typealias Strings = AppConstants.Strings.SettingsPageView

        /* MARK: Types */

        public enum ViewState: Equatable {
            case loading
            case error(Exception)
            case loaded
        }

        /* MARK: Properties */

        // Array
        public var developerModeListItems: [StaticListItem]?
        public var strings: [TranslationOutputMap] = SettingsPageViewStrings.defaultOutputMap

        // Bool
        public var isPresented: Binding<Bool>
        public var traitCollectionChanged = false

        // String
        public var contactDetailViewSubtitleLabelText: String?
        public var contactDetailViewTitleLabelText = ""
        @Localized(.done) public var doneToolbarButtonText: String
        public var navigationTitle = Localized(.settings).wrappedValue.removingOccurrences(of: ["..."])

        // Other
        public var buildInfoButtonStrings: BuildInfoButtonStrings = .init(.bundleVersionAndBuildNumber)
        public var contactDetailViewImage: UIImage?
        public var cnContact: CNContact?
        public var viewID = UUID()
        public var viewState: ViewState = .loading

        /* MARK: Computed Properties */

        // UIImage
        public var buildInfoButtonDarkBackgroundImage: UIImage { .ntWhite }
        public var buildInfoButtonLightBackgroundImage: UIImage { .ntBlack }

        /* MARK: Init */

        public init(_ isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        /* MARK: Equatable Conformance */

        public static func == (left: State, right: State) -> Bool {
            let sameBuildInfoButtonDarkBackgroundImage = left.buildInfoButtonDarkBackgroundImage == right.buildInfoButtonDarkBackgroundImage
            let sameBuildInfoButtonLightBackgroundImage = left.buildInfoButtonLightBackgroundImage == right.buildInfoButtonLightBackgroundImage
            let sameBuildInfoButtonStrings = left.buildInfoButtonStrings == right.buildInfoButtonStrings
            let sameCNContact = left.cnContact == right.cnContact
            let sameContactDetailViewImage = left.contactDetailViewImage == right.contactDetailViewImage
            let sameContactDetailViewSubtitleLabelText = left.contactDetailViewSubtitleLabelText == right.contactDetailViewSubtitleLabelText
            let sameContactDetailViewTitleLabelText = left.contactDetailViewTitleLabelText == right.contactDetailViewTitleLabelText
            let sameDeveloperModeListItems = left.developerModeListItems == right.developerModeListItems
            let sameDoneToolbarButtonText = left.doneToolbarButtonText == right.doneToolbarButtonText
            let sameIsPresented = left.isPresented.wrappedValue == right.isPresented.wrappedValue
            let sameNavigationTitle = left.navigationTitle == right.navigationTitle
            let sameStrings = left.strings == right.strings
            let sameTraitCollectionChanged = left.traitCollectionChanged == right.traitCollectionChanged
            let sameViewID = left.viewID == right.viewID
            let sameViewState = left.viewState == right.viewState

            guard sameBuildInfoButtonDarkBackgroundImage,
                  sameBuildInfoButtonLightBackgroundImage,
                  sameBuildInfoButtonStrings,
                  sameCNContact,
                  sameContactDetailViewImage,
                  sameContactDetailViewSubtitleLabelText,
                  sameContactDetailViewTitleLabelText,
                  sameDeveloperModeListItems,
                  sameDoneToolbarButtonText,
                  sameIsPresented,
                  sameNavigationTitle,
                  sameStrings,
                  sameTraitCollectionChanged,
                  sameViewID,
                  sameViewState else { return false }

            return true
        }
    }

    // MARK: - Init

    public init() { RuntimeStorage.store(#file, as: .presentedViewName) }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case let .action(action):
            return reduce(into: &state, for: action)

        case let .feedback(feedback):
            return reduce(into: &state, for: feedback)
        }
    }

    // MARK: - Reduce Action

    private func reduce(into state: inout State, for action: Action) -> Effect<Feedback> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading
            state.developerModeListItems = viewService.developerModeListItems()

            let fetchCNContactForCurrentUserTask: Effect<Feedback> = .task {
                let result = await viewService.fetchCNContactForCurrentUser()
                return .fetchCNContactForCurrentUserReturned(result)
            }

            return .task {
                let result = await translator.resolve(SettingsPageViewStrings.self)
                return .resolveReturned(result)
            }.merge(with: fetchCNContactForCurrentUserTask)

        case .buildInfoButtonTapped:
            state.buildInfoButtonStrings = state.buildInfoButtonStrings.next
            state.viewID = UUID()

        case .changeThemeButtonTapped:
            viewService.changeThemeButtonTapped()

        case .clearCachesButtonTapped:
            viewService.clearCachesButtonTapped()

        case .deleteAccountButtonTapped:
            viewService.deleteAccountButtonTapped()

        case .doneToolbarButtonTapped:
            state.isPresented.wrappedValue = false

        case .inviteFriendsButtonTapped:
            return .task {
                let result = await viewService.inviteFriendsButtonTapped()
                return .inviteFriendsButtonTappedReturned(result)
            }

        case .leaveReviewButtonTapped:
            viewService.leaveReviewButtonTapped()

        case .longPressGestureRecognized:
            viewService.setClipboardWithHapticFeedback(state.buildInfoButtonStrings.labelText)

        case .sendFeedbackButtonTapped:
            viewService.sendFeedbackButtonTapped()

        case .signOutButtonTapped:
            viewService.signOutButtonTapped()

        case .traitCollectionChanged:
            state.traitCollectionChanged = true

        case .viewDisappeared:
            NavigationBar.setAppearance(.appDefault)
            guard state.traitCollectionChanged else { return .none }
            Observables.traitCollectionChanged.trigger()
        }

        return .none
    }

    // MARK: - Reduce Feedback

    private func reduce(into state: inout State, for feedback: Feedback) -> Effect<Feedback> {
        switch feedback {
        case let .fetchCNContactForCurrentUserReturned(.success(cnContact)):
            state.cnContact = cnContact

            let contact = Contact(cnContact)
            state.contactDetailViewSubtitleLabelText = userSession.currentUser?.phoneNumber.formattedString() ?? contact.phoneNumbers.first?.formattedString()
            state.contactDetailViewTitleLabelText = contact.fullName

            if let imageData = contact.imageData {
                state.contactDetailViewImage = .init(data: imageData)
            }

            state.viewID = UUID()

        case let .fetchCNContactForCurrentUserReturned(.failure(exception)):
            state.contactDetailViewTitleLabelText = userSession.currentUser?.phoneNumber.formattedString() ?? state.contactDetailViewTitleLabelText
            state.viewID = UUID()
            Logger.log(exception)

        case let .inviteFriendsButtonTappedReturned(exception):
            guard let exception else { return .none }
            Logger.log(exception, with: .toast())

        case let .resolveReturned(.success(strings)):
            state.strings = strings
            state.viewState = .loaded

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception)
            state.viewState = .loaded
        }

        return .none
    }
}
