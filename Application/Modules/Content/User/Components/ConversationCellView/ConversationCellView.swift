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
                chatPageView(configuration: .default)
            } label: {
                EmptyView()
            }
            .buttonStyle(.plain)
            .frame(width: Floats.navigationLinkFrameWidth)
            .opacity(Floats.navigationLinkOpacity)

            cellView
        }
        .contextMenu {
            Button(role: .destructive) {
                viewModel.send(.deleteConversationButtonTapped)
            } label: {
                Label(viewModel.deleteConversationButtonText, systemImage: Strings.deleteConversationButtonImageSystemName)
            }
        } preview: {
            chatPageView(configuration: .preview)
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

                AvatarImageView(
                    viewModel.cellViewData.thumbnailImage,
                    badgeCount: viewModel.conversation.participants.count - 1
                )
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

    private var chatInfoToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.send(.chatInfoToolbarButtonTapped)
            } label: {
                Image(systemName: Strings.chatInfoButtonImageSystemName)
            }
            .foregroundStyle(Color.accent)
        }
    }

    private func chatPageView(configuration: ChatPageView.Configuration) -> some View {
        func configure(_ anyView: AnyView) -> some View {
            guard ThemeService.isDefaultThemeApplied else {
                return AnyView(anyView.toolbarBackground(Color.navigationBarBackground, for: .navigationBar))
            }

            return anyView
        }

        var pageView: AnyView = .init(
            ChatPageView(viewModel.conversation, configuration: configuration)
                .background(ThemeService.isDefaultThemeApplied ? .clear : .navigationBarBackground)
                .ignoresSafeArea(.keyboard)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(viewModel.cellViewData.titleLabelText)
                .toolbar {
                    chatInfoToolbarButton
                }
        )

        guard configuration == .preview else {
            pageView = AnyView(
                pageView
                    .onAppear {
                        viewModel.send(.chatPageViewAppeared)
                    }
            )
            return configure(pageView)
        }

        return configure(pageView)
    }
}
