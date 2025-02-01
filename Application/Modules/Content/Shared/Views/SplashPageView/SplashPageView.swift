//
//  SplashPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct SplashPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SplashPageView
    private typealias Floats = AppConstants.CGFloats.SplashPageView

    // MARK: - Dependencies

    @ObservedDependency(\.splashPageViewService) private var viewService: SplashPageViewService

    // MARK: - Properties

    @StateObject private var observer: ViewObserver<SplashPageObserver>
    @StateObject private var viewModel: ViewModel<SplashPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<SplashPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
        _observer = .init(wrappedValue: .init(.init(viewModel)))
    }

    // MARK: - View

    public var body: some View {
        VStack {
            ThemedView {
                Image(.hello)
                    .resizable()
                    .renderingMode((ThemeService.isDarkModeActive || !ThemeService.isAppDefaultThemeApplied) ? .template : .original)
                    .foregroundColor((ThemeService.isDarkModeActive || !ThemeService.isAppDefaultThemeApplied) ? Colors.imageDarkForeground : .none)
                    .frame(width: Floats.imageFrameWidth, height: Floats.imageFrameHeight)
                    .padding(.bottom, Floats.padding)
            }

            if viewModel.shouldShowProgressBar {
                progressBar
                    .animation(.easeIn, value: viewService.initializationProgress)
                    .controlSize(.large)
                    .dynamicTypeSize(.large)
                    .tint(Color.accent)
                    .padding(.horizontal, Floats.progressBarHorizontalPadding)
                    .padding(.top, Floats.progressBarTopPadding)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .dynamicTypeSize(.large)
                    .scaleEffect(.init(Floats.activityIndicatorScaleEffect))
                    .padding(.top, Floats.padding)
            }
        }
        .fadeIn(delay: .milliseconds(Floats.fadeInDelayMilliseconds))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredStatusBarStyle(
            ThemeService.isDarkModeActive ? .lightContent : (ThemeService.isAppDefaultThemeApplied ? .darkContent : .lightContent),
            restoreOnDisappear: !Application.isInPrevaricationMode
        )
        .redrawsOnTraitCollectionChange()
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        if viewService.shouldShowLoadingLabel {
            ProgressView(value: viewService.initializationProgress) {
                HStack(spacing: 0) {
                    ProgressView()
                        .controlSize(.regular)
                        .dynamicTypeSize(.large)
                        .frame(
                            maxWidth: Floats.progressBarActivityIndicatorFrameMaxWidth,
                            maxHeight: Floats.progressBarActivityIndicatorFrameMaxHeight
                        )
                        .tint(Color(uiColor: .systemGray))

                    ThemedView {
                        Components.text(
                            viewService.loadingLabelText,
                            foregroundColor: .init(uiColor: ThemeService.isDarkModeActive ? .lightGray : .darkGray)
                        )
                    }
                }
            }
        } else {
            ProgressView(value: viewService.initializationProgress)
        }
    }
}
