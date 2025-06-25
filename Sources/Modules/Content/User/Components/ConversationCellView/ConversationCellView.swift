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

/* Proprietary */
import AppSubsystem
import ComponentKit

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

    // MARK: - Body

    public var body: some View {
        Button {
            viewModel.send(.cellTapped)
        } label: {
            cellView
        }
        .contextMenu {
            contextMenuButtons
        } preview: { // Modify with caution – ChatPageViewService relies on this specific stack to detect misconfigured previews.
            ChatPageView(
                viewModel.conversation,
                configuration: .preview
            )
            .background(ThemeService.isAppDefaultThemeApplied ? .clear : .navigationBarBackground)
            .id(viewModel.conversation.id)
        }
        .frame(height: Floats.frameHeight)
        .swipeActions(edge: .leading, allowsFullSwipe: false) { swipeActionButtons(.leading) }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) { swipeActionButtons(.trailing) }
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }

    // MARK: - Button Views

    @ViewBuilder
    private var contextMenuButtons: some View {
        Button(role: .destructive) {
            viewModel.send(.deleteConversationButtonTapped)
        } label: {
            Label(viewModel.deleteConversationButtonText, systemImage: Strings.deleteConversationButtonImageSystemName)
        }

        Divider()

        Button {
            viewModel.send(.blockUsersButtonTapped)
        } label: {
            Label(viewModel.blockUsersButtonText, systemImage: Strings.blockUsersButtonImageSystemName)
        }

        Button {
            viewModel.send(.reportUsersButtonTapped)
        } label: {
            Label(viewModel.reportUsersButtonText, systemImage: Strings.reportUsersButtonImageSystemName)
        }
    }

    @ViewBuilder
    private func swipeActionButtons(_ edge: HorizontalEdge) -> some View {
        switch edge {
        case .leading:
            Button {
                viewModel.send(.blockUsersButtonTapped)
            } label: {
                Image(systemName: Strings.blockUsersButtonImageSystemName)
            }
            .tint(Colors.blockUsersButtonImageTint)

            Button {
                viewModel.send(.reportUsersButtonTapped)
            } label: {
                Image(systemName: Strings.reportUsersButtonImageSystemName)
            }
            .tint(Colors.reportUsersButtonImageTint)

        case .trailing:
            Button {
                viewModel.send(.deleteConversationButtonTapped)
            } label: {
                Image(systemName: Strings.deleteConversationButtonImageSystemName)
            }
            .tint(Colors.deleteConversationButtonImageTint)
        }
    }

    // MARK: - Cell View

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
                                .padding(
                                    .trailing,
                                    Application.isInPrevaricationMode ? 0 : Floats.dateLabelPaddingTrailing
                                )
                                .if(Application.isInPrevaricationMode) { $0.offset(x: Floats.chevronImageFrameMaxWidth) }

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
                                .if(Application.isInPrevaricationMode) { $0.opacity(0) }
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
}
