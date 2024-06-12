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

/* 3rd-party */
import CoreArchitecture

public struct SettingsContentPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SettingsPageView
    private typealias Floats = AppConstants.CGFloats.SettingsPageView
    private typealias Strings = AppConstants.Strings.SettingsPageView

    // MARK: - Properties

    @ObservedObject public var viewModel: ViewModel<SettingsPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<SettingsPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - View

    public var body: some View {
        ThemedView(redrawsOnAppearanceChange: true) {
            NavigationView {
                ScrollViewReader { _ in
                    VStack {
                        if let cnContact = viewModel.cnContact {
                            NavigationLink(destination: CNContactView(cnContact)) {
                                contactDetailView
                            }
                        } else {
                            contactDetailView
                        }

                        staticListView
                        Spacer()
                        buildInfoButton
                    }
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
            .toolbarBackground(Color.navigationBarBackground, for: .navigationBar)
        }
        .id(viewModel.viewID)
        .preferredStatusBarStyle(.lightContent)
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

            Text(viewModel.buildInfoButtonStrings.labelText)
                .font(.sanFrancisco(size: Floats.buildInfoButtonLabelFontSize))
                .foregroundStyle(Color.subtitleText)
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
            Button {
                viewModel.send(.doneToolbarButtonTapped)
            } label: {
                Text(viewModel.doneToolbarButtonText)
                    .bold()
                    .foregroundStyle(Color.accent)
            }
        }
    }

    @ViewBuilder
    private var staticListView: some View {
        StaticListView(
            [
                inviteFriendsListItem,
                leaveReviewListItem,
            ]
        )
        .padding(.bottom, Floats.staticListViewBottomPadding)
        .padding(.horizontal, Floats.staticListViewHorizontalPadding)

        StaticListView(
            [
                changeThemeListItem,
                sendFeedbackListItem,
                clearCachesListItem,
            ]
        )
        .padding(.bottom, Floats.staticListViewBottomPadding)
        .padding(.horizontal, Floats.staticListViewHorizontalPadding)

        StaticListView(
            [
                deleteAccountListItem,
                signOutListItem,
            ]
        )
        .padding(.bottom, Floats.staticListViewBottomPadding)
        .padding(.horizontal, Floats.staticListViewHorizontalPadding)

        if let developerModeListItems = viewModel.developerModeListItems {
            StaticListView(developerModeListItems)
                .padding(.horizontal, Floats.staticListViewHorizontalPadding)
        }
    }
}
