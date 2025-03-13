//
//  SettingsContentPageView.swift
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

public struct SettingsContentPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SettingsPageView
    private typealias Floats = AppConstants.CGFloats.SettingsPageView
    private typealias Strings = AppConstants.Strings.SettingsPageView

    // MARK: - Properties

    @ObservedObject var viewModel: ViewModel<SettingsPageReducer>

    @ObservedNavigator private var navigationCoordinator: NavigationCoordinator<RootNavigationService>

    // MARK: - Bindings

    private var sheetBinding: Binding<SettingsNavigatorState.SheetPaths?> {
        navigationCoordinator.navigable(
            \.settings.sheet,
            route: { .settings(.sheet($0)) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<SettingsPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - View

    public var body: some View {
        ThemedView(redrawsOnAppearanceChange: true) {
            NavigationView {
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
                    }
                    .scrollBounceBehavior(
                        .basedOnSize,
                        axes: [.vertical]
                    )

                    Spacer()

                    buildInfoButton
                }
                .background(Color.listViewBackground)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(viewModel.navigationTitle)
                .toolbar {
                    doneToolbarButton
                }
            }
            .accentColor(Color.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .interactiveDismissDisabled(true)
            .sheet(item: sheetBinding) { sheetView(for: $0) }
            .toolbarBackground(Color.navigationBarBackground, for: .navigationBar)
        }
        .id(viewModel.viewID)
        .preferredStatusBarStyle(.lightContent, restoreOnDisappear: !Application.isInPrevaricationMode)
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
    }

    private var doneToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Components.button(
                viewModel.doneToolbarButtonText,
                font: .systemSemibold,
                foregroundColor: Application.isInPrevaricationMode ? .navigationBarTitle : .accent
            ) {
                viewModel.send(.doneToolbarButtonTapped)
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
        .padding(.horizontal, Floats.groupedListViewHorizontalPadding)

        if Application.isInPrevaricationMode {
            GroupedListView([
                sendFeedbackListItem,
                clearCachesListItem,
            ])
            .padding(.bottom, Floats.groupedListViewBottomPadding)
            .padding(.horizontal, Floats.groupedListViewHorizontalPadding)
        } else {
            GroupedListView([
                changeThemeListItem,
                sendFeedbackListItem,
                clearCachesListItem,
            ])
            .padding(.bottom, Floats.groupedListViewBottomPadding)
            .padding(.horizontal, Floats.groupedListViewHorizontalPadding)
        }

        GroupedListView([
            blockedUsersListItem,
            deleteAccountListItem,
            signOutListItem,
        ])
        .padding(.bottom, Floats.groupedListViewBottomPadding)
        .padding(.horizontal, Floats.groupedListViewHorizontalPadding)

        ListRowView(penPalsListItem)
            .padding(.bottom, Floats.groupedListViewBottomPadding)
            .padding(.horizontal, Floats.groupedListViewHorizontalPadding)

        if let developerModeListItems = viewModel.developerModeListItems {
            GroupedListView(developerModeListItems)
                .padding(.horizontal, Floats.groupedListViewHorizontalPadding)
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
