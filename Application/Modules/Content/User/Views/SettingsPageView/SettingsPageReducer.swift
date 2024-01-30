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
import Redux

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
        case inviteFriendsButtonTapped
        case leaveReviewButtonTapped
        case sendFeedbackButtonTapped
        case signOutButtonTapped

        case doneToolbarButtonTapped
    }

    // MARK: - Feedback

    public enum Feedback {
        case fetchCnContactForCurrentUserReturned(Callback<CNContact, Exception>)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Type Aliases */

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

        // String
        public var contactDetailViewSubtitleLabelText: String?
        public var contactDetailViewTitleLabelText = ""
        @Localized(.done) public var doneToolbarButtonText: String
        public var navigationTitle = Localized(.settings).wrappedValue.removingOccurrences(of: ["..."])

        // UIImage
        public var buildInfoButtonDarkBackgroundImage: UIImage? { .init(named: Strings.buildInfoButtonDarkBackgroundImageSystemName) }
        public var buildInfoButtonLightBackgroundImage: UIImage? { .init(named: Strings.buildInfoButtonLightBackgroundImageSystemName) }
        public var contactDetailViewImage: UIImage?

        // Other
        public var buildInfoButtonStrings: BuildInfoButtonStrings = .init(.bundleVersionAndBuildNumber)
        public var cnContact: CNContact?
        public var isPresented: Binding<Bool>
        public var viewID = UUID()
        public var viewState: ViewState = .loading

        /* MARK: Init */

        public init(_ isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        /* MARK: Equatable Conformance */

        public static func == (left: State, right: State) -> Bool {
            let sameBuildInfoButtonDarkBackgroundImage = left.buildInfoButtonDarkBackgroundImage == right.buildInfoButtonDarkBackgroundImage
            let sameBuildInfoButtonLightBackgroundImage = left.buildInfoButtonLightBackgroundImage == right.buildInfoButtonLightBackgroundImage
            let sameBuildInfoButtonStrings = left.buildInfoButtonStrings == right.buildInfoButtonStrings
            let sameCnContact = left.cnContact == right.cnContact
            let sameContactDetailViewImage = left.contactDetailViewImage == right.contactDetailViewImage
            let sameContactDetailViewSubtitleLabelText = left.contactDetailViewSubtitleLabelText == right.contactDetailViewSubtitleLabelText
            let sameContactDetailViewTitleLabelText = left.contactDetailViewTitleLabelText == right.contactDetailViewTitleLabelText
            let sameDeveloperModeListItems = left.developerModeListItems == right.developerModeListItems
            let sameDoneToolbarButtonText = left.doneToolbarButtonText == right.doneToolbarButtonText
            let sameIsPresented = left.isPresented.wrappedValue == right.isPresented.wrappedValue
            let sameNavigationTitle = left.navigationTitle == right.navigationTitle
            let sameStrings = left.strings == right.strings
            let sameViewID = left.viewID == right.viewID
            let sameViewState = left.viewState == right.viewState

            guard sameBuildInfoButtonDarkBackgroundImage,
                  sameBuildInfoButtonLightBackgroundImage,
                  sameBuildInfoButtonStrings,
                  sameCnContact,
                  sameContactDetailViewImage,
                  sameContactDetailViewSubtitleLabelText,
                  sameContactDetailViewTitleLabelText,
                  sameDeveloperModeListItems,
                  sameDoneToolbarButtonText,
                  sameIsPresented,
                  sameNavigationTitle,
                  sameStrings,
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

            let fetchCnContactForCurrentUserTask: Effect<Feedback> = .task {
                let result = await viewService.fetchCnContactForCurrentUser()
                return .fetchCnContactForCurrentUserReturned(result)
            }

            return .task {
                let result = await translator.resolve(SettingsPageViewStrings.self)
                return .resolveReturned(result)
            }.merge(with: fetchCnContactForCurrentUserTask)

        case .buildInfoButtonTapped:
            state.buildInfoButtonStrings = state.buildInfoButtonStrings.next

        case .changeThemeButtonTapped:
            break

        case .clearCachesButtonTapped:
            viewService.clearCachesButtonTapped()

        case .doneToolbarButtonTapped:
            state.isPresented.wrappedValue = false

        case .inviteFriendsButtonTapped:
            break

        case .leaveReviewButtonTapped:
            viewService.leaveReviewButtonTapped()

        case .longPressGestureRecognized:
            viewService.setClipboardWithHapticFeedback(state.buildInfoButtonStrings.labelText)

        case .sendFeedbackButtonTapped:
            viewService.sendFeedbackButtonTapped()

        case .signOutButtonTapped:
            break
        }

        return .none
    }

    // MARK: - Reduce Feedback

    private func reduce(into state: inout State, for feedback: Feedback) -> Effect<Feedback> {
        switch feedback {
        case let .fetchCnContactForCurrentUserReturned(.success(cnContact)):
            state.cnContact = cnContact

            let contact = Contact(cnContact)
            state.contactDetailViewSubtitleLabelText = userSession.currentUser?.phoneNumber.formattedString() ?? contact.phoneNumbers.first?.formattedString()
            state.contactDetailViewTitleLabelText = contact.fullName

            if let imageData = contact.imageData {
                state.contactDetailViewImage = .init(data: imageData)
            }

            state.viewID = UUID()

        case let .fetchCnContactForCurrentUserReturned(.failure(exception)):
            state.contactDetailViewTitleLabelText = userSession.currentUser?.phoneNumber.formattedString() ?? state.contactDetailViewTitleLabelText
            state.viewID = UUID()
            Logger.log(exception)

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
