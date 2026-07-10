//
//  ChatPageHeaderView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 27/04/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

struct ChatPageHeaderView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageHeaderView
    private typealias Floats = AppConstants.CGFloats.ChatPageHeaderView
    private typealias Strings = AppConstants.Strings.ChatPageHeaderView

    // MARK: - Properties

    @StateObject private var observer: ViewObserver<ChatPageHeaderObserver>
    @StateObject private var viewModel: ViewModel<ChatPageHeaderReducer>

    // MARK: - Init

    init(_ viewModel: ViewModel<ChatPageHeaderReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
        _observer = .init(wrappedValue: .init(.init(viewModel)))
    }

    // MARK: - View

    var body: some View {
        contentView
            .padding(.vertical, Floats.contentViewVerticalPadding)
            .frame(maxWidth: .infinity)
            .background { backgroundView }
            .id(viewModel.viewID)
    }

    // MARK: - Background View

    private var backgroundView: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(.thinMaterial.opacity(Floats.backgroundViewBlurOpacity))
                .frame(
                    height: proxy.size.height + Floats.backgroundViewHeightIncrement
                )
                .mask(
                    VStack(spacing: 0) {
                        Colors.backgroundViewGradientColor
                            .frame(height: proxy.size.height)

                        LinearGradient(
                            colors: [
                                Colors.backgroundViewGradientColor,
                                .clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: Floats.backgroundViewHeightIncrement)
                    }
                )
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Content View

    private var contentView: some View {
        ThemedView {
            ZStack(alignment: .top) {
                chatInfoButton

                HStack {
                    backButton
                    Spacer()
                }
                .padding(
                    .horizontal,
                    Floats.backButtonViewHorizontalPadding
                )
            }
        }
    }

    // MARK: - Back Button

    private var backButton: some View {
        Button {
            viewModel.send(.backButtonTapped)
        } label: {
            Components.symbol(
                Strings.backButtonImageSystemName,
                weight: .medium,
                usesIntrinsicSize: false
            )
            .frame(
                width: Floats.backButtonSymbolFrameSize,
                height: Floats.backButtonSymbolFrameSize
            )
        }
        .frame(
            width: Floats.backButtonFrameSize,
            height: Floats.backButtonFrameSize
        )
        .glassEffect(
            padding: Floats.backButtonGlassEffectPadding,
            shape: .circle
        )
    }

    // MARK: - Chat Info Button

    private var chatInfoButton: some View {
        Button {
            viewModel.send(.chatInfoButtonTapped)
        } label: {
            VStack(spacing: Floats.avatarViewSpacing) {
                AvatarImageView(
                    viewModel.cellViewData.thumbnailImage,
                    badgeCount: viewModel.conversation.participants.count > Int(Floats.avatarImageViewBadgeCountComparator) ? -1 : 0,
                    size: .init(
                        width: Floats.avatarImageSize,
                        height: Floats.avatarImageSize
                    )
                )
                .background(
                    Colors.avatarImageViewBackground,
                    in: Circle()
                )
                .zIndex(1)

                HStack(spacing: Floats.avatarViewNameLabelSpacing) {
                    Components.text(
                        viewModel.conversation.chatPageHeaderLabelText ?? viewModel.cellViewData.titleLabelText,
                        font: .systemSemibold(scale: .custom(
                            Floats.avatarViewNameLabelFontSize
                        ))
                    )
                    .multilineTextAlignment(.center)
                    .padding(
                        .horizontal,
                        Floats.avatarViewNameLabelTextHorizontalPadding
                    )

                    Components.symbol(
                        Strings.avatarViewNameLabelChevronSymbolImageSystemName,
                        foregroundColor: Colors.avatarViewNameLabelChevronSymbolForeground,
                        weight: .heavy,
                        usesIntrinsicSize: false
                    )
                    .frame(
                        width: Floats.avatarViewNameLabelChevronSymbolFrameSize,
                        height: Floats.avatarViewNameLabelChevronSymbolFrameSize
                    )
                }
                .glassEffect(
                    padding: Floats.avatarViewNameLabelGlassEffectPadding,
                    shape: .capsule
                )
                .padding(
                    .horizontal,
                    Floats.avatarViewNameLabelViewHorizontalPadding
                )
            }
        }
        .buttonStyle(.plain)
    }
}
