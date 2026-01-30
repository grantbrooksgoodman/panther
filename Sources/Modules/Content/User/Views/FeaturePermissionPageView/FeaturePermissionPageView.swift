//
//  FeaturePermissionPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 29/01/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

struct FeaturePermissionPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.FeaturePermissionPageView
    private typealias Floats = AppConstants.CGFloats.FeaturePermissionPageView

    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<FeaturePermissionPageReducer>

    // MARK: - Bindings

    private var currentIndexBinding: Binding<Int> {
        viewModel.binding(
            for: \.currentIndex,
            sendAction: { .pageChanged($0) }
        )
    }

    // MARK: - Init

    init(_ viewModel: ViewModel<FeaturePermissionPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    var body: some View {
        StatefulView(
            viewModel.binding(for: \.viewState),
            progressPageViewBackgroundColor: ThemeService.isDarkModeActive ? Color.groupedContentBackground : Colors.lightBackground
        ) {
            VStack {
                TabView(selection: currentIndexBinding) {
                    ForEach(
                        0 ..< viewModel.configurations.count,
                        id: \.self
                    ) { index in
                        contentView
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(
                    indexDisplayMode: .never
                ))

                if viewModel.configurations.count > 1 {
                    pageIndicatorView
                }

                enableButton
                declineButton
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        }
        .ignoresSafeArea()
        .interactiveDismissDisabled()
        .preferredStatusBarStyle(
            .conditionalLightContent,
            restoreOnDisappear: !Application.isInPrevaricationMode
        )
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        VStack {
            ThemedView {
                Components.text(
                    viewModel.titleText,
                    font: .systemBold(scale: .custom(Floats.titleLabelFontScale))
                )
                .multilineTextAlignment(.center)
                .padding(.bottom, Floats.titleLabelBottomPadding)
                .padding(.horizontal, Floats.labelHorizontalPadding)
                .padding(.top, Floats.titleLabelTopPadding)
            }

            SquareIconView(
                viewModel.iconConfig
            )

            ScrollView {
                Components.text(
                    viewModel.subtitleText,
                    font: .system,
                    foregroundColor: .subtitleText
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, Floats.labelHorizontalPadding)
                .padding(.top, Floats.subtitleLabelTopPadding)
            }
            .scrollBounceBehavior(
                .basedOnSize,
                axes: [.vertical]
            )

            Spacer()
        }
    }

    // MARK: - Button Views

    private var declineButton: some View {
        Components.button(
            Localized(.notNow).wrappedValue,
            font: .system,
            foregroundColor: viewModel.isButtonInteractionEnabled ? viewModel.accentColor : .disabled
        ) {
            viewModel.send(
                .declineButtonTapped,
                animation: .easeInOut(duration: Floats.animationDuration)
            )
        }
        .disabled(!viewModel.isButtonInteractionEnabled)
        .padding(
            .bottom,
            Floats.dismissButtonBottomPadding
        )
    }

    private var enableButton: some View {
        Button {
            viewModel.send(
                .enableButtonTapped,
                animation: .easeInOut(duration: Floats.animationDuration)
            )
        } label: {
            Rectangle()
                .frame(height: Floats.enableButtonLabelFrameHeight)
                .frame(
                    minWidth: Floats.enableButtonLabelFrameMinWidth,
                    maxWidth: .infinity
                )
                .foregroundStyle(
                    viewModel.isButtonInteractionEnabled ? viewModel.accentColor : .disabled
                )
                .cornerRadius(Floats.enableButtonLabelCornerRadius)
                .shadow(
                    color: Colors
                        .enableButtonLabelShadow
                        .opacity(Floats.enableButtonLabelShadowColorOpacity),
                    radius: Floats.enableButtonLabelShadowRadius,
                    x: 0,
                    y: Floats.enableButtonLabelShadowYOffset
                )
                .overlay {
                    Components.text(
                        Localized(.enable).wrappedValue,
                        font: .systemSemibold,
                        foregroundColor: viewModel.isButtonInteractionEnabled ? Colors.enableButtonLabelOverlayTextForeground : .gray
                    )
                }
        }
        .disabled(!viewModel.isButtonInteractionEnabled)
        .padding(
            .horizontal,
            Floats.enableButtonLabelHorizontalPadding
        )
        .padding(
            .bottom,
            Floats.enableButtonBottomPadding
        )
    }

    // MARK: - Page Indicator View

    private var pageIndicatorView: some View {
        HStack(spacing: Floats.pageIndicatorHStackSpacing) {
            ForEach(
                0 ..< viewModel.configurations.count,
                id: \.self
            ) { index in
                Circle()
                    .frame(
                        width: Floats.pageIndicatorCircleSize,
                        height: Floats.pageIndicatorCircleSize
                    )
                    .opacity(
                        index == viewModel.currentIndex ? 1 : Floats.pageIndicatorCircleSelectedOpacity
                    )
            }
        }
        .foregroundStyle(.secondary)
        .padding(.bottom, Floats.pageIndicatorBottomPadding)
        .onTapGesture {
            viewModel.send(
                .pageIndicatorTapped,
                animation: .easeInOut(duration: Floats.animationDuration)
            )
        }
    }
}
