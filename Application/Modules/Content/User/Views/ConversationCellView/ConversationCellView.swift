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
                // TODO: Link to chat page.
                SamplePageView(.init(initialState: .init(), reducer: SamplePageReducer()))
            } label: {
                EmptyView()
            }
            .buttonStyle(.plain)
            .frame(width: Floats.navigationLinkFrameWidth)
            .opacity(Floats.navigationLinkOpacity)

            cellView
        }
        .frame(height: Floats.frameHeight)
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
                    .opacity(viewModel.isShowingUnreadIndicator ? 1 : 0)
                    .padding(.trailing, Floats.unreadIndicatorViewTrailingPadding)

                AvatarImageView(viewModel.contactImage)
                    .padding(.top, Floats.avatarImageViewTopPadding)

                ZStack {
                    VStack(alignment: .leading) {
                        HStack {
                            HStack {
                                Text(viewModel.titleLabelText)
                                    .bold()
                                    .font(.system(size: Floats.titleLabelSystemFontSize))
                                    .foregroundStyle(Color.titleText)
                                    .minimumScaleFactor(Floats.titleLabelMinimumScaleFactor)
                                    .padding(.bottom, Floats.titleLabelBottomPadding)

                                if let otherUser = viewModel.otherUser {
                                    UserInfoBadgeView(otherUser) {
                                        viewModel.send(.userInfoBadgeTapped)
                                    }
                                    .disabled(viewModel.isPresentingUserInfoAlert)
                                }
                            }

                            Spacer()

                            HStack(alignment: .center, spacing: Floats.chevronImageAndDateLabelHStackSpacing) {
                                Text(viewModel.dateLabelText)
                                    .font(.system(size: Floats.dateLabelSystemFontSize))
                                    .foregroundStyle(Color.subtitleText)
                                    .padding(.trailing, Floats.dateLabelPaddingTrailing)

                                Image(systemName: Strings.chevronImageSystemName)
                                    .font(.system(size: Floats.chevronImageSystemFontSize, weight: .semibold))
                                    .foregroundStyle(viewModel.chevronImageForegroundColor)
                            }
                        }

                        Text(viewModel.subtitleLabelText)
                            .font(Font.system(size: Floats.subtitleLabelSystemFontSize))
                            .foregroundStyle(viewModel.subtitleLabelTextForegroundColor)
                            .lineLimit(.init(Floats.subtitleLabelLineLimit), reservesSpace: true)
                            .offset(x: Floats.subtitleLabelXOffset, y: Floats.subtitleLabelYOffset)
                    }
                }
            }
        }
    }
}
