//
//  SettingsPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct SettingsPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SettingsPageView
    private typealias Floats = AppConstants.CGFloats.SettingsPageView
    private typealias Strings = AppConstants.Strings.SettingsPageView

    // MARK: - Dependencies

    @ObservedDependency(\.navigation) private var navigation: Navigation

    // MARK: - Properties

    @StateObject var viewModel: ViewModel<SettingsPageReducer>

    @StateObject private var observer: ViewObserver<SettingsPageObserver>

    // MARK: - Bindings

    private var sheetBinding: Binding<SettingsNavigatorState.SheetPaths?> {
        navigation.navigable(
            \.settings.sheet,
            route: { .settings(.sheet($0)) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<SettingsPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
        _observer = .init(wrappedValue: .init(.init(viewModel)))
    }

    // MARK: - View

    public var body: some View {
        StatefulView(
            viewModel.binding(for: \.viewState),
            progressPageViewBackgroundColor: .groupedContentBackground
        ) {
            ThemedView {
                NavigationWindow(
                    displayMode: .inline,
                    toolbarBackgroundColor: .navigationBarBackground,
                    toolbarItems: [doneToolbarButton],
                    toolbarTitle: .init(viewModel.navigationTitle)
                ) {
                    VStack {
                        if let cnContact = viewModel.cnContact {
                            NavigationLink(destination: CNContactView(cnContact)) {
                                contactDetailView
                            }
                        } else {
                            contactDetailView
                        }

                        ScrollView {
                            groupedListViews
                                .padding(.horizontal, Floats.groupedListViewHorizontalPadding)
                                .redrawsOnTraitCollectionChange()
                        }
                        .scrollBounceBehavior(
                            .basedOnSize,
                            axes: [.vertical]
                        )

                        Spacer()

                        buildInfoButton
                    }
                    .background(Color.groupedContentBackground)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .interactiveDismissDisabled(true)
            }
        }
        .preferredStatusBarStyle(
            .conditionalLightContent,
            restoreOnDisappear: !Application.isInPrevaricationMode
        )
        .sheet(item: sheetBinding) { sheetView(for: $0) }
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
        .onDisappear {
            viewModel.send(.viewDisappeared)
        }
        .onTraitCollectionChange {
            viewModel.send(.traitCollectionChanged)
        }
    }

    private var buildInfoButton: some View {
        Group {
            if viewModel.buildInfoButtonStrings.key == .copyright {
                let image = ThemeService.isDarkModeActive ? viewModel.buildInfoButtonDarkBackgroundImage : viewModel.buildInfoButtonLightBackgroundImage
                Image(uiImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .frame(
                        width: Floats.buildInfoButtonImageFrameWidth,
                        height: Floats.buildInfoButtonImageFrameHeight,
                        alignment: .center
                    )
                    .padding(.bottom, Floats.buildInfoButtonImageBottomPadding)
            }

            Components.text(
                viewModel.buildInfoButtonStrings.labelText,
                font: .system(scale: .small),
                foregroundColor: .subtitleText
            )
            .padding(.bottom, Floats.buildInfoButtonLabelBottomPadding)
        }
        .highPriorityGesture(
            TapGesture()
                .onEnded { _ in
                    viewModel.send(.buildInfoButtonTapped)
                }
        )
        .simultaneousGesture(
            LongPressGesture()
                .onEnded { _ in
                    viewModel.send(.longPressGestureRecognized)
                }
        )
    }

    private var contactDetailView: some View {
        ContactDetailView(
            titleLabelText: viewModel.contactDetailViewTitleLabelText,
            subtitleLabelText: viewModel.contactDetailViewSubtitleLabelText,
            image: viewModel.contactDetailViewImage
        )
        .padding(.bottom, Floats.contactDetailViewBottomPadding)
        .padding(.horizontal, Floats.contactDetailViewHorizontalPadding)
        .padding(.top, Floats.contactDetailViewTopPadding)
        .redrawsOnTraitCollectionChange()
    }

    private var doneToolbarButton: NavigationWindow.Toolbar.Item {
        .init(placement: .topBarTrailing) {
            if UIApplication.v26FeaturesEnabled {
                Components.v26DoneButton {
                    viewModel.send(.doneToolbarButtonTapped)
                }
            } else {
                Components.button(
                    viewModel.doneToolbarButtonText,
                    font: .systemSemibold,
                    foregroundColor: Application.isInPrevaricationMode ? .navigationBarTitle : .accent
                ) {
                    viewModel.send(.doneToolbarButtonTapped)
                }
            }
        }
    }

    @ViewBuilder
    private var groupedListViews: some View {
        GroupedListView([
            inviteFriendsListItem,
            leaveReviewListItem,
        ])
        .padding(.bottom, Floats.groupedListViewBottomPadding)

        if Application.isInPrevaricationMode {
            GroupedListView([
                sendFeedbackListItem,
                clearCachesListItem,
            ])
            .padding(.bottom, Floats.groupedListViewBottomPadding)
        } else {
            GroupedListView([
                changeThemeListItem,
                sendFeedbackListItem,
                clearCachesListItem,
            ])
            .id(viewModel.viewID)
            .padding(.bottom, Floats.groupedListViewBottomPadding)
        }

        GroupedListView([
            blockedUsersListItem,
            deleteAccountListItem,
            signOutListItem,
        ])
        .id(viewModel.viewID)
        .padding(.bottom, Floats.groupedListViewBottomPadding)

        ListRowView(penPalsListItem)
            .padding(.bottom, Floats.groupedListViewBottomPadding)

        ListRowView(messageRecipientConsentListItem)
            .padding(.bottom, Floats.groupedListViewBottomPadding)

        if let developerModeListItems = viewModel.developerModeListItems {
            GroupedListView(developerModeListItems)
        }
    }

    @ViewBuilder
    private func sheetView(for path: SettingsNavigatorState.SheetPaths) -> some View {
        switch path {
        case .inviteQRCode:
            InviteQRCodePageView(
                .init(
                    initialState: .init(),
                    reducer: InviteQRCodePageReducer()
                )
            )
        }
    }
}
