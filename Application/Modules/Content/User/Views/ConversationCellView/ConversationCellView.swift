//
//  ConversationCellView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct ConversationCellView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ConversationCellView
    private typealias Floats = AppConstants.CGFloats.ConversationCellView
    private typealias Strings = AppConstants.Strings.ConversationCellView

    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<ConversationCellReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<ConversationCellReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        ZStack {
            NavigationLink {
                chatPageView
            } label: {
                EmptyView()
            }
            .buttonStyle(.plain)
            .frame(width: Floats.navigationLinkFrameWidth)
            .opacity(Floats.navigationLinkOpacity)

            cellView
        }
        .frame(height: Floats.frameHeight)
        .swipeActions(allowsFullSwipe: false) {
            Button {
                viewModel.send(.deleteConversationButtonTapped)
            } label: {
                Image(systemName: Strings.deleteConversationButtonImageSystemName)
            }
            .tint(Colors.deleteConversationButtonImageTint)
        }
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }

    private var cellView: some View {
        Group {
            HStack {
                Circle()
                    .foregroundStyle(Colors.unreadIndicatorViewForeground)
                    .frame(
                        width: Floats.unreadIndicatorViewFrameWidth,
                        height: Floats.unreadIndicatorViewFrameHeight,
                        alignment: .center
                    )
                    .offset(
                        x: Floats.unreadIndicatorViewXOffset,
                        y: Floats.unreadIndicatorViewYOffset
                    )
                    .opacity(viewModel.cellViewData.isShowingUnreadIndicator ? 1 : 0)
                    .padding(.trailing, Floats.unreadIndicatorViewTrailingPadding)

                AvatarImageView(viewModel.cellViewData.contactImage)
                    .padding(.top, Floats.avatarImageViewTopPadding)

                ZStack {
                    VStack(alignment: .leading) {
                        HStack {
                            HStack {
                                Text(viewModel.cellViewData.titleLabelText)
                                    .bold()
                                    .font(.system(size: Floats.titleLabelSystemFontSize))
                                    .foregroundStyle(Color.titleText)
                                    .minimumScaleFactor(Floats.titleLabelMinimumScaleFactor)
                                    .padding(.bottom, Floats.titleLabelBottomPadding)

                                if let otherUser = viewModel.cellViewData.otherUser {
                                    UserInfoBadgeView(otherUser) {
                                        viewModel.send(.userInfoBadgeTapped)
                                    }
                                    .disabled(viewModel.isPresentingUserInfoAlert)
                                }
                            }

                            Spacer()

                            HStack(alignment: .center, spacing: Floats.chevronImageAndDateLabelHStackSpacing) {
                                Text(viewModel.cellViewData.dateLabelText)
                                    .font(.system(size: Floats.dateLabelSystemFontSize))
                                    .foregroundStyle(Color.subtitleText)
                                    .padding(.trailing, Floats.dateLabelPaddingTrailing)

                                Image(systemName: Strings.chevronImageSystemName)
                                    .font(.system(size: Floats.chevronImageSystemFontSize, weight: .semibold))
                                    .foregroundStyle(viewModel.chevronImageForegroundColor)
                            }
                        }

                        Text(viewModel.cellViewData.subtitleLabelText)
                            .font(.system(size: Floats.subtitleLabelSystemFontSize))
                            .foregroundStyle(viewModel.subtitleLabelTextForegroundColor)
                            .lineLimit(.init(Floats.subtitleLabelLineLimit), reservesSpace: true)
                            .offset(x: Floats.subtitleLabelXOffset, y: Floats.subtitleLabelYOffset)
                    }
                }
            }
        }
    }

    private var chatPageView: some View {
        ChatPageView(viewModel.conversation)
            .background(ThemeService.isDefaultThemeApplied ? .clear : .navigationBarBackground)
            .ignoresSafeArea(.keyboard)
            .navigationBarColor(background: .navigationBarBackground, titleText: .navigationBarTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(viewModel.cellViewData.titleLabelText)
            .toolbarBackground(Color.navigationBarBackground, for: .navigationBar)
            .onAppear {
                viewModel.send(.chatPageViewAppeared)
            }
    }
}
