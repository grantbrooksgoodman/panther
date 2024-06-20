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
import ComponentKit
import CoreArchitecture

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
                                Components.text(
                                    viewModel.cellViewData.titleLabelText,
                                    font: .systemSemibold(scale: .custom(Floats.titleLabelSystemFontSize))
                                )
                                .minimumScaleFactor(Floats.titleLabelMinimumScaleFactor)
                                .padding(.bottom, Floats.titleLabelBottomPadding)

                                if let otherUser = viewModel.cellViewData.otherUser {
                                    UserInfoBadgeView(otherUser) {
                                        viewModel.send(.userInfoBadgeTapped)
                                    }
                                }
                            }

                            Spacer()

                            HStack(alignment: .center, spacing: Floats.chevronImageAndDateLabelHStackSpacing) {
                                Components.text(
                                    viewModel.cellViewData.dateLabelText,
                                    font: .system(scale: .custom(Floats.dateLabelSystemFontSize)),
                                    foregroundColor: .subtitleText
                                )
                                .padding(.trailing, Floats.dateLabelPaddingTrailing)

                                Components.symbol(
                                    Strings.chevronImageSystemName,
                                    foregroundColor: viewModel.chevronImageForegroundColor,
                                    weight: .semibold,
                                    usesIntrinsicSize: false
                                )
                                .frame(
                                    maxWidth: Floats.chevronImageFrameMaxWidth,
                                    maxHeight: Floats.chevronImageFrameMaxHeight
                                )
                            }
                        }

                        Components.text(
                            viewModel.cellViewData.subtitleLabelText,
                            font: .system(scale: .custom(Floats.subtitleLabelSystemFontSize)),
                            foregroundColor: viewModel.subtitleLabelTextForegroundColor
                        )
                        .lineLimit(.init(Floats.subtitleLabelLineLimit), reservesSpace: true)
                        .offset(x: Floats.subtitleLabelXOffset, y: Floats.subtitleLabelYOffset)
                    }
                }
            }
        }
    }

    private var chatInfoToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Components.button(
                symbolName: Strings.chatInfoButtonImageSystemName,
                usesIntrinsicSize: false
            ) {
                viewModel.send(.chatInfoToolbarButtonTapped)
            }
        }
    }

    private func chatPageView(configuration: ChatPageView.Configuration) -> some View {
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
            return pageView
        }

        return pageView
    }
}
